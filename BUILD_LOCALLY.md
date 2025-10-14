# Build BitNet Locally (Windows + Linux GPU)

This guide shows how to build Windows and Linux binaries locally, since:
- **Windows**: You have VS 2022, CUDA, NVIDIA GPU
- **Linux**: You can use WSL2 or Docker with CUDA
- **macOS**: GitHub Actions handles this (no GPU needed)

---

## **Why Build Locally?**

1. ✅ **More Reliable** - Test GPU before releasing
2. ✅ **Faster** - No waiting for CI
3. ✅ **Control** - Ensure quality builds
4. ✅ **Practical** - macOS on CI, Windows/Linux local

---

## **1. Build Windows (Your PC)**

### **Prerequisites:**
- ✅ You already have everything!
- Visual Studio 2022 with Clang
- CUDA Toolkit 12.1+
- NVIDIA GPU

### **Build:**
```cmd
cd E:\Desktop\TabAgent\Server\BitNet
build-all-windows.bat
```

### **Expected Output:**
```
Release/cpu/windows/llama-server.exe (~80-120 MB)
Release/gpu/windows/
├── bitlinear_cuda.pyd (~5-15 MB)
└── *.py files
```

### **Test:**
```cmd
cd Release\cpu\windows
llama-server.exe --help

cd ..\..\..\Release\gpu\windows
python -c "import bitlinear_cuda; print('✅ GPU works!')"
```

---

## **2. Build Linux GPU**

You have **3 options** for building Linux with GPU:

### **Option A: WSL2 with CUDA (Recommended if available)**

**Setup WSL2 with CUDA (one-time):**
```powershell
# On Windows PowerShell:
wsl --install Ubuntu-22.04
wsl --set-default Ubuntu-22.04

# Inside WSL2:
sudo apt-get update
sudo apt-get install cmake clang build-essential python3 python3-pip

# Install CUDA in WSL2 (follow NVIDIA WSL2 CUDA guide)
wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.0-1_all.deb
sudo dpkg -i cuda-keyring_1.0-1_all.deb
sudo apt-get update
sudo apt-get install cuda-toolkit-12-1
```

**Build:**
```bash
cd /mnt/e/Desktop/TabAgent/Server/BitNet
chmod +x *.sh
./build-all-linux.sh
```

**Expected Output:**
```
Release/cpu/linux/llama-server (~60-90 MB)
Release/gpu/linux/
├── bitlinear_cuda.so (~5-15 MB)
└── *.py files
```

---

### **Option B: Docker with NVIDIA GPU**

**Prerequisites:**
- Docker Desktop with WSL2 backend
- NVIDIA Container Toolkit

**Build:**
```bash
# Pull NVIDIA CUDA Docker image
docker pull nvidia/cuda:12.1.0-devel-ubuntu22.04

# Run build in container
docker run --rm --gpus all \
  -v E:\Desktop\TabAgent\Server\BitNet:/workspace \
  nvidia/cuda:12.1.0-devel-ubuntu22.04 \
  bash -c "
    apt-get update && \
    apt-get install -y cmake clang python3 python3-pip && \
    cd /workspace && \
    chmod +x *.sh && \
    ./build-all-linux.sh
  "

# Output appears in Release/ on Windows side
```

---

### **Option C: Linux VM or Physical Machine**

If you have access to a Linux machine with NVIDIA GPU:

```bash
cd /path/to/BitNet
chmod +x *.sh
./build-all-linux.sh
```

Then copy `Release/` folder to Windows.

---

## **3. macOS (GitHub Actions)**

Don't build macOS locally - let GitHub Actions handle it!

**Trigger CI:**
```bash
# From your BitNet fork
git push origin main
# Workflow builds macOS automatically
```

**Or manually trigger:**
1. Go to: https://github.com/ocentra/BitNet/actions
2. Select "Build macOS Binaries Only"
3. Click "Run workflow"
4. Download artifacts from workflow run

---

## **4. Create Complete Release**

### **Organize All Binaries:**

After building Windows and Linux locally:

```
Release/
├── cpu/
│   ├── windows/llama-server.exe (from local Windows)
│   ├── macos/llama-server (download from GitHub Actions)
│   └── linux/llama-server (from WSL2/Docker)
│
└── gpu/
    ├── windows/*.pyd + *.py (from local Windows)
    ├── macos/*.py (download from GitHub Actions)
    └── linux/*.so + *.py (from WSL2/Docker)
```

### **Create Release Archive:**

**On Windows:**
```cmd
cd E:\Desktop\TabAgent\Server\BitNet\Release

REM Download macOS binaries from GitHub Actions first
REM Then create zip:
tar -czf BitNet-Release-Complete.zip cpu/ gpu/
```

**Or manually on GitHub:**
1. Create new release: https://github.com/ocentra/BitNet/releases/new
2. Tag: `build-manual-1` (or version number)
3. Upload files:
   - `cpu/windows/llama-server.exe`
   - `cpu/macos/llama-server` (from Actions)
   - `cpu/linux/llama-server`
   - `gpu/windows/*.pyd` + `*.py`
   - `gpu/macos/*.py` (from Actions)
   - `gpu/linux/*.so` + `*.py`
4. Or upload `BitNet-Release-Complete.zip`

---

## **5. Update TabAgent to Download**

Once release is created, trigger TabAgent build:

**Manual Trigger:**
```bash
cd E:\Desktop\TabAgent
# Update .github/workflows/build-and-deploy.yml to point to your release

# Or trigger manually with release version:
# Go to Actions → Build and Deploy → Run workflow
# Specify BitNet release tag
```

**Or just test locally:**
1. Extract `BitNet-Release-Complete.zip`
2. Copy to `E:\Desktop\TabAgent\Server\backends/bitnet/`
3. Build TabAgent native host
4. Test!

---

## **Quick Command Reference**

| Platform | Command | Time |
|----------|---------|------|
| **Windows** | `build-all-windows.bat` | 5-15 min |
| **Linux (WSL2)** | `./build-all-linux.sh` | 5-15 min |
| **Linux (Docker)** | `docker run ... (see above)` | 10-20 min |
| **macOS** | Let GitHub Actions handle it | 5-10 min |

---

## **Troubleshooting**

### **WSL2 doesn't see NVIDIA GPU**
```bash
# Test GPU visibility:
nvidia-smi
# If error, install NVIDIA CUDA drivers for WSL2
```

### **Docker GPU not working**
```bash
# Test Docker GPU access:
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
# If error, install NVIDIA Container Toolkit
```

### **Build script not executable**
```bash
chmod +x *.sh
```

---

## **Summary: Your Workflow**

```
┌─────────────────────────────────────────┐
│ 1. Build Windows (your PC)             │
│    → build-all-windows.bat             │
│    → Release/cpu/windows + gpu/windows │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ 2. Build Linux (WSL2 or Docker)        │
│    → ./build-all-linux.sh              │
│    → Release/cpu/linux + gpu/linux     │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ 3. Trigger macOS (GitHub Actions)      │
│    → git push or manual trigger        │
│    → Download artifacts                 │
│    → Release/cpu/macos + gpu/macos     │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ 4. Create Complete Release             │
│    → Zip all Release/                   │
│    → Upload to GitHub Release           │
│    → Trigger TabAgent                   │
└─────────────────────────────────────────┘
```

**Clean, reliable, fully tested binaries! 🚀**

