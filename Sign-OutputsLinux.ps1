param(
    [Parameter(Mandatory=$true)]
    [string]$CertificateSubject
)

# Find all DLLs and EXEs in the output directories
$files = Get-ChildItem -Path "./net" -Recurse -Include @("*.dll", "*.exe") | Where-Object { $_.Directory.FullName -like "*\bin\*" }

foreach ($file in $files) {
    Write-Host "Signing $($file.Name)..."
    
    # Use osslsigncode for Linux signing
    $timestampServer = "http://timestamp.digicert.com"
    $cert = Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object { $_.Subject -eq $CertificateSubject } | Select-Object -First 1
    
    if (-not $cert) {
        throw "Certificate with subject '$CertificateSubject' not found!"
    }
    
    $certPath = Join-Path $PSScriptRoot "cert/CodeSigning.pfx"
    
    # Sign using osslsigncode
    $null = & osslsigncode sign -pkcs12 $certPath `
        -pass "Dev123!@#" `
        -n "$CertificateSubject" `
        -t $timestampServer `
        -in $file.FullName `
        -out "$($file.FullName).signed"
    
    # Replace original with signed file
    Remove-Item $file.FullName
    Move-Item "$($file.FullName).signed" $file.FullName
}
