#pragma once
#include "llvm/IR/PassManager.h"
#include "llvm/IR/Module.h"

namespace llvm {

class StringObfuscatorPass
    : public PassInfoMixin<StringObfuscatorPass> {
public:
    // C'est la fonction appelée automatiquement par Clang
    // sur chaque module (= chaque fichier .cpp compilé)
    PreservedAnalyses run(Module& M, ModuleAnalysisManager& MAM);
};

} // namespace llvm