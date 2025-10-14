#!/bin/bash
# ============================================================================
# BitNet Complete Build Script for macOS
# ============================================================================
# Builds CPU binary and copies GPU modules (Python only, no CUDA on macOS)
# 
# Prerequisites:
#   - Xcode Command Line Tools (xcode-select --install)
#   - CMake 3.14+ (brew install cmake)
# ============================================================================

set -e  # Exit on error

echo ""
echo "============================================================================"
echo "BitNet Complete Build for macOS"
echo "============================================================================"
echo ""

# Get script directory
BITNET_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BITNET_ROOT"

echo "This will:"
echo "  0. Sync with upstream microsoft/BitNet (latest changes)"
echo "  1. Build BitNet CPU Binary (llama-server-bitnet + cli + bench with ARM TL1 kernels)"
echo "  2. Build Standard GPU Binary (llama-server-standard + cli + bench with Metal)"
echo "  3. Copy GPU Modules (Python only - no CUDA on macOS)"
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
bash build-cpu-macos.sh

echo ""
echo ""
echo "============================================================================"
echo "Part 2: Building Standard GPU Binary (Metal)"
echo "============================================================================"
echo ""
echo "Building standard llama.cpp with Metal support..."
echo ""

# Clean previous build
rm -rf build-standard

# Configure with Metal (enabled by default on macOS)
cmake -B build-standard -DGGML_METAL=ON -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_EXAMPLES=ON
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
        cp -f build-standard/bin/llama-server Release/cpu/macos/llama-server-standard
        chmod +x Release/cpu/macos/llama-server-standard
        
        if [ -f "build-standard/bin/llama-cli" ]; then
            cp -f build-standard/bin/llama-cli Release/cpu/macos/llama-cli-standard
            chmod +x Release/cpu/macos/llama-cli-standard
        fi
        
        if [ -f "build-standard/bin/llama-bench" ]; then
            cp -f build-standard/bin/llama-bench Release/cpu/macos/llama-bench-standard
            chmod +x Release/cpu/macos/llama-bench-standard
        fi
        
        echo "✅ Standard binaries built successfully!"
    fi
fi

echo ""
echo ""
echo "============================================================================"
echo "Part 3: Copying GPU Modules"
echo "============================================================================"
bash build-gpu-macos.sh

echo ""
echo ""
echo "============================================================================"
echo "✅ COMPLETE BUILD SUCCESSFUL!"
echo "============================================================================"
echo ""
echo "BitNet CPU Binary: $BITNET_ROOT/Release/cpu/macos/llama-server-bitnet"
echo "Standard GPU Binary: $BITNET_ROOT/Release/cpu/macos/llama-server-standard"
echo "GPU Modules: $BITNET_ROOT/Release/gpu/macos/ (Python only)"
echo ""

# Show summary
echo "Build Summary:"
echo ""
echo "CPU Binaries:"
ls -1 Release/cpu/macos/
echo ""
echo "GPU Modules:"
ls -1 Release/gpu/macos/
echo ""

echo "Ready for:"
echo "  - Manual testing"
echo "  - GitHub Actions to package into Release"
echo "  - TabAgent integration"
echo ""

