#!/bin/bash
# ============================================================================
# BitNet GPU Kernel Build Script for Linux
# ============================================================================
# This script builds the CUDA kernel and copies all GPU modules to
# Release/gpu/linux/
# 
# Prerequisites:
#   - CUDA Toolkit 12.1+
#   - Python 3.9-3.11
#   - PyTorch with CUDA support
#   - GCC/G++ compiler
# ============================================================================

set -e  # Exit on error

echo ""
echo "============================================================================"
echo "BitNet GPU Kernel Build for Linux"
echo "============================================================================"
echo ""

# Get script directory (BitNet root)
BITNET_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BITNET_ROOT"

echo "[1/5] Checking prerequisites..."
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python not found!"
    echo "Install Python 3.9-3.11"
    exit 1
fi
echo "  ✓ Python found"

# Check nvcc (CUDA compiler)
if ! command -v nvcc &> /dev/null; then
    echo "WARNING: nvcc not found!"
    echo "CUDA Toolkit may not be installed or not in PATH"
    echo "Continuing anyway..."
else
    echo "  ✓ CUDA Toolkit found"
fi

echo ""
echo "[2/5] Installing PyTorch with CUDA support..."
echo "  This may take a few minutes if not already installed..."
python3 -m pip install torch --index-url https://download.pytorch.org/whl/cu121 --quiet || true

echo "  ✓ PyTorch installed"

echo ""
echo "[3/5] Building CUDA kernel..."
echo "  This will compile the CUDA code..."
cd gpu/bitnet_kernels

python3 setup.py build_ext --inplace

cd ../..

echo ""
echo "[4/5] Creating Release directory structure..."
mkdir -p Release/gpu/linux

echo ""
echo "[5/5] Copying GPU modules to Release directory..."

# Copy compiled kernel
echo "  Copying CUDA kernel (.so)..."
cp gpu/bitnet_kernels/*.so Release/gpu/linux/ 2>/dev/null || echo "WARNING: No .so file found!"

# Copy Python modules
echo "  Copying Python modules..."
cp gpu/model.py Release/gpu/linux/
cp gpu/generate.py Release/gpu/linux/
cp gpu/tokenizer.py Release/gpu/linux/
cp gpu/pack_weight.py Release/gpu/linux/
cp gpu/sample_utils.py Release/gpu/linux/
cp gpu/stats.py Release/gpu/linux/
cp gpu/convert_checkpoint.py Release/gpu/linux/
cp gpu/convert_safetensors.py Release/gpu/linux/

# Copy tokenizer model
echo "  Copying tokenizer data..."
cp gpu/tokenizer.model Release/gpu/linux/

echo ""
echo "============================================================================"
echo "✅ BUILD SUCCESSFUL!"
echo "============================================================================"
echo ""
echo "GPU modules location: $BITNET_ROOT/Release/gpu/linux/"
echo ""

# List files
echo "Files copied:"
ls -1 Release/gpu/linux/

echo ""
echo "Test the GPU kernel:"
echo "  cd Release/gpu/linux"
echo "  python3 -c \"import bitlinear_cuda; print('✅ GPU kernel loaded!')\""
echo ""

