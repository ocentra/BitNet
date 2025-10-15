# Vulkan SDK Setup Helper for Windows
# This script helps configure Vulkan SDK for BitNet builds

# Colors
$Green = "$([char]27)[92m"
$Yellow = "$([char]27)[93m"
$Red = "$([char]27)[91m"
$Reset = "$([char]27)[0m"

function Write-Status {
    param([string]$Message, [string]$Color = $Green)
    Write-Host "${Color}${Message}${Reset}"
}

Write-Status "=== Vulkan SDK Setup Helper ==="
Write-Status ""

# Check if Vulkan SDK is installed
$vulkanPath = "C:\VulkanSDK\1.4.328.1"
if (!(Test-Path $vulkanPath)) {
    Write-Status "[FAIL] Vulkan SDK not found at $vulkanPath" $Red
    Write-Status ""
    Write-Status "Please install Vulkan SDK from:" $Yellow
    Write-Status "https://vulkan.lunarg.com/sdk/home#windows"
    Write-Status ""
    exit 1
}

Write-Status "[OK] Vulkan SDK found at $vulkanPath" $Green

# Check if glslc compiler exists
if (Test-Path "$vulkanPath\Bin\glslc.exe") {
    $glslcVersion = & "$vulkanPath\Bin\glslc.exe" --version 2>$null | Select-Object -First 1
    Write-Status "[OK] Shader compiler: $glslcVersion" $Green
} else {
    Write-Status "[FAIL] glslc.exe not found" $Red
    exit 1
}

# Check current VULKAN_SDK environment variable
Write-Status ""
Write-Status "Checking VULKAN_SDK environment variable..."
$currentVulkanSdk = [System.Environment]::GetEnvironmentVariable('VULKAN_SDK', 'Machine')

if ($currentVulkanSdk -eq $vulkanPath) {
    Write-Status "[OK] VULKAN_SDK is correctly set system-wide" $Green
    Write-Status ""
    Write-Status "Vulkan is ready for builds!" $Green
    Write-Status "You can now run build_complete.ps1 with Vulkan support"
} else {
    Write-Status "[WARN] VULKAN_SDK not set at system level" $Yellow
    Write-Status ""
    Write-Status "Current value: $currentVulkanSdk"
    Write-Status "Expected: $vulkanPath"
    Write-Status ""
    Write-Status "To enable Vulkan support, run this command as Administrator:" $Yellow
    Write-Status ""
    Write-Status "[System.Environment]::SetEnvironmentVariable('VULKAN_SDK', 'C:\VulkanSDK\1.4.328.1', 'Machine')" $Green
    Write-Status ""
    Write-Status "Then restart PowerShell and run build_complete.ps1 again"
    Write-Status ""
    Write-Status "Note: Builds will work without Vulkan (CUDA-only), but Vulkan provides:" $Yellow
    Write-Status "  - AMD/Intel GPU support"
    Write-Status "  - Better performance on some NVIDIA GPUs"
    Write-Status "  - Cross-platform compatibility"
}

Write-Status ""

