# BitNet Python GPU Kernel Build Script for Windows
# This script builds the CUDA kernel for Python inference
# Prerequisites: VS 2022, CUDA Toolkit, PyTorch with CUDA

param(
    [string]$PythonEnv = "bitnet-gpu-env"
)

# Colors
$Green = "$([char]27)[92m"
$Yellow = "$([char]27)[93m"
$Red = "$([char]27)[91m"
$Reset = "$([char]27)[0m"

function Write-Status {
    param([string]$Message, [string]$Color = $Green)
    Write-Host "${Color}${Message}${Reset}"
}

Write-Status "=== BitNet Python GPU Kernel Build Script ==="
Write-Status ""

# 1. Check Python environment
Write-Status "1. Checking Python environment..."
$pythonCmd = Join-Path $PSScriptRoot "$PythonEnv\Scripts\python.exe"
if (!(Test-Path $pythonCmd)) {
    Write-Status "   [FAIL] Python environment not found at $pythonCmd" $Red
    Write-Status "   Run build_complete.ps1 first to create the environment" $Red
    exit 1
}
Write-Status "   [OK] Python environment found"
Write-Status "   Using: $pythonCmd"

# 2. Check PyTorch CUDA
Write-Status "2. Verifying PyTorch CUDA version..."
$torchVersion = & $pythonCmd -c "import torch; print(torch.__version__)" 2>$null
if ($torchVersion -like "*cu121*") {
    Write-Status "   [OK] PyTorch CUDA 12.1: $torchVersion" $Green
} else {
    Write-Status "   [WARN] PyTorch version: $torchVersion (expected cu121)" $Yellow
}

# 3. Set up VS 2022 Build Environment (Force VS 2022, not Insiders!)
Write-Status "3. Setting up VS 2022 Community build environment..."
$vsPath = "C:\Program Files\Microsoft Visual Studio\2022\Community"
$msvcPath = "$vsPath\VC\Tools\MSVC\14.44.35207"

# CRITICAL: Force distutils and PyTorch to use VS 2022 Community (not Insiders!)
$env:DISTUTILS_USE_SDK = "1"
$env:MSSdk = "1"
$env:VS160COMNTOOLS = "$vsPath\Common7\Tools\"
$env:VSINSTALLDIR = "$vsPath\"

# Add MSVC compiler to PATH (put it FIRST to override Insiders)
$env:PATH = "$msvcPath\bin\Hostx64\x64;$env:PATH"

# Set INCLUDE paths (VS 2022 Community paths ONLY)
$env:INCLUDE = @(
    "$msvcPath\include",
    "C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\ucrt",
    "C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\shared",
    "C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\um"
) -join ";"

# Set LIB paths (VS 2022 Community paths ONLY)
$env:LIB = @(
    "$msvcPath\lib\x64",
    "C:\Program Files (x86)\Windows Kits\10\Lib\10.0.26100.0\ucrt\x64",
    "C:\Program Files (x86)\Windows Kits\10\Lib\10.0.26100.0\um\x64"
) -join ";"

# Explicitly set compiler paths for PyTorch
$env:CC = "$msvcPath\bin\Hostx64\x64\cl.exe"
$env:CXX = "$msvcPath\bin\Hostx64\x64\cl.exe"

# Set CUDA paths
$cudaPath = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA"
$cudaVersions = Get-ChildItem $cudaPath -Directory | Where-Object { $_.Name -match "^v\d" } | Sort-Object Name -Descending
if ($cudaVersions) {
    $cudaDir = $cudaVersions[0].FullName
    $env:CUDA_HOME = $cudaDir
    $env:CUDA_PATH = $cudaDir
    $env:PATH = "$cudaDir\bin;$env:PATH"
    Write-Status "   [OK] Using CUDA: $($cudaVersions[0].Name)"
} else {
    Write-Status "   [FAIL] CUDA not found" $Red
    exit 1
}

Write-Status "   [OK] VS 2022 environment configured"

# 4. Build CUDA kernel as DLL (ctypes compatible, like Linux .so)
Write-Status "4. Building BitNet CUDA kernel as DLL..."
Write-Status "   This may take 2-5 minutes..."

$originalLocation = Get-Location
try {
    Set-Location "gpu\bitnet_kernels"
    
    # Build as shared library (DLL) not Python extension
    $nvcc = "$env:CUDA_HOME\bin\nvcc.exe"
    & $nvcc bitnet_kernels.cu `
        -o libbitnet.dll `
        --shared `
        -O3 `
        -use_fast_math `
        -std=c++17 `
        "-gencode=arch=compute_75,code=sm_75" `
        -Xcompiler "/MD"
    
    if ($LASTEXITCODE -ne 0) {
        throw "NVCC compilation failed with exit code $LASTEXITCODE"
    }
    
    Set-Location $originalLocation
    Write-Status "   [OK] CUDA kernel DLL built successfully" $Green
} catch {
    Set-Location $originalLocation -ErrorAction SilentlyContinue
    Write-Status "   [FAIL] CUDA kernel build failed: $_" $Red
    exit 1
}

# 5. Copy to Release folder
Write-Status "5. Copying GPU modules to Release folder..."
New-Item -ItemType Directory -Path "Release\gpu\windows" -Force | Out-Null

# Copy CUDA kernel DLL
if (Test-Path "gpu\bitnet_kernels\libbitnet.dll") {
    Copy-Item "gpu\bitnet_kernels\libbitnet.dll" "Release\gpu\windows\" -Force
    Copy-Item "gpu\bitnet_kernels\libbitnet.lib" "Release\gpu\windows\" -Force -ErrorAction SilentlyContinue
    $dllSize = [math]::Round((Get-Item "gpu\bitnet_kernels\libbitnet.dll").Length/1KB, 1)
    Write-Status "   [OK] CUDA kernel DLL copied (${dllSize} KB)" $Green
} else {
    Write-Status "   [FAIL] libbitnet.dll not found" $Red
    exit 1
}

# Copy Python modules
Copy-Item "gpu\*.py" "Release\gpu\windows\" -Force -ErrorAction SilentlyContinue
Copy-Item "gpu\tokenizer.model" "Release\gpu\windows\" -Force -ErrorAction SilentlyContinue
Write-Status "   [OK] Python modules copied"

# 6. Summary
Write-Status ""
Write-Status "=== Build Complete! ===" $Green
Write-Status ""
Write-Status "GPU modules location: Release\gpu\windows\" $Yellow
Write-Status ""
Write-Status "Files in Release folder:"
Get-ChildItem "Release\gpu\windows\" | ForEach-Object { 
    if ($_.Extension -eq ".dll") {
        Write-Status "   [CUDA DLL] $($_.Name)" $Green
    } elseif ($_.Extension -eq ".py") {
        Write-Status "   [Python] $($_.Name)"
    } else {
        Write-Status "   [OK] $($_.Name)"
    }
}
Write-Status ""
Write-Status "Test the GPU kernel:" $Yellow
Write-Status "   cd Release\gpu\windows"
Write-Status "   `$env:PATH = 'C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8\bin;' + `$env:PATH"
Write-Status "   python -c `"import ctypes; lib=ctypes.CDLL('libbitnet.dll'); print('GPU kernel loaded!')`""
Write-Status ""

