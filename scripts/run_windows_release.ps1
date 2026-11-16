param(
    [string]$FirebaseSdk = 'D:\DeveloperTools\LEARNsync\FirebaseCppRelease\firebase_cpp_sdk_windows'
)

$ErrorActionPreference = 'Stop'
$previousFirebaseSdk = $env:FIREBASE_CPP_SDK_DIR
$projectRoot = Split-Path -Parent $PSScriptRoot

Push-Location -LiteralPath $projectRoot
try {
    if (Test-Path -LiteralPath (Join-Path $FirebaseSdk 'include\firebase\version.h')) {
        $env:FIREBASE_CPP_SDK_DIR = $FirebaseSdk
    }
    & flutter run -d windows --release
    if ($LASTEXITCODE -ne 0) {
        throw "Windows run failed with exit code $LASTEXITCODE."
    }
}
finally {
    $env:FIREBASE_CPP_SDK_DIR = $previousFirebaseSdk
    Pop-Location
}
