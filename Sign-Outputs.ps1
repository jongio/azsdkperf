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

if ($IsWindows) {
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
} else {
    # Linux signing using osslsigncode
    foreach ($buildPath in $builds) {
        $files = Get-ChildItem -Path $buildPath -Filter "azsdkperf.*" -Include "*.dll"
        
        foreach ($file in $files) {
            Write-Host "Signing $($file.Name) in $buildPath..." -ForegroundColor Cyan
            
            $pfxPath = "./cert/CodeSigning.pfx"
            $tempFile = "$($file.FullName).signed"
            
            & osslsigncode sign -pkcs12 $pfxPath -pass "Dev123!@#" -ts $TimestampServer -h sha256 -in $file.FullName -out $tempFile
            
            if ($LASTEXITCODE -eq 0) {
                Move-Item -Force $tempFile $file.FullName
                Write-Host "Successfully signed $($file.Name)" -ForegroundColor Green
            } else {
                Write-Host "Failed to sign $($file.Name)" -ForegroundColor Red
                if (Test-Path $tempFile) { Remove-Item $tempFile }
            }
        }
    }
}
