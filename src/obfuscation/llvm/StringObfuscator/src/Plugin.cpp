#include "ObfuscatorPass.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"

using namespace llvm;

// Point d'entrée du plugin — Clang appelle ça au chargement
extern "C" LLVM_ATTRIBUTE_WEAK PassPluginLibraryInfo llvmGetPassPluginInfo() {
    return {
        LLVM_PLUGIN_API_VERSION,
        "StringObfuscator",
        "1.0",
        [](PassBuilder& PB) {
            // On s'enregistre sur le pipeline "optimizer"
            PB.registerPipelineStartEPCallback(
                [](ModulePassManager& MPM, OptimizationLevel) {
                    MPM.addPass(StringObfuscatorPass());
                }
            );
        }
    };
}