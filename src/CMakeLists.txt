set(GGML_HEADERS_BITNET ../include/ggml-bitnet.h)
set(GGML_SOURCES_BITNET ggml-bitnet-mad.cpp)
set(GGML_SOURCES_BITNET ggml-bitnet-lut.cpp)

include_directories(3rdparty/llama.cpp/ggml/include)

# Only enforce Clang/GCC when actually building BitNet-optimized binaries (BITNET_X86_TL2 or BITNET_ARM_TL1)
if (BITNET_ARM_TL1 OR BITNET_X86_TL2)
    if (NOT (CMAKE_C_COMPILER_ID MATCHES "Clang" OR CMAKE_C_COMPILER_ID STREQUAL "GNU") OR
        NOT (CMAKE_CXX_COMPILER_ID MATCHES "Clang" OR CMAKE_CXX_COMPILER_ID STREQUAL "GNU"))
        message(FATAL_ERROR "Clang or GCC is required for Bitnet.cpp compilation (when BITNET_ARM_TL1 or BITNET_X86_TL2 enabled)")
    endif()
endif()
