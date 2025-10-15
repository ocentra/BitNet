# BitNet Windows Build - Complete Guide

**Status:** ✅ ALL WORKING - Ready for Production Use

---

## 🚀 Quick Start (3 Steps)

### Step 1: Build C++ Binaries (Required)
```powershell
.\build_complete.ps1
```
**Duration:** 10-15 minutes  
**Output:** 9 executables in `Release/cpu/windows/`

### Step 2: Build Python GPU Kernel (Optional)
```powershell
.\build_python_gpu.ps1
```
**Duration:** 2-5 minutes  
**Output:** CUDA DLL in `Release/gpu/windows/`

### Step 3: Enable Vulkan (Optional)
```powershell
.\setup_vulkan.ps1
```
**Duration:** < 1 minute  
**Output:** Instructions for enabling Vulkan support

---

## 📦 What Gets Built

### C++ Binaries (9 total)
- **Standard** - General CPU inference (3 tools)
- **GPU** - NVIDIA CUDA acceleration (3 tools)  
- **BitNet** - 1.58-bit optimized (3 tools)

Each variant includes: `llama-server`, `llama-cli`, `llama-bench`

### Python GPU Kernel
- `libbitnet.dll` - CUDA kernel for Python inference
- 9 Python modules for GPU inference
- Tokenizer and utilities

---

## 📁 File Structure

### Working Scripts (Keep These!)
```
build_complete.ps1          ← Main C++ build script
build_python_gpu.ps1        ← Python GPU kernel builder
setup_vulkan.ps1            ← Vulkan configuration helper
gpu/bitnet_kernels/
  └── build_dll.ps1         ← Internal DLL builder
```

### Documentation
```
WINDOWS_BUILD_README.md     ← This file (master guide)
COMPLETE_BUILD_STATUS.md    ← Detailed status & troubleshooting
README_WINDOWS_BUILDS.md    ← Quick reference card
```

### Build Outputs
```
Release/
├── cpu/windows/            ← 9 C++ executables
│   ├── llama-server-standard.exe
│   ├── llama-server-gpu.exe
│   ├── llama-server-bitnet.exe
│   └── ... (6 more)
└── gpu/windows/            ← Python GPU kernel
    ├── libbitnet.dll
    ├── *.py (9 files)
    └── tokenizer.model
```

---

## ⚙️ Prerequisites

### Required
- **Visual Studio 2022 Community** with:
  - C++ Desktop Development
  - Clang/LLVM (C++ Clang Compiler for Windows)
  - CUDA 12.x support
- **NVIDIA CUDA Toolkit 12.x**
- **Python 3.9-3.13**
- **Git**

### One-Time Setup (CUDA MSBuild Integration)

**Run PowerShell as Administrator:**
```powershell
Copy-Item "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8\extras\visual_studio_integration\MSBuildExtensions\*" `
          "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Microsoft\VC\v170\BuildCustomizations\" -Force
```

This allows MSVC to compile CUDA code.

### Optional
- **Vulkan SDK** - For AMD/Intel GPU support

---

## 🧪 Testing Your Builds

### Test C++ Binaries
```powershell
# Standard CPU
.\Release\cpu\windows\llama-server-standard.exe --help

# GPU with CUDA
.\Release\cpu\windows\llama-server-gpu.exe --help

# BitNet optimized
.\Release\cpu\windows\llama-server-bitnet.exe --help
```

### Test Python GPU Kernel
```powershell
cd Release\gpu\windows
$env:PATH = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8\bin;$env:PATH"
python -c "import ctypes; lib=ctypes.CDLL('libbitnet.dll'); print('✅ GPU kernel loaded!')"
```

---

## 🔧 How It Works

### Build Strategy

**Problem:** Windows needs different compilers for different components:
- BitNet C++ → Requires Clang (intrinsics, optimizations)
- CUDA code → Requires MSVC (Windows CUDA integration)
- Standard llama.cpp → Works with any compiler

**Solution:** Build separately with appropriate compilers:

1. **Standard CPU Build** → ClangCL (fastest on Windows)
2. **GPU Build** → MSVC + CUDA
3. **BitNet Build** → ClangCL + BitNet optimizations

### Key Fixes Applied

1. **PyTorch CUDA Preservation** - Don't let requirements.txt downgrade torch
2. **Missing Headers** - Added `#include <chrono>` for Windows
3. **Conditional Clang Check** - Only enforce when building BitNet features
4. **CUDA MSBuild Integration** - Install one-time for CUDA compilation
5. **Windows CUDA uint** - Added typedef for Windows compatibility
6. **Python GPU as DLL** - Build as shared library (like Linux .so)
7. **DLL Export** - Windows requires explicit `__declspec(dllexport)`
8. **Vulkan Graceful Fallback** - Auto-disable if SDK not configured

### Platform Safety

All code changes use platform guards:
- `#ifdef _WIN32` for C++ code
- `if (WIN32)` for CMake
- Standard C++ features (`<chrono>` is C++11)

**Zero impact on Linux/Mac builds!**

---

## 🌋 Enabling Vulkan (Optional)

Vulkan adds AMD/Intel GPU support and can improve performance.

### Step 1: Run Setup Helper
```powershell
.\setup_vulkan.ps1
```

### Step 2: Set Environment Variable

**Run PowerShell as Administrator:**
```powershell
[System.Environment]::SetEnvironmentVariable('VULKAN_SDK', 'C:\VulkanSDK\1.4.328.1', 'Machine')
```

### Step 3: Rebuild GPU Variant
```powershell
# Close and reopen PowerShell
Remove-Item build-gpu -Recurse -Force
.\build_complete.ps1
```

You should see `Vulkan Support: ✅ ENABLED` in the build summary.

---

## 🐛 Troubleshooting

### "CUDA toolset not found"
**Fix:** Install CUDA MSBuild integration (see Prerequisites)

### "Clang required for Bitnet"
**Fix:** Install "C++ Clang Compiler for Windows" in VS 2022

### Python GPU build fails
**Fix:** Ensure VS 2022 environment is set up correctly (script handles this)

### Vulkan not working
**Fix:** Run `setup_vulkan.ps1` and follow instructions

### All builds fail
**Fix:** 
1. Verify Visual Studio 2022 installed
2. Verify CUDA Toolkit installed
3. Check `COMPLETE_BUILD_STATUS.md` for detailed troubleshooting

---

## 📊 Build Comparison

| Platform | C++ Builds | Python GPU | Vulkan | Scripts |
|----------|------------|------------|--------|---------|
| **Windows** | ✅ 9 binaries | ✅ DLL | ⚠️ Optional | 3 modular |
| **Linux** | ✅ Works | ✅ .so | ❌ WSL limit | 1 script |
| **macOS** | ✅ CI | ❌ Not built | ✅ CI | 1 script |

Windows is now a **first-class platform** for BitNet!

---

## 🎯 For TabAgent Integration

Everything is ready in `Release/` folder:

### C++ Inference
Use `Release/cpu/windows/llama-server-*.exe` for:
- Standard CPU inference
- GPU-accelerated inference (NVIDIA)
- BitNet 1.58-bit optimized inference

### Python Inference
Use `Release/gpu/windows/` for Python-based GPU inference:
```python
import ctypes
lib = ctypes.CDLL('path/to/libbitnet.dll')
# Use lib.bitlinear_int8xint2(...)
```

---

## 📚 Additional Documentation

- **`COMPLETE_BUILD_STATUS.md`** - Detailed status, all fixes, comprehensive testing
- **`README_WINDOWS_BUILDS.md`** - Quick reference card
- **Main `README.md`** - Project overview

---

## 🏆 What Makes This Special

This is the **first fully self-contained Windows build** for BitNet that:

1. ✅ Works without VS Developer Command Prompt
2. ✅ Handles compiler conflicts automatically
3. ✅ Preserves PyTorch CUDA version
4. ✅ Builds Python GPU kernel correctly
5. ✅ Provides modular, focused scripts
6. ✅ Includes platform-safe upstream fixes
7. ✅ Supports optional Vulkan
8. ✅ Maintains Linux/Mac compatibility

**All components built and tested on Windows 11 with VS 2022!**

---

## ✅ Quick Checklist

Before building:
- [ ] Visual Studio 2022 installed with Clang component
- [ ] CUDA Toolkit 12.x installed
- [ ] CUDA MSBuild integration installed (one-time)
- [ ] Python 3.9-3.13 available
- [ ] Git installed

To build:
- [ ] Run `build_complete.ps1` (C++ binaries)
- [ ] Run `build_python_gpu.ps1` (Python GPU kernel)
- [ ] (Optional) Configure Vulkan with `setup_vulkan.ps1`

To verify:
- [ ] Test C++ binaries with `--help`
- [ ] Test Python GPU DLL loads
- [ ] Check `Release/` folder has all outputs

---

**Need help?** Check `COMPLETE_BUILD_STATUS.md` for comprehensive troubleshooting!

**Ready to build?** Run `.\build_complete.ps1` and you're off! 🚀

