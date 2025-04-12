param(
    [Parameter(Mandatory=$true)]
    [string]$CertificateSubject,
    
    [Parameter()]
    [string]$TimestampServer = "http://timestamp.digicert.com"
)

$builds = @(
    ".\net\bin\Debug\net9.0",
    ".\net\bin\Release\net9.0"
)

# Find SignTool.exe in the Windows SDK
$programFiles = ${env:ProgramFiles(x86)}
$signtool = Get-ChildItem -Path "$programFiles\Windows Kits\10\bin\**\x64\signtool.exe" | 
    Sort-Object -Property FullName -Descending | 
    Select-Object -First 1

if (-not $signtool) {
    throw "SignTool.exe not found. Please install the Windows SDK."
}

foreach ($buildPath in $builds) {
    $files = Get-ChildItem -Path $buildPath -Filter "azsdkperf.*" -Include "*.exe","*.dll"
    
    foreach ($file in $files) {
        Write-Host "Signing $($file.Name) in $buildPath..." -ForegroundColor Cyan
        
        & $signtool sign /fd SHA256 /n $CertificateSubject /tr $TimestampServer /td SHA256 /v $file.FullName
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully signed $($file.Name)" -ForegroundColor Green
        } else {
            Write-Host "Failed to sign $($file.Name)" -ForegroundColor Red
        }
    }
}
