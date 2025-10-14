# llama.cpp GPU Build Options

## Summary
The BitNet repository is based on **llama.cpp**, which means we can build BOTH:
1. **BitNet specialized binaries** (1.58-bit ternary quantization)
2. **Standard llama.cpp binaries** (all GGUF formats with GPU support)

---

## GPU Backend Options

### 1. **CUDA (NVIDIA GPUs)**
**CMake Flag:** `-DGGML_CUDA=ON`

**Requirements:**
- NVIDIA GPU with CUDA Compute Capability 6.0+ (Pascal or newer)
- CUDA Toolkit 11.8+ or 12.x
- cuBLAS library

**Build Command:**
```bash
cmake -B build -DGGML_CUDA=ON -DLLAMA_BUILD_SERVER=ON
cmake --build build --config Release -j
```

**Additional CUDA Options:**
- `-DGGML_CUDA_FORCE_CUBLAS=ON` - Always use cuBLAS (better performance)
- `-DGGML_CUDA_F16=ON` - Use FP16 for some calculations
- `-DGGML_CUDA_GRAPHS=ON` - Use CUDA graphs (enabled by default in llama.cpp)

---

### 2. **Vulkan (Cross-platform: NVIDIA, AMD, Intel)**
**CMake Flag:** `-DGGML_VULKAN=ON`

**Requirements:**
- Vulkan SDK (from LunarG)
- Compatible GPU driver with Vulkan support

**Build Command:**
```bash
cmake -B build -DGGML_VULKAN=ON -DLLAMA_BUILD_SERVER=ON
cmake --build build --config Release -j
```

**Advantages:**
- ✅ Works on NVIDIA, AMD, and Intel GPUs
- ✅ Cross-platform (Windows, Linux, macOS with MoltenVK)
- ✅ Good performance, especially on AMD

**Additional Vulkan Options:**
- `-DGGML_VULKAN_DEBUG=ON` - Enable debug output
- `-DGGML_VULKAN_VALIDATE=ON` - Enable validation layers

---

### 3. **ROCm/HIP (AMD GPUs)**
**CMake Flag:** `-DGGML_HIPBLAS=ON`

**Requirements:**
- AMD GPU (RX 5000 series or newer recommended)
- ROCm 5.0+ toolkit

**Build Command:**
```bash
cmake -B build -DGGML_HIPBLAS=ON -DLLAMA_BUILD_SERVER=ON
cmake --build build --config Release -j
```

---

### 4. **Metal (macOS - Apple Silicon & Intel)**
**CMake Flag:** `-DGGML_METAL=ON`

**Requirements:**
- macOS 11.0+
- Apple Silicon (M1/M2/M3) or Intel GPU

**Build Command:**
```bash
cmake -B build -DGGML_METAL=ON -DLLAMA_BUILD_SERVER=ON
cmake --build build --config Release -j
```

**Note:** Metal is automatically enabled on macOS by default.

---

## Build Strategy for TabAgent

### Proposed Output Structure:
```
Server/BitNet/Release/
├── cpu/
│   ├── windows/
│   │   ├── llama-server-bitnet.exe     (BitNet 1.58 specialized)
│   │   └── llama-server-standard.exe   (Regular GGUF + CUDA)
│   ├── macos/
│   │   ├── llama-server-bitnet         (BitNet 1.58 specialized)
│   │   └── llama-server-standard       (Regular GGUF + Metal)
│   └── linux/
│       ├── llama-server-bitnet         (BitNet 1.58 specialized)
│       └── llama-server-standard       (Regular GGUF + CUDA/Vulkan)
└── gpu/
    ├── windows/
    │   └── bitlinear_cuda.pyd          (BitNet GPU kernels)
    ├── macos/
    │   └── [Python modules]
    └── linux/
        └── libbitnet.so                (BitNet GPU kernels)
```

### Build Commands:

#### **Windows (CUDA + Vulkan)**
```batch
REM BitNet specialized
cmake -B build-bitnet -DGGML_CUDA=OFF -DLLAMA_BUILD_SERVER=ON
cmake --build build-bitnet --config Release -j
copy build-bitnet\bin\Release\llama-server.exe Release\cpu\windows\llama-server-bitnet.exe

REM Standard with CUDA + Vulkan
cmake -B build-standard -DGGML_CUDA=ON -DGGML_VULKAN=ON -DLLAMA_BUILD_SERVER=ON
cmake --build build-standard --config Release -j
copy build-standard\bin\Release\llama-server.exe Release\cpu\windows\llama-server-standard.exe

REM GPU kernels (BitNet)
python gpu\build.py
```

#### **Linux (CUDA + Vulkan)**
```bash
# BitNet specialized
cmake -B build-bitnet -DGGML_CUDA=OFF -DLLAMA_BUILD_SERVER=ON
cmake --build build-bitnet --config Release -j
cp build-bitnet/bin/llama-server Release/cpu/linux/llama-server-bitnet

# Standard with CUDA + Vulkan
cmake -B build-standard -DGGML_CUDA=ON -DGGML_VULKAN=ON -DLLAMA_BUILD_SERVER=ON
cmake --build build-standard --config Release -j
cp build-standard/bin/llama-server Release/cpu/linux/llama-server-standard

# GPU kernels (BitNet)
python3 gpu/build.py
```

#### **macOS (Metal)**
```bash
# BitNet specialized
cmake -B build-bitnet -DGGML_METAL=OFF -DLLAMA_BUILD_SERVER=ON
cmake --build build-bitnet --config Release -j
cp build-bitnet/bin/llama-server Release/cpu/macos/llama-server-bitnet

# Standard with Metal
cmake -B build-standard -DGGML_METAL=ON -DLLAMA_BUILD_SERVER=ON
cmake --build build-standard --config Release -j
cp build-standard/bin/llama-server Release/cpu/macos/llama-server-standard
```

---

## Performance Comparison

| Backend | NVIDIA | AMD | Intel | Apple | Cross-platform |
|---------|--------|-----|-------|-------|----------------|
| CUDA    | ⭐⭐⭐⭐⭐ | ❌ | ❌ | ❌ | ❌ |
| Vulkan  | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ✅ |
| ROCm    | ❌ | ⭐⭐⭐⭐⭐ | ❌ | ❌ | ❌ |
| Metal   | ❌ | ❌ | ❌ | ⭐⭐⭐⭐⭐ | ❌ |

**Recommendation for TabAgent:**
- **Windows/Linux:** Build with both **CUDA** (best NVIDIA performance) + **Vulkan** (AMD/Intel fallback)
- **macOS:** Build with **Metal** (best performance on Apple Silicon)

---

## Benefits of This Approach

✅ **Full Backend Control** - No LM Studio dependency  
✅ **GPU Acceleration** - For both BitNet and regular models  
✅ **One Build Process** - Build everything at once  
✅ **Smaller Footprint** - Just binaries, no wrapper apps  
✅ **Consistent Architecture** - Both backends use llama.cpp  
✅ **Cross-GPU Support** - CUDA, Vulkan, Metal, ROCm  

---

## Next Steps

1. ✅ Document GPU options (THIS FILE)
2. ⏳ Update build scripts to build both BitNet + Standard binaries
3. ⏳ Test GPU acceleration on all platforms
4. ⏳ Update native host to route to appropriate binary
5. ⏳ (Later) Remove LM Studio dependency entirely

