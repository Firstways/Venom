cmake_minimum_required(VERSION 3.20)
project(StringObfuscator)
set(CMAKE_CXX_STANDARD 17)
set(LLVM_DIR "/usr/lib/llvm-21/lib/cmake/llvm")
find_package(LLVM REQUIRED CONFIG)

message(STATUS "LLVM version: ${LLVM_VERSION}")

include_directories(${LLVM_INCLUDE_DIRS})
add_definitions(${LLVM_DEFINITIONS})

add_library(obfuscator SHARED
    src/ObfuscatorPass.cpp
    src/Plugin.cpp
)

target_include_directories(obfuscator PRIVATE ${LLVM_INCLUDE_DIRS})

# Lier LLVM en dynamique uniquement
target_link_libraries(obfuscator LLVM-21)

set_target_properties(obfuscator PROPERTIES PREFIX "")