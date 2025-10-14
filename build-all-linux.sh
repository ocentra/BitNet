#!/bin/bash
# ============================================================================
# BitNet Complete Build Script for Linux (CPU + GPU)
# ============================================================================
# Builds both CPU binary and GPU kernel for Linux
# 
# Prerequisites:
#   - CMake 3.14+ (apt install cmake)
#   - Clang (apt install clang)
#   - CUDA Toolkit 12.1+ (for GPU)
#   - Python 3.9-3.11 (for GPU)
# ============================================================================

set -e  # Exit on error

echo ""
echo "============================================================================"
echo "BitNet Complete Build for Linux (CPU + GPU)"
echo "============================================================================"
echo ""

# Get script directory
BITNET_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BITNET_ROOT"

echo "This will:"
echo "  0. Sync with upstream microsoft/BitNet (latest changes)"
echo "  1. Build BitNet CPU Binary (llama-server-bitnet + cli + bench with x64 TL2 kernels)"
echo "  2. Build Standard GPU Binary (llama-server-standard + cli + bench with CUDA + Vulkan)"
echo "  3. Build BitNet GPU Kernel (libbitnet.so + Python modules)"
echo ""
read -p "Press Enter to start, or Ctrl+C to cancel..."

echo ""
echo "============================================================================"
echo "Part 0: Syncing with Upstream BitNet"
echo "============================================================================"
bash sync-upstream.sh || {
    echo ""
    echo "WARNING: Upstream sync failed or had conflicts!"
    echo "You can continue with the build, but you may want to resolve conflicts first."
    echo ""
    read -p "Continue with build anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
}

echo ""
echo "============================================================================"
echo "Part 1: Building BitNet CPU Binary"
echo "============================================================================"
bash build-cpu-linux.sh

echo ""
echo ""
echo "============================================================================"
echo "Part 2: Building Standard GPU Binary (CUDA + Vulkan)"
echo "============================================================================"
echo ""
echo "Building standard llama.cpp with GPU support..."
echo ""

# Clean previous build
rm -rf build-standard

# Configure with CUDA and Vulkan
cmake -B build-standard -DGGML_CUDA=ON -DGGML_VULKAN=ON -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_EXAMPLES=ON
if [ $? -ne 0 ]; then
    echo ""
    echo "WARNING: Standard build configuration failed! Skipping..."
else
    # Build
    cmake --build build-standard --config Release -j
    if [ $? -ne 0 ]; then
        echo ""
        echo "WARNING: Standard build failed! Skipping..."
    else
        # Copy all binaries
        echo ""
        echo "Copying standard binaries to Release folder..."
        cp -f build-standard/bin/llama-server Release/cpu/linux/llama-server-standard
        chmod +x Release/cpu/linux/llama-server-standard
        
        if [ -f "build-standard/bin/llama-cli" ]; then
            cp -f build-standard/bin/llama-cli Release/cpu/linux/llama-cli-standard
            chmod +x Release/cpu/linux/llama-cli-standard
        fi
        
        if [ -f "build-standard/bin/llama-bench" ]; then
            cp -f build-standard/bin/llama-bench Release/cpu/linux/llama-bench-standard
            chmod +x Release/cpu/linux/llama-bench-standard
        fi
        
        echo "✅ Standard binaries built successfully!"
    fi
fi

echo ""
echo ""
echo "============================================================================"
echo "Part 3: Building BitNet GPU Kernel"
echo "============================================================================"
bash build-gpu-linux.sh || {
    echo ""
    echo "WARNING: GPU build failed! BitNet CPU and Standard builds are still valid."
}

echo ""
echo ""
echo "============================================================================"
echo "✅ COMPLETE BUILD SUCCESSFUL!"
echo "============================================================================"
echo ""
echo "BitNet CPU Binary: $BITNET_ROOT/Release/cpu/linux/llama-server-bitnet"
echo "Standard GPU Binary: $BITNET_ROOT/Release/cpu/linux/llama-server-standard"
echo "BitNet GPU Modules: $BITNET_ROOT/Release/gpu/linux/"
echo ""

# Show summary
echo "Build Summary:"
echo ""
echo "CPU Binaries:"
ls -1 Release/cpu/linux/
echo ""
echo "GPU Modules:"
ls -1 Release/gpu/linux/
echo ""

echo "Ready for:"
echo "  - Manual testing"
echo "  - GitHub Actions to package into Release"
echo "  - TabAgent integration"
echo ""

