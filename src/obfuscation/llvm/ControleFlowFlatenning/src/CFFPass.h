#pragma once
#include "llvm/IR/PassManager.h"
#include "llvm/IR/Module.h"


struct FlatteningPass : public PassInfoMixin<FlatteningPass> {
    PreservedAnalyses run(Function &F, FunctionAnalysisManager &AM);
};