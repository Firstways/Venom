#include "ObfuscatorPass.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/GlobalVariable.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Transforms/Utils/ModuleUtils.h"
using namespace llvm;

// --------------------------------------------------
// Chiffre chaque caractère avec XOR
// --------------------------------------------------
static void xorBuffer(char* buf, size_t size, uint8_t key) {
    for (size_t i = 0; i < size; i++)
        buf[i] ^= key;
}

// --------------------------------------------------
// Ajoute une fonction qui déchiffre toutes les
// strings au démarrage (avant le main)
// --------------------------------------------------
static void addDecoder(Module& M,
                       std::vector<std::pair<GlobalVariable*, uint8_t>>& strings) {
    auto& ctx = M.getContext();

    // Créer une fonction vide : void decodeAllStrings()
    FunctionType* fnType = FunctionType::get(Type::getVoidTy(ctx), false);
    Function* decoderFn  = Function::Create(
        fnType,
        GlobalValue::InternalLinkage,
        "decode_all_strings",
        M
    );

    // Créer le bloc d'instructions
    BasicBlock* block = BasicBlock::Create(ctx, "entry", decoderFn);
    IRBuilder<> builder(block);

    // Pour chaque string chiffrée, ajouter une boucle de déchiffrement
    for (auto& [gv, key] : strings) {

        // Récupérer le type et la taille du tableau
        auto* arrayType = cast<ArrayType>(gv->getValueType());
        size_t size     = arrayType->getNumElements();

        // Créer la constante pour la clé XOR
        Value* keyVal  = builder.getInt8(key);
        Value* sizeVal = builder.getInt64(size);

        // Obtenir un pointeur vers le premier élément de la string
        Value* ptr = builder.CreateConstInBoundsGEP2_32(
            arrayType, gv, 0, 0
        );

        // Créer une boucle : for(i=0; i<size; i++) ptr[i] ^= key
        // On a besoin de 3 blocs : init, loop, end
        Function*   fn       = block->getParent();
        BasicBlock* loopInit = BasicBlock::Create(ctx, "loop_init", fn);
        BasicBlock* loopBody = BasicBlock::Create(ctx, "loop_body", fn);
        BasicBlock* loopEnd  = BasicBlock::Create(ctx, "loop_end",  fn);

        // Sauter vers l'init
        builder.CreateBr(loopInit);

        // -- Bloc init : i = 0
        builder.SetInsertPoint(loopInit);
        PHINode* idx = builder.CreatePHI(builder.getInt64Ty(), 2, "i");
        idx->addIncoming(builder.getInt64(0), block); // i=0 au départ
        Value* cond  = builder.CreateICmpULT(idx, sizeVal); // i < size
        builder.CreateCondBr(cond, loopBody, loopEnd);

        // -- Bloc body : ptr[i] ^= key
        builder.SetInsertPoint(loopBody);
        Value* elemPtr = builder.CreateGEP(
            builder.getInt8Ty(), ptr, idx
        );
        Value* loaded  = builder.CreateLoad(builder.getInt8Ty(), elemPtr);
        Value* xored   = builder.CreateXor(loaded, keyVal);
        builder.CreateStore(xored, elemPtr);

        // i++
        Value* nextIdx = builder.CreateAdd(idx, builder.getInt64(1));
        idx->addIncoming(nextIdx, loopBody);
        builder.CreateBr(loopInit);

        // -- Bloc end : continuer
        builder.SetInsertPoint(loopEnd);
        block = loopEnd; // le prochain string part d'ici
    }

    builder.CreateRetVoid();

    // Enregistrer comme constructeur global (s'exécute avant main)
    appendToGlobalCtors(M, decoderFn, 0);
}

// --------------------------------------------------
// La passe principale
// --------------------------------------------------
PreservedAnalyses StringObfuscatorPass::run(Module& M,
                                            ModuleAnalysisManager& MAM) {
    auto& ctx = M.getContext();
    uint8_t key = 0x42; // clé XOR

    // Liste des strings qu'on a chiffrées
    std::vector<std::pair<GlobalVariable*, uint8_t>> obfuscated;

    for (GlobalVariable& gv : M.globals()) {
        // Ignorer ce qui n'est pas une string constante
        if (!gv.isConstant() || !gv.hasInitializer())
            continue;

        auto* array = dyn_cast<ConstantDataArray>(gv.getInitializer());
        if (!array || !array->isCString())
            continue;

        // Récupérer la string
        StringRef str = array->getAsString();
        size_t size   = str.size();

        outs() << "[obfuscator] Chiffrement de : " << str << "\n";

        // Copier et chiffrer
        char* buf = new char[size];
        memcpy(buf, str.data(), size);
        xorBuffer(buf, size, key);

        // Remplacer dans l'IR
        auto* newArray = ConstantDataArray::getString(
            ctx, StringRef(buf, size), false
        );
        gv.setInitializer(newArray);
        gv.setConstant(false);

        obfuscated.push_back({&gv, key});
        delete[] buf;
    }

    if (obfuscated.empty())
        return PreservedAnalyses::all(); // rien changé

    // Ajouter la fonction de décodage automatique
    addDecoder(M, obfuscated);

    return PreservedAnalyses::none(); // on a modifié le module
}