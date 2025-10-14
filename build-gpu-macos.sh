#!/bin/bash
# ============================================================================
# BitNet GPU Modules Copy Script for macOS
# ============================================================================
# macOS does not support NVIDIA CUDA, so this script only copies Python
# modules to Release/gpu/macos/ for consistency.
#
# No CUDA kernel will be built. GPU acceleration is not available on macOS.
# Use CPU backend instead (which has ARM TL1 optimizations).
# ============================================================================

set -e  # Exit on error

echo ""
echo "============================================================================"
echo "BitNet GPU Modules for macOS (Python only - No CUDA)"
echo "============================================================================"
echo ""

# Get script directory (BitNet root)
BITNET_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BITNET_ROOT"

echo "⚠️  macOS does not support NVIDIA CUDA"
echo "    GPU acceleration is only available on Windows/Linux with NVIDIA GPUs"
echo "    This script copies Python modules for consistency."
echo ""

echo "[1/2] Creating Release directory structure..."
mkdir -p Release/gpu/macos

echo ""
echo "[2/2] Copying Python modules (no kernel)..."

# Copy Python modules
cp gpu/model.py Release/gpu/macos/
cp gpu/generate.py Release/gpu/macos/
cp gpu/tokenizer.py Release/gpu/macos/
cp gpu/pack_weight.py Release/gpu/macos/
cp gpu/sample_utils.py Release/gpu/macos/
cp gpu/stats.py Release/gpu/macos/
cp gpu/convert_checkpoint.py Release/gpu/macos/
cp gpu/convert_safetensors.py Release/gpu/macos/
cp gpu/tokenizer.model Release/gpu/macos/

# Create README explaining limitation
cat > Release/gpu/macos/README.txt << 'EOF'
macOS GPU Support Limitation
=============================

macOS does not support NVIDIA CUDA.
GPU acceleration is only available on:
- Windows with NVIDIA GPU
- Linux with NVIDIA GPU

On macOS, use the CPU backend which has ARM TL1 optimizations
specifically tuned for Apple Silicon (M1/M2/M3).

For best performance on macOS:
- Use the CPU binary: Release/cpu/macos/llama-server
- ARM TL1 kernels provide 2-6x speedup over standard GGUF
- Performance is comparable to or better than many GPU implementations

Build CPU binary with:
  ./build-cpu-macos.sh
EOF

echo ""
echo "============================================================================"
echo "✅ MODULES COPIED (NO GPU SUPPORT)"
echo "============================================================================"
echo ""
echo "Location: $BITNET_ROOT/Release/gpu/macos/"
echo ""

# List files
echo "Files copied:"
ls -1 Release/gpu/macos/

echo ""
echo "⚠️  Remember: No GPU acceleration on macOS!"
echo "   Use CPU backend for best performance on Apple Silicon."
echo ""
echo "Build CPU binary:"
echo "  ./build-cpu-macos.sh"
echo ""

