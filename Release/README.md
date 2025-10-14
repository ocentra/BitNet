# BitNet Release Directory

This directory contains the complete BitNet binaries and modules for all platforms.

## Structure

```
Release/
├── cpu/          # CPU inference binaries (standalone)
│   ├── windows/
│   │   └── llama-server.exe        (~80-120 MB)
│   ├── macos/
│   │   └── llama-server            (~60-90 MB, ARM64)
│   └── linux/
│       └── llama-server            (~60-90 MB, x64)
│
└── gpu/          # GPU inference modules (Python + CUDA kernels)
    ├── windows/
    │   ├── bitlinear_cuda.pyd      (~5-15 MB, CUDA kernel)
    │   ├── model.py                (~11 KB)
    │   ├── generate.py             (~13 KB)
    │   ├── tokenizer.py            (~9 KB)
    │   ├── tokenizer.model         (~2.1 MB)
    │   └── *.py                    (other modules)
    │
    ├── macos/
    │   ├── *.py                    (Python modules only)
    │   ├── tokenizer.model         (~2.1 MB)
    │   └── README.txt              (no CUDA explanation)
    │
    └── linux/
        ├── bitlinear_cuda.so       (~5-15 MB, CUDA kernel)
        ├── model.py, generate.py, etc.
        └── tokenizer.model         (~2.1 MB)
```

## Quick Build Scripts

### Windows (Automated):
```cmd
REM Build CPU only
build-cpu-windows.bat

REM Build GPU only
build-gpu-windows.bat

REM Build both CPU + GPU
build-all-windows.bat
```

### macOS/Linux (Automated):
```bash
# CPU only
./build-cpu-macos.sh    # or ./build-cpu-linux.sh

# GPU only
./build-gpu-linux.sh    # (no GPU for macOS)
```

---

## Manual Build Instructions (If Scripts Don't Work)

### CPU Binary (Windows - Visual Studio)

**Prerequisites:**
- Visual Studio 2022 with C++ and Clang/LLVM tools
- CMake 3.14+

**Build Steps:**

1. Open **Visual Studio Developer Command Prompt** (as Administrator)

2. Navigate to BitNet directory:
   ```cmd
   cd E:\Desktop\TabAgent\Server\BitNet
   ```

3. Create build directory:
   ```cmd
   mkdir build
   cd build
   ```

4. Configure with CMake (TL2 kernels for x64):
   ```cmd
   cmake .. -DBITNET_X86_TL2=ON -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -T ClangCL
   ```

5. Build in Release mode:
   ```cmd
   cmake --build . --config Release
   ```

6. Copy binary to Release directory:
   ```cmd
   copy bin\Release\llama-server.exe ..\Release\cpu\windows\
   ```

7. Verify:
   ```cmd
   dir ..\Release\cpu\windows\
   ```

### GPU Kernel (Windows - CUDA)

**Prerequisites:**
- CUDA Toolkit 12.1+ installed
- Python 3.9-3.11
- PyTorch with CUDA support

**Build Steps:**

1. Open **Visual Studio Developer Command Prompt** (as Administrator)

2. Navigate to GPU kernels:
   ```cmd
   cd E:\Desktop\TabAgent\Server\BitNet\gpu\bitnet_kernels
   ```

3. Install PyTorch with CUDA:
   ```cmd
   python -m pip install torch --index-url https://download.pytorch.org/whl/cu121
   ```

4. Build kernel:
   ```cmd
   python setup.py build_ext --inplace
   ```

5. Copy to Release:
   ```cmd
   mkdir ..\..\Release\gpu\windows
   copy *.pyd ..\..\Release\gpu\windows\
   cd ..
   copy *.py ..\Release\gpu\windows\
   copy tokenizer.model ..\Release\gpu\windows\
   ```

6. Verify:
   ```cmd
   dir ..\Release\gpu\windows\
   ```

## Testing

### Test CPU Binary:
```cmd
cd Release\cpu\windows
llama-server.exe --version
```

### Test GPU Kernel:
```cmd
cd Release\gpu\windows
python -c "import bitlinear_cuda; print('GPU kernel loaded!')"
```

## CI/CD Workflow

The GitHub Actions workflow automates all of the above:
- Builds CPU binaries for all platforms
- Builds GPU kernels for Windows/Linux
- Organizes into this Release/ structure
- Creates GitHub Release with BitNet-Release.zip
- Triggers TabAgent to download and integrate

## Notes

- **Windows:** Requires Clang/LLVM for optimal performance
- **macOS:** Requires Apple Clang, uses ARM TL1 kernels
- **Linux:** Requires Clang, uses x86 TL2 kernels
- **GPU:** Only Windows and Linux support CUDA (macOS has no NVIDIA support)

## File Sizes (Approximate)

- `llama-server.exe` (Windows): ~80-120 MB
- `llama-server` (macOS): ~60-90 MB
- `llama-server` (Linux): ~60-90 MB
- `bitlinear_cuda.pyd` (Windows): ~5-15 MB
- `bitlinear_cuda.so` (Linux): ~5-15 MB
- `tokenizer.model`: ~2.1 MB
- Python files: ~100-200 KB total

## Troubleshooting

### CMake can't find Clang
```
Error: Could not find Clang compiler
```
**Solution:** Install "Clang/LLVM" component in Visual Studio Installer

### CUDA not found
```
Error: CUDA toolkit not found
```
**Solution:** Install CUDA Toolkit 12.1+ from NVIDIA website

### Python setup.py fails
```
Error: torch not found
```
**Solution:** Install PyTorch with CUDA support first

### Binary runs but crashes
```
Error: Missing DLL
```
**Solution:** Ensure all dependencies are in PATH or same directory

