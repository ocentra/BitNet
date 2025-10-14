# Build BitNet on Windows - Quick Guide

## Prerequisites Checklist

- [ ] Visual Studio 2022 installed
- [ ] Clang/LLVM component installed in Visual Studio
- [ ] CMake 3.14+ installed
- [ ] (Optional) CUDA Toolkit 12.1+ for GPU kernel

## Quick Build (Automated Scripts)

### Option 1: Build Everything (CPU + GPU)
```cmd
REM Open Visual Studio Developer Command Prompt as Administrator
cd E:\Desktop\TabAgent\Server\BitNet
build-all-windows.bat
```

### Option 2: Build CPU Only
```cmd
cd E:\Desktop\TabAgent\Server\BitNet
build-cpu-windows.bat
```

### Option 3: Build GPU Only
```cmd
cd E:\Desktop\TabAgent\Server\BitNet
build-gpu-windows.bat
```

**Expected Output:**
- `Release/cpu/windows/llama-server.exe` (~80-120 MB)
- `Release/gpu/windows/bitlinear_cuda.pyd` (~5-15 MB) + Python files

---

## Manual Build Steps (If Scripts Fail)

### Step 1: Open Visual Studio Developer Command Prompt

**IMPORTANT:** Run as Administrator!

Search for "Developer Command Prompt for VS 2022" in Start Menu → Right-click → Run as Administrator

### Step 2: Navigate to BitNet

```cmd
cd E:\Desktop\TabAgent\Server\BitNet
```

### Step 3: Build CPU Binary

```cmd
REM Create build directory
mkdir build
cd build

REM Configure with CMake (TL2 kernels for Windows x64)
cmake .. -DBITNET_X86_TL2=ON -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -T ClangCL

REM Build in Release mode (this will take a few minutes)
cmake --build . --config Release

REM Copy to Release directory
copy bin\Release\llama-server.exe ..\Release\cpu\windows\

REM Verify
dir ..\Release\cpu\windows\llama-server.exe
```

**Expected Output:**
- Build completes successfully
- `llama-server.exe` (~80-120 MB) in `Release/cpu/windows/`

### Step 4: Build GPU Kernel (Optional - if CUDA installed)

```cmd
REM Go back to BitNet root
cd ..

REM Navigate to GPU kernels
cd gpu\bitnet_kernels

REM Install PyTorch with CUDA (if not already installed)
python -m pip install torch --index-url https://download.pytorch.org/whl/cu121

REM Build kernel
python setup.py build_ext --inplace

REM Copy to Release
mkdir ..\..\Release\gpu\windows
copy *.pyd ..\..\Release\gpu\windows\

REM Copy Python modules
cd ..
copy *.py ..\Release\gpu\windows\
copy tokenizer.model ..\Release\gpu\windows\

REM Verify
dir ..\Release\gpu\windows\
```

**Expected Output:**
- `bitlinear_cuda.pyd` (~5-15 MB) in `Release/gpu/windows/`
- All Python files copied

### Step 5: Test

#### Test CPU Binary:
```cmd
cd Release\cpu\windows
llama-server.exe --help
```

Should show help text with options.

#### Test GPU Kernel (if built):
```cmd
cd Release\gpu\windows
python -c "import bitlinear_cuda; print('✅ GPU kernel loaded!')"
```

Should print success message.

## Troubleshooting

### Error: Clang not found
```
CMake Error: Could not find Clang compiler
```

**Solution:**
1. Open Visual Studio Installer
2. Modify VS 2022
3. Individual Components → Search "Clang"
4. Check "C++ Clang compiler for Windows"
5. Install

### Error: CMAKE not found
```
'cmake' is not recognized
```

**Solution:**
1. Download from https://cmake.org/download/
2. Install with "Add to PATH" option
3. Restart Command Prompt

### Error: CUDA not found (for GPU)
```
nvcc not found
```

**Solution:**
1. Download CUDA Toolkit 12.1+ from NVIDIA
2. Install
3. Restart Command Prompt

### Build takes forever
This is normal! First build compiles llama.cpp and all dependencies.
Expect 5-15 minutes depending on CPU.

### Binary is huge
Normal! Includes all BitNet kernels and llama.cpp.
Size: 80-120 MB is expected.

## What Next?

After successful build:

1. **Verify Files:**
   ```cmd
   dir Release\cpu\windows\llama-server.exe
   dir Release\gpu\windows\*.pyd
   ```

2. **Test with Model (if you have one):**
   ```cmd
   cd Release\cpu\windows
   llama-server.exe --model C:\path\to\bitnet-model.gguf --port 8081
   ```

3. **Ready for CI/CD:**
   - Push `.github/workflows/build-and-release.yml` to GitHub
   - Workflow will automate all of this
   - Creates Release with binaries

## CI/CD Automation

Once this manual build works, the GitHub Actions workflow will:
- Build all platforms (Windows, macOS, Linux)
- Build CPU + GPU for each
- Package into `BitNet-Release.zip`
- Trigger TabAgent to download and integrate

**No more manual builds needed!** 🎉

## Help

If stuck, check:
- Visual Studio 2022 with Clang is installed
- Command Prompt is **Administrator** and **Developer** version
- All paths are correct (adjust `E:\Desktop\...` if needed)
- CMake cache: delete `build/` folder and try again if CMake errors persist

