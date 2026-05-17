//===----------------------------------------------------------------------===//
// Control Flow Flattening Pass
//
// Algorithme :
//  1. Collecter tous les BasicBlocks de la fonction (hors entry, hors return)
//  2. Créer une variable alloca "switch_var" dans l'entry block
//  3. Créer un "dispatcher" block contenant le switch()
//  4. Remplacer chaque terminateur (br, etc.) par une assignation à switch_var
//     + un saut vers le dispatcher
//  5. Connecter le dispatcher à chaque bloc via les cases
//===----------------------------------------------------------------------===//

#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Constants.h"
#include "llvm/Transforms/Utils/BasicBlockUtils.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

namespace {

// ─────────────────────────────────────────────────────────────
// Utilitaires
// ─────────────────────────────────────────────────────────────

// Retourne true si le bloc se termine par un ret (on ne le touche pas)
static bool isReturnBlock(BasicBlock *BB) {
  return isa<ReturnInst>(BB->getTerminator());
}

// Collecte les blocs à aplatir (tout sauf entry et returns)
static std::vector<BasicBlock *> collectBlocks(Function &F) {
  std::vector<BasicBlock *> blocks;
  bool first = true;
  for (auto &BB : F) {
    if (first) { 
        first = false;
        continue; }  // skip entry
    if (!isReturnBlock(&BB))
      blocks.push_back(&BB);
  }
  return blocks;
}

// ─────────────────────────────────────────────────────────────
// Le pass lui-même
// ─────────────────────────────────────────────────────────────
struct CFFPass : public PassInfoMixin<CFFPass> {

  PreservedAnalyses run(Function &F, FunctionAnalysisManager &) {
    if (F.isDeclaration()){
        return PreservedAnalyses::all();

    } 
    LLVMContext &Ctx = F.getContext();
    IRBuilder<> Builder(Ctx);
    Type *I32 = Type::getInt32Ty(Ctx);

    // ── Étape 1 : collecter les blocs candidats ──────────────
    auto blocks = collectBlocks(F);
    if (blocks.empty()) return PreservedAnalyses::all();

    // Assigner un numéro à chaque bloc (case index)
    std::map<BasicBlock *, uint32_t> blockID;
    uint32_t id = 0;
    for (auto *BB : blocks)
      blockID[BB] = id++;

    // ── Étape 2 : créer switch_var dans l'entry block ─────────
    BasicBlock *entry = &F.getEntryBlock();
    // On insère l'alloca au tout début de l'entry
    AllocaInst *switchVar = new AllocaInst(
        I32, 0, "switch_var",
        entry->getFirstNonPHI()   // point d'insertion
    );

    // Initialiser switch_var = 0 (→ premier bloc)
    // On l'insère juste avant le terminateur de l'entry
    Builder.SetInsertPoint(entry->getTerminator());
    Builder.CreateStore(ConstantInt::get(I32, 0), switchVar);

    // ── Étape 3 : créer le dispatcher block ───────────────────
    BasicBlock *dispatcher = BasicBlock::Create(Ctx, "dispatcher", &F);
    // Loader switch_var
    Builder.SetInsertPoint(dispatcher);
    Value *loadedVar = Builder.CreateLoad(I32, switchVar, "load_sw");

    // Créer un bloc "default" (ne devrait jamais être atteint)
    BasicBlock *defaultBB = BasicBlock::Create(Ctx, "sw_default", &F);
    Builder.SetInsertPoint(defaultBB);
    Builder.CreateUnreachable();

    // Créer le switch dans le dispatcher
    Builder.SetInsertPoint(dispatcher);
    SwitchInst *sw = Builder.CreateSwitch(loadedVar, defaultBB,
                                          (unsigned)blocks.size());

    // Ajouter chaque bloc comme case
    for (auto *BB : blocks)
      sw->addCase(ConstantInt::get(I32, blockID[BB]), BB);

    // ── Étape 4 : rediriger l'entry vers le dispatcher ────────
    // L'entry saute directement vers le premier bloc normalement.
    // On change ce saut pour aller vers le dispatcher.
    {
      auto *term = entry->getTerminator();
      // Si c'est un br direct vers blocks[0], on remplace
      if (auto *br = dyn_cast<BranchInst>(term)) {
        if (!br->isConditional()) {
          Builder.SetInsertPoint(term);
          Builder.CreateBr(dispatcher);
          term->eraseFromParent();
        }
      }
    }

    // ── Étape 5 : remplacer les terminateurs des blocs ────────
    for (auto *BB : blocks) {
      auto *term = BB->getTerminator();

      if (auto *br = dyn_cast<BranchInst>(term)) {
        if (!br->isConditional()) {
          // Branchement direct  → switch_var = id(dest) ; br dispatcher
          BasicBlock *dest = br->getSuccessor(0);
          if (blockID.count(dest)) {
            Builder.SetInsertPoint(term);
            Builder.CreateStore(ConstantInt::get(I32, blockID[dest]), switchVar);
            Builder.CreateBr(dispatcher);
            term->eraseFromParent();
          }
        } else {
          // Branchement conditionnel → select sur switch_var puis br dispatcher
          BasicBlock *trueDest  = br->getSuccessor(0);
          BasicBlock *falseDest = br->getSuccessor(1);

          if (blockID.count(trueDest) && blockID.count(falseDest)) {
            Builder.SetInsertPoint(term);
            Value *cond = br->getCondition();
            // switch_var = cond ? id(true) : id(false)
            Value *trueID  = ConstantInt::get(I32, blockID[trueDest]);
            Value *falseID = ConstantInt::get(I32, blockID[falseDest]);
            Value *selected = Builder.CreateSelect(cond, trueID, falseID,
                                                   "sw_sel");
            Builder.CreateStore(selected, switchVar);
            Builder.CreateBr(dispatcher);
            term->eraseFromParent();
          }
        }
      }
    }

    errs() << "[CFF] Flattened function: " << F.getName() << "\n";
    return PreservedAnalyses::none();
  }
};

} // namespace

// ─────────────────────────────────────────────────────────────
// Enregistrement du plugin
// ─────────────────────────────────────────────────────────────
extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return {
    LLVM_PLUGIN_API_VERSION, "CFFPass", LLVM_VERSION_STRING,
    [](PassBuilder &PB) {
      // Enregistrer pour opt -passes="cff"
      PB.registerPipelineParsingCallback(
          [](StringRef Name, FunctionPassManager &FPM,
             ArrayRef<PassBuilder::PipelineElement>) {
            if (Name == "cff") {
              FPM.addPass(CFFPass());
              return true;
            }
            return false;
          });
    }
  };
}