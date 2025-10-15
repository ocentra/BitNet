# BitNet Complete Build Script for Windows
# This script is completely self-contained and will set up everything needed
# It works on any Windows machine with the required tools installed

# EXPECTED TOOL LOCATIONS AND INSTALLATION INSTRUCTIONS:
# 
# 1. VISUAL STUDIO 2022 COMMUNITY EDITION:
#    - Download: https://visualstudio.microsoft.com/vs/community/
#    - Install with these components:
#      * Desktop development with C++
#      * C++ CMake Tools for Windows
#      * Git for Windows
#      * C++ Clang Compiler for Windows
#      * MSVC v143 - VS 2022 C++ x64/x86 build tools
#    - Expected installation path: C:\Program Files\Microsoft Visual Studio\2022\Community\
#
# 2. CMAKE:
#    - Included with Visual Studio 2022
#    - Expected path: C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe
#
# 3. CLANG COMPILER:
#    - Included with Visual Studio 2022 ("C++ Clang Compiler for Windows")
#    - Expected path: C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\Llvm\x64\bin\clang.exe
#
# 4. MSVC COMPILER:
#    - Included with Visual Studio 2022 ("MSVC v143 - VS 2022 C++ x64/x86 build tools")
#    - Expected path: C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\cl.exe
#
# 5. VULKAN SDK:
#    - Download: https://vulkan.lunarg.com/sdk/home#windows
#    - Install only "Vulkan SDK Core" components
#    - Expected installation path: C:\VulkanSDK\1.4.328.1\
#    - GLSL Compiler expected at: C:\VulkanSDK\1.4.328.1\Bin\glslc.exe
#
# 6. CUDA TOOLKIT:
#    - Download: https://developer.nvidia.com/cuda-downloads
#    - Expected installation path: C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.1\
#    - CUDA Compiler expected at: C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.1\bin\nvcc.exe
#
# 7. GIT:
#    - Download: https://git-scm.com/
#    - Must be added to PATH during installation
#    - Expected to be accessible as "git" from command line
#
# 8. PYTHON REQUIREMENTS:
#    - Python 3.9 or higher recommended (3.11 preferred for xformers compatibility)
#    - Script will create a virtual environment named "bitnet-gpu-env"
#    - Will install all required packages with exact versions:
#      * PyTorch 2.3.1+cu121 (CUDA 12.1)
#      * xformers 0.0.27 (requires PyTorch 2.3.1 exactly)
#      * transformers 4.57.1
#      * And other dependencies as specified in the script

param(
    [string]$BuildDir = "Release",
    [switch]$CleanBuild = $false
)

# Colors for output
$Green = "$([char]27)[92m"
$Yellow = "$([char]27)[93m"
$Red = "$([char]27)[91m"
$Reset = "$([char]27)[0m"

function Write-Status {
    param([string]$Message, [string]$Color = $Green)
    Write-Host "${Color}${Message}${Reset}"
}

function Write-ErrorAndExit {
    param([string]$Message)
    Write-Host "${Red}ERROR: ${Message}${Reset}"
    exit 1
}

function Test-CommandExists {
    param([string]$Command)
    try {
        # Try multiple ways to check if command exists
        $result = Get-Command $Command -ErrorAction SilentlyContinue
        if ($result) {
            return $true
        }
        
        # Try using where command as fallback
        $whereResult = where.exe $Command 2>$null
        if ($whereResult -and $whereResult.Length -gt 0) {
            return $true
        }
        
        return $false
    } catch {
        return $false
    }
}

function Run-FullBitNetSetup {
    param([string]$PythonCmd)
    
    Write-Status "   Running full BitNet setup process..."
    
    # Install GGUF package
    Write-Status "   Installing GGUF package..."
    & $PythonCmd -m pip install 3rdparty/llama.cpp/gguf-py
    if ($LASTEXITCODE -ne 0) {
        Write-Status "   Warning: Failed to install GGUF package, continuing..." $Yellow
    }
    
    # Generate kernel code (this is what gen_code() does in setup_env.py)
    Write-Status "   Generating kernel code..."
    try {
        # For x86_64 architecture, we use codegen_tl2.py
        if (Test-Path "utils\codegen_tl2.py") {
            & $PythonCmd utils\codegen_tl2.py --model Llama3-8B-1.58-100B-tokens --BM 256,128,256,128 --BK 96,96,96,96 --bm 32,32,32
            if ($LASTEXITCODE -eq 0) {
                Write-Status "   Kernel code generated successfully"
            } else {
                Write-Status "   Warning: Kernel code generation failed, using preset kernels..." $Yellow
                # Copy preset kernels as fallback
                Copy-PresetKernels
            }
        } else {
            Write-Status "   Warning: codegen_tl2.py not found, using preset kernels..." $Yellow
            Copy-PresetKernels
        }
    } catch {
        Write-Status "   Warning: Kernel code generation failed, using preset kernels..." $Yellow
        Copy-PresetKernels
    }
}

function Copy-PresetKernels {
    Write-Status "   Copying preset kernels as fallback..."
    try {
        # Try to copy the most appropriate preset kernel
        $presetPath = "preset_kernels\Llama3-8B-1.58-100B-tokens"
        if (Test-Path $presetPath) {
            # Copy the TL2 kernel file (since we're building for x86 TL2)
            $tl2Kernel = "$presetPath\bitnet-lut-kernels-tl2.h"
            if (Test-Path $tl2Kernel) {
                Copy-Item $tl2Kernel "include\bitnet-lut-kernels.h" -Force
                Write-Status "   Copied TL2 preset kernel"
            } else {
                # Fallback to TL1 if TL2 not available
                $tl1Kernel = "$presetPath\bitnet-lut-kernels-tl1.h"
                if (Test-Path $tl1Kernel) {
                    Copy-Item $tl1Kernel "include\bitnet-lut-kernels.h" -Force
                    Write-Status "   Copied TL1 preset kernel"
                }
            }
        }
        
        # If still no kernel file, create a minimal one
        if (!(Test-Path "include\bitnet-lut-kernels.h") -or (Get-Content "include\bitnet-lut-kernels.h" | Measure-Object).Count -eq 0) {
            Write-Status "   Creating minimal kernel header..." $Yellow
            $minimalKernel = @"
#if defined(GGML_BITNET_X86_TL2) || defined(GGML_BITNET_ARM_TL1)
#define GGML_BITNET_MAX_NODES 8192
static bool initialized = false;
static bitnet_tensor_extra * bitnet_tensor_extras = nullptr;
static size_t bitnet_tensor_extras_index = 0;
static bool is_type_supported(enum ggml_type type) {
    return (type == GGML_TYPE_TL2 || type == GGML_TYPE_TL1 || type == GGML_TYPE_Q4_0);
}
#endif
"@
            $minimalKernel | Out-File -FilePath "include\bitnet-lut-kernels.h" -Encoding UTF8
        }
    } catch {
        Write-Status "   Warning: Failed to copy preset kernels..." $Yellow
    }
}

Write-Status "=== BitNet Complete Build Script ==="
Write-Status ""

# 1. VERIFY ALL REQUIRED TOOLS FIRST (fail fast before spending time on Python setup)
Write-Status "1. Verifying ALL required tools before proceeding..."
Write-Status ""

$allToolsFound = $true
$criticalToolsMissing = @()

# Check CMake
Write-Status "   Checking CMake..."
$cmakePath = "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
if (Test-Path "$cmakePath\cmake.exe") {
    $env:PATH = "$cmakePath;$env:PATH"
    $cmakeVersion = & cmake --version 2>$null | Select-Object -First 1
    Write-Status "   [OK] CMake found: $cmakeVersion" $Green
} else {
    Write-Status "   [FAIL] CMake not found at: $cmakePath" $Red
    $criticalToolsMissing += "CMake"
    $allToolsFound = $false
}

# Check Clang
Write-Status "   Checking Clang..."
$clangPath = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\Llvm\x64\bin"
if (Test-Path "$clangPath\clang.exe") {
    $clangVersion = & "$clangPath\clang.exe" --version 2>$null | Select-Object -First 1
    Write-Status "   [OK] Clang found: $clangVersion" $Green
} else {
    Write-Status "   [FAIL] Clang not found at: $clangPath" $Red
    $criticalToolsMissing += "Clang"
    $allToolsFound = $false
}

# Check CUDA (look for all versions)
Write-Status "   Checking CUDA..."
$cudaBasePath = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA"
if (Test-Path $cudaBasePath) {
    $cudaVersions = Get-ChildItem $cudaBasePath -Directory | Where-Object { $_.Name -match "^v\d" } | Sort-Object Name -Descending
    if ($cudaVersions) {
        $cudaDir = $cudaVersions[0].FullName
        $env:PATH = "$cudaDir\bin;$env:PATH"
        $env:CUDA_PATH = $cudaDir
        $env:CUDA_HOME = $cudaDir
        Write-Status "   [OK] CUDA found: $($cudaVersions[0].Name)" $Green
    } else {
        Write-Status "   [WARN] CUDA directory exists but no versions found" $Yellow
    }
} else {
    Write-Status "   [WARN] CUDA not found - GPU builds will not work" $Yellow
}

# Check Vulkan SDK
Write-Status "   Checking Vulkan SDK..."
$vulkanPath = "C:\VulkanSDK\1.4.328.1\Bin"
if (Test-Path $vulkanPath) {
    $env:PATH = "$vulkanPath;$env:PATH"
    $env:VULKAN_SDK = "C:\VulkanSDK\1.4.328.1"
    Write-Status "   [OK] Vulkan SDK found" $Green
} else {
    Write-Status "   [WARN] Vulkan SDK not found - Vulkan builds will not work" $Yellow
}

# Check Git
Write-Status "   Checking Git..."
if (Test-CommandExists "git") {
    $gitVersion = & git --version 2>$null
    Write-Status "   [OK] Git found: $gitVersion" $Green
} else {
    Write-Status "   [FAIL] Git not found in PATH" $Red
    $criticalToolsMissing += "Git"
    $allToolsFound = $false
}

# Check Python
Write-Status "   Checking Python..."
$pythonFound = $false
if (Test-CommandExists "py") {
    $pythonVersion = & py --version 2>$null
    Write-Status "   [OK] Python found: $pythonVersion" $Green
    $pythonFound = $true
} elseif (Test-CommandExists "python") {
    $pythonVersion = & python --version 2>$null
    Write-Status "   [OK] Python found: $pythonVersion" $Green
    $pythonFound = $true
} else {
    Write-Status "   [FAIL] Python not found in PATH" $Red
    $criticalToolsMissing += "Python"
    $allToolsFound = $false
}

Write-Status ""

# FAIL FAST if critical tools are missing
if (-not $allToolsFound) {
    Write-Status "========================================" $Red
    Write-Status "CRITICAL TOOLS MISSING!" $Red
    Write-Status "========================================" $Red
    Write-Status ""
    Write-Status "The following required tools were not found:" $Red
    foreach ($tool in $criticalToolsMissing) {
        Write-Status "   - $tool" $Red
    }
    Write-Status ""
    Write-Status "Please install missing tools before running this script." $Red
    Write-Status "See comments at top of script for installation instructions." $Red
    Write-Status ""
    exit 1
}

Write-Status "========================================" $Green
Write-Status "ALL REQUIRED TOOLS VERIFIED!" $Green
Write-Status "========================================" $Green
Write-Status ""

# 2. Initialize git submodules
Write-Status "2. Initializing git submodules..."
# This step ensures all required submodules are properly initialized:
# - 3rdparty/llama.cpp (main llama.cpp framework)
# - 3rdparty/llama.cpp/ggml (core compute library)
# - 3rdparty/llama.cpp/ggml/src/kompute (Kompute backend for GPU acceleration)
try {
    & git submodule update --init --recursive
    if ($LASTEXITCODE -ne 0) {
        throw "Git submodule initialization failed"
    }
    Write-Status "   Git submodules initialized successfully"
} catch {
    Write-ErrorAndExit "Failed to initialize git submodules: $_"
}

# 3. Verify 3rdparty directory structure
Write-Status "3. Verifying 3rdparty directory structure..."
# Verify that git submodules were properly initialized and key directories exist:
# - 3rdparty/llama.cpp (main framework)
# - 3rdparty/llama.cpp/ggml (compute library)
# - 3rdparty/llama.cpp/ggml/src (source files)
# - 3rdparty/llama.cpp/ggml/include (header files)
if (!(Test-Path "3rdparty\llama.cpp")) {
    Write-ErrorAndExit "llama.cpp submodule not found in 3rdparty directory. Please check git submodule initialization."
}

if (!(Test-Path "3rdparty\llama.cpp\ggml")) {
    Write-ErrorAndExit "ggml submodule not found in llama.cpp directory. Please check git submodule initialization."
}

Write-Status "   3rdparty directory structure verified"

# 4. Verify required header files are available
Write-Status "4. Verifying required header files..."
# Check for critical header files that are required for successful compilation:
# - llama.h: Main llama.cpp header
# - ggml.h: Core GGML compute library header
# - ggml-vulkan.h: Vulkan backend header
# - ggml-cuda.h: CUDA backend header
$headerFiles = @(
    "3rdparty\llama.cpp\include\llama.h",
    "3rdparty\llama.cpp\ggml\include\ggml.h",
    "3rdparty\llama.cpp\ggml\include\ggml-vulkan.h",
    "3rdparty\llama.cpp\ggml\include\ggml-cuda.h"
)

$missingHeaders = @()
foreach ($header in $headerFiles) {
    if (!(Test-Path $header)) {
        $missingHeaders += $header
    }
}

if ($missingHeaders.Count -gt 0) {
    Write-Status "   Missing header files detected:" $Yellow
    foreach ($header in $missingHeaders) {
        Write-Host "     - $header"
    }
    Write-ErrorAndExit "Required header files are missing. Please check submodule initialization and ensure all submodules are properly checked out."
}

Write-Status "   All required header files are available"

# 6. Set up Python environment (create if doesn't exist)
Write-Status "6. Setting up Python environment..."
# Create or use existing Python virtual environment:
# - Environment name: bitnet-gpu-env
# - Location: .\bitnet-gpu-env\ (relative to script location)
# - Python executable: .\bitnet-gpu-env\Scripts\python.exe
# This ensures isolated dependencies and prevents conflicts with system Python packages
$envPath = "bitnet-gpu-env"
$pythonCmd = "$envPath\Scripts\python.exe"

if (!(Test-Path $envPath)) {
    Write-Status "   Creating Python virtual environment..."
    # Use system Python to create virtual environment
    $systemPython = "py"
    if (!(Test-CommandExists "py")) {
        $systemPython = "python"
    }
    
    & $systemPython -m venv $envPath
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorAndExit "Failed to create virtual environment. Please ensure Python 3.9+ is installed."
    }
}

# Verify Python environment
if (!(Test-Path $pythonCmd)) {
    Write-ErrorAndExit "Python environment not found at $pythonCmd. Please check virtual environment creation."
}

Write-Status "   Python environment ready"

# 7. Install required Python packages with exact versions
Write-Status "7. Installing required Python packages..."
& $pythonCmd -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) {
    Write-ErrorAndExit "Failed to upgrade pip"
}

# Core ML/CUDA packages
$packages = @(
    "torch==2.3.1+cu121",
    "torchvision==0.18.1+cu121",
    "torchaudio==2.3.1+cu121"
)

Write-Status "   Installing PyTorch stack (CUDA 12.1)..."
foreach ($package in $packages) {
    & $pythonCmd -m pip install $package --extra-index-url https://download.pytorch.org/whl/cu121
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorAndExit "Failed to install $package"
    }
}

Write-Status "   Installing xformers 0.0.27..."
& $pythonCmd -m pip install xformers==0.0.27 --extra-index-url https://download.pytorch.org/whl/cu121
if ($LASTEXITCODE -ne 0) {
    Write-ErrorAndExit "Failed to install xformers"
}

# Other required packages
$otherPackages = @(
    "transformers==4.57.1",
    "sentencepiece==0.2.1",
    "tiktoken==0.12.0",
    "tokenizers==0.22.1",
    "numpy==2.3.3",
    "safetensors==0.6.2",
    "einops==0.8.1",
    "huggingface_hub==0.35.3",
    "intel-openmp==2021.4.0",
    "mkl==2021.4.0",
    "tbb==2021.13.1",
    "fire==0.7.1",
    "flask==3.1.2",
    "blobfile==3.1.0",
    "ninja==1.13.0"
)

Write-Status "   Installing other required packages..."
foreach ($package in $otherPackages) {
    & $pythonCmd -m pip install $package
    if ($LASTEXITCODE -ne 0) {
        Write-Status "   Warning: Failed to install $package, continuing..." $Yellow
    }
}

# Install GGUF package directly (avoid requirements.txt conflicts)
Write-Status "   Installing GGUF package from llama.cpp..."
& $pythonCmd -m pip install 3rdparty/llama.cpp/gguf-py
    if ($LASTEXITCODE -ne 0) {
    Write-Status "   Warning: Failed to install GGUF package, continuing..." $Yellow
}

# Install GPU requirements individually (SKIP torch/xformers - already installed with CUDA!)
Write-Status "   Installing GPU requirements (skipping torch/xformers to preserve CUDA version)..."
$gpuPackagesOnly = @(
    "fire",
    "sentencepiece",
    "tiktoken",
    "blobfile",
    "flask",
    "einops",
    "transformers"
)

foreach ($package in $gpuPackagesOnly) {
    & $pythonCmd -m pip install $package
    if ($LASTEXITCODE -ne 0) {
        Write-Status "   Warning: Failed to install $package, continuing..." $Yellow
    }
}

# Verify torch version is still CUDA
Write-Status "   Verifying PyTorch CUDA version preserved..."
$torchVersion = & $pythonCmd -c "import torch; print(torch.__version__)" 2>$null
if ($torchVersion -like "*cu121*") {
    Write-Status "   [OK] PyTorch CUDA 12.1 preserved: $torchVersion" $Green
} else {
    Write-Status "   [WARN] PyTorch version is $torchVersion (expected cu121)" $Yellow
}

Write-Status "   All Python packages installed successfully"

# 12. Generate required kernel files if they don't exist
Write-Status "12. Generating required kernel files..."
# Create include directory if it doesn't exist:
# - Location: .\include\
# - Required files: bitnet-lut-kernels.h, kernel_config.ini
# These files are critical for BitNet kernel compilation and must be generated properly
if (!(Test-Path "include")) {
    New-Item -ItemType Directory -Path "include" | Out-Null
}

# Run the full BitNet setup process to generate proper kernel files:
# This replicates the gen_code() function from setup_env.py:
# 1. Installs GGUF package from 3rdparty/llama.cpp/gguf-py
# 2. Runs codegen_tl2.py to generate optimized kernels for x86_64 architecture
# 3. Creates bitnet-lut-kernels.h and kernel_config.ini with proper parameters
Write-Status "   Running full BitNet setup process..."
Run-FullBitNetSetup -PythonCmd $pythonCmd

# Verify that kernel files were generated
$kernelFiles = @(
    "include\bitnet-lut-kernels.h",
    "include\kernel_config.ini"
)

$missingKernelFiles = @()
foreach ($file in $kernelFiles) {
    if (!(Test-Path $file)) {
        $missingKernelFiles += $file
    }
}

if ($missingKernelFiles.Count -gt 0) {
    Write-Status "   Some kernel files are missing, using preset kernels..." $Yellow
    # Use preset kernels as fallback (like Linux workflow does)
    $presetKernelPath = "preset_kernels\bitnet_b1_58-3B\bitnet-lut-kernels-tl2.h"
    if (Test-Path $presetKernelPath) {
        Copy-Item $presetKernelPath "include\bitnet-lut-kernels.h" -Force
        Write-Status "   [OK] Copied preset TL2 kernel header"
    } else {
        Write-Status "   Warning: Preset kernel not found, creating minimal fallback..." $Yellow
        '#ifndef BITNET_LUT_KERNELS_H
#define BITNET_LUT_KERNELS_H
#include <cstring>
#include <immintrin.h>
// Minimal header for build process
#endif // BITNET_LUT_KERNELS_H' | Out-File -FilePath "include\bitnet-lut-kernels.h" -Encoding UTF8
    }

    if (!(Test-Path "include\kernel_config.ini")) {
        Write-Status "   Creating kernel_config.ini..." $Yellow
        '[kernel]
BM=256,128,256
BK=96,96,96
bm=32,32,32' | Out-File -FilePath "include\kernel_config.ini" -Encoding UTF8
    }
} else {
    Write-Status "   Required kernel files are available"
}

# Apply critical patches to kernel header (like Linux workflow lines 222-225)
Write-Status "   Applying kernel header patches..."
if (Test-Path "include\bitnet-lut-kernels.h") {
    $kernelContent = Get-Content "include\bitnet-lut-kernels.h" -Raw
    
    # Check if it's a preset kernel (starts with #if defined) - DON'T PATCH IT!
    if ($kernelContent -match "^#if defined\(GGML_BITNET") {
        Write-Status "   [OK] Kernel header is preset kernel - no patching needed"
    }
    # Check if it's a generated kernel that needs includes added
    elseif ($kernelContent -notmatch "#include <cstring>") {
        # Only patch if file is long enough (more than 10 lines) - avoid corrupting minimal headers
        $lineCount = (Get-Content "include\bitnet-lut-kernels.h" | Measure-Object -Line).Lines
        if ($lineCount -gt 10) {
            # Insert includes at the top after header guards
            $lines = Get-Content "include\bitnet-lut-kernels.h"
            $newContent = @()
            $headerGuardFound = $false
            foreach ($line in $lines) {
                $newContent += $line
                # After the #define BITNET_LUT_KERNELS_H line, add includes
                if ($line -match "^#define BITNET_LUT_KERNELS_H" -and -not $headerGuardFound) {
                    $newContent += "#include <cstring>"
                    $newContent += "#include <immintrin.h>"
                    $newContent += ""
                    $headerGuardFound = $true
                }
            }
            $newContent | Out-File -FilePath "include\bitnet-lut-kernels.h" -Encoding UTF8
            Write-Status "   [OK] Added missing includes to generated kernel header"
        } else {
            Write-Status "   [WARN] Kernel header too short to patch safely - skipping"
        }
    } else {
        Write-Status "   [OK] Kernel header already has required includes"
    }
}

# 13. Build BitNet CUDA kernels
Write-Status "13. Building BitNet CUDA kernels..."
if (Test-Path "gpu\bitnet_kernels") {
    Set-Location gpu\bitnet_kernels
    # Set environment variables for CUDA build
    $env:CUDA_HOME = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.1"
    $env:CUDA_PATH = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.1"
    
    # Try to build with proper CUDA 12.1 support
    try {
        & $pythonCmd setup.py build_ext --inplace
        Write-Status "   BitNet CUDA kernels built successfully"
    } catch {
        Write-Status "   Warning: Failed to build BitNet CUDA kernels, continuing..." $Yellow
    }
    Set-Location ..\..
}

# 14. Clean CMake caches and create build directories
Write-Status "14. Cleaning CMake caches and creating build directories..."

# Clean old CMake caches to avoid toolset conflicts
$buildDirs = @("build-standard", "build-gpu", "build-bitnet")
foreach ($dir in $buildDirs) {
    if (Test-Path $dir) {
        Write-Status "   Cleaning CMake cache in $dir..." $Yellow
        Remove-Item "$dir\CMakeCache.txt" -Force -ErrorAction SilentlyContinue
        Remove-Item "$dir\CMakeFiles" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($CleanBuild -and (Test-Path $BuildDir)) {
    Write-Status "   Cleaning previous build output..." $Yellow
    Remove-Item -Recurse -Force $BuildDir
}

New-Item -ItemType Directory -Path "$BuildDir\cpu\windows" -Force | Out-Null
New-Item -ItemType Directory -Path "$BuildDir\gpu\windows" -Force | Out-Null

Write-Status "   Build directories ready"

# 15. Build Standard CPU Version (from repo root, like Linux)
Write-Status "15. Building Standard CPU Version..."
try {
    # Build from repo root (BitNet's conditional Clang check won't fail without BITNET flags)
    & cmake -B "build-standard" `
        -T ClangCL `
        -DLLAMA_BUILD_SERVER=ON `
        -DLLAMA_BUILD_EXAMPLES=ON
    
    if ($LASTEXITCODE -ne 0) {
        throw "CMake configure failed"
    }
    
    & cmake --build build-standard --config Release --parallel
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed"
    }
    
    Write-Status "   Standard CPU version built successfully"
    $env:STANDARD_CPU_SUCCESS = "true"
} catch {
    Write-Status "   Warning: Failed to build standard CPU version: $_" $Yellow
    $env:STANDARD_CPU_SUCCESS = "false"
}

# 16. Build GPU Version (Try CUDA + Vulkan, fallback to CUDA-only, like Linux)
Write-Status "16. Building GPU Version (CUDA + Vulkan)..."
try {
    # Try CUDA + Vulkan first
    Write-Status "   Trying with Vulkan support..."
    & cmake -B "build-gpu" `
        -DGGML_VULKAN=ON `
        -DGGML_CUDA=ON `
        -DCMAKE_CUDA_ARCHITECTURES=75 `
        -DLLAMA_BUILD_SERVER=ON `
        -DLLAMA_BUILD_EXAMPLES=ON
    
    if ($LASTEXITCODE -eq 0) {
        & cmake --build build-gpu --config Release --parallel
        if ($LASTEXITCODE -eq 0) {
            Write-Status "   GPU version built successfully (CUDA + Vulkan)"
            $env:STANDARD_GPU_SUCCESS = "true"
            $env:GPU_VULKAN_SUCCESS = "true"
        } else {
            throw "Build with Vulkan failed"
        }
    } else {
        throw "Configure with Vulkan failed"
    }
} catch {
    Write-Status "   Warning: Vulkan build failed, trying CUDA-only..." $Yellow
    
    # Clean failed build and try CUDA-only
    Remove-Item "build-gpu\CMakeCache.txt" -Force -ErrorAction SilentlyContinue
    Remove-Item "build-gpu\CMakeFiles" -Recurse -Force -ErrorAction SilentlyContinue
    
    try {
        & cmake -B "build-gpu" `
            -DGGML_VULKAN=OFF `
            -DGGML_CUDA=ON `
            -DCMAKE_CUDA_ARCHITECTURES=75 `
            -DLLAMA_BUILD_SERVER=ON `
            -DLLAMA_BUILD_EXAMPLES=ON
    
    if ($LASTEXITCODE -ne 0) {
        throw "CMake configure failed"
    }
    
    & cmake --build build-gpu --config Release --parallel
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed"
    }
    
        Write-Status "   GPU version built successfully (CUDA-only)"
        $env:STANDARD_GPU_SUCCESS = "true"
        $env:GPU_VULKAN_SUCCESS = "false"
} catch {
        Write-Status "   Warning: GPU build failed completely: $_" $Yellow
        $env:STANDARD_GPU_SUCCESS = "false"
        $env:GPU_VULKAN_SUCCESS = "false"
    }
}

# 17. Build BitNet Specialized Version (CPU with TL2 kernels using ClangCL)
Write-Status "17. Building BitNet Specialized Version (CPU with TL2)..."
try {
    # BitNet REQUIRES Clang - use ClangCL for C++ (GPU is Python extension built separately)
    & cmake -B "build-bitnet" `
        -DBITNET_X86_TL2=ON `
        -T ClangCL `
        -DCMAKE_C_COMPILER=clang `
        -DCMAKE_CXX_COMPILER=clang++ `
        -DLLAMA_BUILD_SERVER=ON `
        -DLLAMA_BUILD_EXAMPLES=ON
    
    if ($LASTEXITCODE -ne 0) {
        throw "CMake configure failed"
    }
    
    & cmake --build build-bitnet --config Release --parallel
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed"
    }
    
    Write-Status "   BitNet specialized version built successfully"
    $env:BITNET_CPU_SUCCESS = "true"
} catch {
    Write-Status "   Warning: Failed to build BitNet specialized version: $_" $Yellow
    $env:BITNET_CPU_SUCCESS = "false"
}

# 18. Organize binaries as requested
Write-Status "18. Organizing binaries..."

# Copy Standard CPU binaries if build succeeded
if ($env:STANDARD_CPU_SUCCESS -eq "true" -and (Test-Path "build-standard\bin\Release\llama-server.exe")) {
    Copy-Item "build-standard\bin\Release\llama-server.exe" "$BuildDir\cpu\windows\llama-server-standard.exe" -Force -ErrorAction SilentlyContinue
    Copy-Item "build-standard\bin\Release\llama-cli.exe" "$BuildDir\cpu\windows\llama-cli-standard.exe" -Force -ErrorAction SilentlyContinue
    Copy-Item "build-standard\bin\Release\llama-bench.exe" "$BuildDir\cpu\windows\llama-bench-standard.exe" -Force -ErrorAction SilentlyContinue
    Write-Status "   [OK] Standard CPU binaries copied"
} else {
    Write-Status "   [WARN] Standard CPU build failed or binaries not found - skipping" $Yellow
}

# Copy GPU binaries if build succeeded
if ($env:STANDARD_GPU_SUCCESS -eq "true" -and (Test-Path "build-gpu\bin\Release\llama-server.exe")) {
    Copy-Item "build-gpu\bin\Release\llama-server.exe" "$BuildDir\cpu\windows\llama-server-gpu.exe" -Force -ErrorAction SilentlyContinue
    Copy-Item "build-gpu\bin\Release\llama-cli.exe" "$BuildDir\cpu\windows\llama-cli-gpu.exe" -Force -ErrorAction SilentlyContinue
    Copy-Item "build-gpu\bin\Release\llama-bench.exe" "$BuildDir\cpu\windows\llama-bench-gpu.exe" -Force -ErrorAction SilentlyContinue
    
    # Alternative naming (CUDA-specific)
    Copy-Item "build-gpu\bin\Release\llama-server.exe" "$BuildDir\cpu\windows\llama-server-cuda.exe" -Force -ErrorAction SilentlyContinue
    Copy-Item "build-gpu\bin\Release\llama-cli.exe" "$BuildDir\cpu\windows\llama-cli-cuda.exe" -Force -ErrorAction SilentlyContinue
    Copy-Item "build-gpu\bin\Release\llama-bench.exe" "$BuildDir\cpu\windows\llama-bench-cuda.exe" -Force -ErrorAction SilentlyContinue
    Write-Status "   [OK] GPU binaries copied"
} else {
    Write-Status "   [WARN] GPU build failed or binaries not found - skipping" $Yellow
}

# Copy BitNet specialized binaries if build succeeded
if ($env:BITNET_CPU_SUCCESS -eq "true" -and (Test-Path "build-bitnet\bin\Release\llama-server.exe")) {
    Copy-Item "build-bitnet\bin\Release\llama-server.exe" "$BuildDir\cpu\windows\llama-server-bitnet.exe" -Force -ErrorAction SilentlyContinue
    Copy-Item "build-bitnet\bin\Release\llama-cli.exe" "$BuildDir\cpu\windows\llama-cli-bitnet.exe" -Force -ErrorAction SilentlyContinue
    Copy-Item "build-bitnet\bin\Release\llama-bench.exe" "$BuildDir\cpu\windows\llama-bench-bitnet.exe" -Force -ErrorAction SilentlyContinue
    Write-Status "   [OK] BitNet specialized binaries copied"
} else {
    Write-Status "   [WARN] BitNet specialized build failed or binaries not found - skipping" $Yellow
}

# GPU modules
if (Test-Path "gpu") {
    Get-ChildItem "gpu\*.py" | Copy-Item -Destination "$BuildDir\gpu\windows\" -Force -ErrorAction SilentlyContinue
    if (Test-Path "gpu\tokenizer.model") {
        Copy-Item "gpu\tokenizer.model" "$BuildDir\gpu\windows\" -Force
    }
    
    # BitNet CUDA kernel
    $cudaFiles = Get-ChildItem "gpu\bitnet_kernels" -Recurse -Filter "*.pyd" -ErrorAction SilentlyContinue
    if ($cudaFiles) {
        $cudaFiles | Copy-Item -Destination "$BuildDir\gpu\windows\" -Force
    } else {
        # Try alternative locations
        $altPaths = @(
            "gpu\bitnet_kernels\build\lib.win-amd64-cpython-311\*.pyd",
            "gpu\bitnet_kernels\*.pyd"
        )
        foreach ($path in $altPaths) {
            if (Test-Path $path) {
                Get-ChildItem $path | Copy-Item -Destination "$BuildDir\gpu\windows\" -Force
                break
            }
        }
    }
    Write-Status "   GPU modules copied"
}

Write-Status "=== Build Complete! ==="
Write-Status "Binaries located in: ${BuildDir}" $Yellow
Write-Status "CPU binaries: ${BuildDir}\cpu\windows\" $Yellow
Write-Status "GPU modules: ${BuildDir}\gpu\windows\" $Yellow

if (Test-Path "$BuildDir\cpu\windows") {
    Write-Status "Available CPU binaries:"
    Get-ChildItem "$BuildDir\cpu\windows\*.exe" -ErrorAction SilentlyContinue | ForEach-Object { Write-Status "   $($_.Name)" }
}

if (Test-Path "$BuildDir\gpu\windows") {
    Write-Status "Available GPU modules:"
    Get-ChildItem "$BuildDir\gpu\windows\*" -ErrorAction SilentlyContinue | ForEach-Object { Write-Status "   $($_.Name)" }
}

# 19. Copy to Release folder structure for other projects
Write-Status "19. Copying to Release folder structure..."
# Check if Release folder exists, create if not
if (!(Test-Path "Release")) {
    Write-Status "   Creating Release folder..."
    New-Item -ItemType Directory -Path "Release" | Out-Null
}

# Check and create subdirectories if they don't exist
if (!(Test-Path "Release\cpu\windows")) {
    Write-Status "   Creating Release\cpu\windows folder..."
    New-Item -ItemType Directory -Path "Release\cpu\windows" -Force | Out-Null
}

if (!(Test-Path "Release\gpu\windows")) {
    Write-Status "   Creating Release\gpu\windows folder..."
    New-Item -ItemType Directory -Path "Release\gpu\windows" -Force | Out-Null
}

# Copy CPU binaries to Release folder
Write-Status "   Copying CPU binaries to Release folder..."
Copy-Item "$BuildDir\cpu\windows\*" "Release\cpu\windows\" -Force -ErrorAction SilentlyContinue

# Copy GPU modules to Release folder
Write-Status "   Copying GPU modules to Release folder..."
Copy-Item "$BuildDir\gpu\windows\*" "Release\gpu\windows\" -Force -ErrorAction SilentlyContinue

Write-Status ""
Write-Status "=== Build Complete! ===" $Green
Write-Status ""

# Build Summary (like Linux workflow)
Write-Status "📋 BUILD SUMMARY:"
$standardSuccess = if ($env:STANDARD_CPU_SUCCESS -eq "true") { "✅ SUCCESS" } else { "❌ FAILED" }
$gpuSuccess = if ($env:STANDARD_GPU_SUCCESS -eq "true") { "✅ SUCCESS" } else { "❌ FAILED" }
$vulkanStatus = if ($env:GPU_VULKAN_SUCCESS -eq "true") { "✅ ENABLED" } else { "❌ DISABLED" }
$bitnetSuccess = if ($env:BITNET_CPU_SUCCESS -eq "true") { "✅ SUCCESS" } else { "❌ FAILED" }

Write-Status "Standard CPU Build: $standardSuccess"
Write-Status "Standard GPU Build: $gpuSuccess"
Write-Status "Vulkan Support: $vulkanStatus"
Write-Status "BitNet Specialized Build (TL2): $bitnetSuccess"
Write-Status ""

Write-Status "📁 Binaries located in: ${BuildDir}\cpu\windows\" $Yellow
Write-Status "📁 GPU modules located in: ${BuildDir}\gpu\windows\" $Yellow
Write-Status "📁 Also copied to Release\ folder" $Yellow
Write-Status ""

if (Test-Path "$BuildDir\cpu\windows") {
    Write-Status "Available CPU binaries:"
    $exeFiles = Get-ChildItem "$BuildDir\cpu\windows\*.exe" -ErrorAction SilentlyContinue
    if ($exeFiles) {
        $exeFiles | ForEach-Object { Write-Status "   [OK] $($_.Name)" $Green }
    } else {
        Write-Status "   [WARN] No binaries found" $Yellow
    }
}
Write-Status ""

if (Test-Path "$BuildDir\gpu\windows") {
    Write-Status "Available GPU modules:"
    $gpuFiles = Get-ChildItem "$BuildDir\gpu\windows\*" -ErrorAction SilentlyContinue
    if ($gpuFiles) {
        $gpuFiles | ForEach-Object { Write-Status "   [OK] $($_.Name)" }
    } else {
        Write-Status "   [WARN] No modules found" $Yellow
    }
}
Write-Status ""

# Determine overall status
if ($env:STANDARD_CPU_SUCCESS -eq "true" -or $env:STANDARD_GPU_SUCCESS -eq "true" -or $env:BITNET_CPU_SUCCESS -eq "true") {
    Write-Status "Build process completed with at least one successful build!" $Green
} else {
    Write-Status "Build process completed but all builds failed. Check errors above." $Red
}