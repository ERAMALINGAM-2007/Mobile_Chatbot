Write-Host "=== FLUTTER & DART ==="
try { flutter --version } catch { Write-Host "Flutter not found: $_" }

Write-Host "`n=== FLUTTER DOCTOR ==="
try { flutter doctor -v } catch { Write-Host "Flutter doctor failed: $_" }

Write-Host "`n=== JAVA ==="
try { java -version } catch { Write-Host "Java not found: $_" }

Write-Host "`n=== GIT ==="
try { git --version } catch { Write-Host "Git not found: $_" }

Write-Host "`n=== CMAKE & NINJA ==="
try { cmake --version } catch { Write-Host "CMake not found: $_" }
try { ninja --version } catch { Write-Host "Ninja not found: $_" }

Write-Host "`n=== ANDROID SDK & ENVIRONMENT ==="
Write-Host "ANDROID_HOME: $env:ANDROID_HOME"
Write-Host "ANDROID_SDK_ROOT: $env:ANDROID_SDK_ROOT"
Write-Host "LOCALAPPDATA Android SDK: $env:LOCALAPPDATA\Android\Sdk"

Write-Host "`n=== ANDROID NDK LOCATIONS ==="
$ndkPaths = @(
    "$env:ANDROID_HOME\ndk",
    "$env:ANDROID_SDK_ROOT\ndk",
    "$env:LOCALAPPDATA\Android\Sdk\ndk"
)
foreach ($p in $ndkPaths) {
    if (Test-Path $p) {
        Write-Host "Found NDK folder at: $p"
        Get-ChildItem $p | ForEach-Object { Write-Host " - $($_.Name)" }
    }
}

Write-Host "`n=== ADB & CONNECTED DEVICES ==="
try {
    adb --version
    adb devices -l
    
    $devices = (adb devices | Where-Object { $_ -match "\bdevice\b" -and $_ -notmatch "List of devices" })
    if ($devices) {
        Write-Host "`n--- Device Details ---"
        Write-Host "Model: $(adb shell getprop ro.product.model)"
        Write-Host "ABI: $(adb shell getprop ro.product.cpu.abi)"
        Write-Host "Android Version: $(adb shell getprop ro.build.version.release)"
        Write-Host "SDK Level: $(adb shell getprop ro.build.version.sdk)"
        Write-Host "Storage (/data):"
        adb shell df -h /data
    } else {
        Write-Host "No authorized ADB devices detected currently."
    }
} catch {
    Write-Host "ADB error or not found: $_"
}
