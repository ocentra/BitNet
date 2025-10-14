#!/bin/bash
# ============================================================================
# BitNet CPU Binary Build Script for Linux
# ============================================================================
# This script builds llama-server and places it in Release/cpu/linux/
# 
# Prerequisites:
#   - CMake 3.14+ (apt install cmake)
#   - Clang (apt install clang)
#   - GCC/G++ (build-essential)
# ============================================================================

set -e  # Exit on error

echo ""
echo "============================================================================"
echo "BitNet CPU Binary Build for Linux (x64 with TL2 kernels)"
echo "============================================================================"
echo ""

# Get script directory (BitNet root)
BITNET_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BITNET_ROOT"

echo "[1/5] Checking prerequisites..."
echo ""

# Check CMake
if ! command -v cmake &> /dev/null; then
    echo "ERROR: CMake not found!"
    echo "Install with: sudo apt-get install cmake"
    exit 1
fi
echo "  ✓ CMake found"

# Check Clang
if ! command -v clang &> /dev/null; then
    echo "ERROR: Clang not found!"
    echo "Install with: sudo apt-get install clang"
    exit 1
fi
echo "  ✓ Clang found"

echo ""
echo "[2/5] Creating build directory..."
rm -rf build
mkdir build
cd build

echo ""
echo "[3/5] Configuring with CMake (TL2 kernels for x64)..."
echo "  This may take a few moments..."
cmake .. \
    -DBITNET_X86_TL2=ON \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DLLAMA_BUILD_SERVER=ON \
    -DLLAMA_BUILD_EXAMPLES=ON

echo ""
echo "[4/5] Building in Release mode..."
echo "  This will take 5-15 minutes depending on your CPU..."
echo "  Please be patient..."
cmake --build . --config Release

echo ""
echo "[5/5] Copying binaries to Release directory..."
cd ..

# Ensure Release directory exists
mkdir -p Release/cpu/linux

# Copy all binaries with BitNet suffix
echo "Copying llama-server-bitnet..."
cp build/bin/llama-server Release/cpu/linux/llama-server-bitnet
chmod +x Release/cpu/linux/llama-server-bitnet

if [ -f "build/bin/llama-cli" ]; then
    echo "Copying llama-cli-bitnet..."
    cp build/bin/llama-cli Release/cpu/linux/llama-cli-bitnet
    chmod +x Release/cpu/linux/llama-cli-bitnet
fi

if [ -f "build/bin/llama-bench" ]; then
    echo "Copying llama-bench-bitnet..."
    cp build/bin/llama-bench Release/cpu/linux/llama-bench-bitnet
    chmod +x Release/cpu/linux/llama-bench-bitnet
fi

echo ""
echo "============================================================================"
echo "✅ BUILD SUCCESSFUL!"
echo "============================================================================"
echo ""
echo "Binaries copied to: $BITNET_ROOT/Release/cpu/linux/"
echo ""
ls -lh Release/cpu/linux/*-bitnet
echo ""

echo "Test the binaries:"
echo "  cd Release/cpu/linux"
echo "  ./llama-server-bitnet --help"
echo "  ./llama-cli-bitnet --help"
echo ""

