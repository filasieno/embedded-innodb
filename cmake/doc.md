# CMake Generator Expressions Explained

Generator expressions are CMake's way of creating conditional content that gets evaluated at **generation time** (when CMake creates build files), not at configuration time. The `$<...>` syntax is how you write them.

## Key Concept: Generation vs Configuration

- **Configuration time**: When CMake processes your `CMakeLists.txt`
- **Generation time**: When CMake creates the actual build files (Makefile, Ninja, etc.)
- Generator expressions are evaluated at generation time

## 1. `$<$<CONFIG:Debug>:UNIV_DEBUG>` - Configuration-Based Condition

### How it works

- `$<CONFIG:Debug>` checks if the current build configuration is "Debug"
- If true, it expands to `UNIV_DEBUG`
- If false, it expands to nothing (empty string)

### Expansion examples

- **Debug build**: `target_compile_definitions(innodb_pch INTERFACE UNIV_DEBUG UNIV_LINUX)`
- **Release build**: `target_compile_definitions(innodb_pch INTERFACE UNIV_LINUX)`

### Why this works

`UNIV_DEBUG` only gets defined in Debug builds, while `UNIV_LINUX` is always defined.

## 2. `$<$<COMPILE_LANGUAGE:CXX>:header.h>` - Language-Based Condition

- `$<COMPILE_LANGUAGE:CXX>` checks if the current compilation unit is C++
- If true, it expands to the header path
- If false (e.g., C compilation), it expands to nothing

PCH headers are only meaningful for C++ compilation. This prevents CMake from trying to precompile C++ headers during C compilation.

## General Syntax: `$<condition:result>`

The pattern is: `$<CONDITION:RESULT_IF_TRUE>`

## Common Conditions

- `$<CONFIG:Debug>` - Current config is Debug
- `$<CONFIG:Release>` - Current config is Release
- `$<COMPILE_LANGUAGE:CXX>` - Compiling C++ code
- `$<COMPILE_LANGUAGE:C>` - Compiling C code
- `$<PLATFORM_ID:Linux>` - Building on Linux
- `$<BOOL:variable>` - Variable evaluates to true

### Advanced nesting

`$<$<CONFIG:Debug>:UNIV_DEBUG>` (condition inside condition)

## Why Generator Expressions Matter

### Deferred Evaluation

They allow conditional logic that depends on build-time decisions

### Multi-config Support

Essential for generators like Visual Studio that support multiple configurations in one build

### Precise Control

Apply settings only where they're needed (per-file, per-target, per-config)

### In your case, this ensures that

- `UNIV_DEBUG` is only defined in Debug builds
- PCH headers are only used for C++ compilation
- The same `CMakeLists.txt` works across different build types and platforms

This is much more powerful than traditional `if(CMAKE_BUILD_TYPE STREQUAL "Debug")` approaches, which only work at configuration time and can cause issues with multi-config generators.
