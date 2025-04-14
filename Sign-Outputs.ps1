param(
    [Parameter(Mandatory=$true)]
    [string]$CertificateSubject
)

# Find certificate with private key
$cert = Get-ChildItem -Path "Cert:\CurrentUser\My" | 
    Where-Object { $_.Subject -eq $CertificateSubject -and $_.HasPrivateKey } |
    Select-Object -First 1

if (-not $cert) {
    throw "Certificate not found with subject: $CertificateSubject or missing private key"
}

Write-Host "Using certificate: $($cert.Subject) ($($cert.Thumbprint))"

# Find the specific files we want to sign
$binPath = Join-Path "net" "bin" "*"
$filePaths = Get-ChildItem -Path $binPath -Recurse | Where-Object {
    $_.Name -eq "azsdkperf.dll"
}

if (-not $filePaths) {
    throw "No azsdkperf.dll found to sign"
}

Write-Host "Found files to sign:"
$filePaths | ForEach-Object { Write-Host "  - $($_.FullName)" }

# Sign each file
foreach ($file in $filePaths) {
    Write-Host "`nSigning $($file.Name)..." -ForegroundColor Cyan
    
    try {
        # Sign with full chain
        $result = Set-AuthenticodeSignature -FilePath $file.FullName `
            -Certificate $cert `
            -TimestampServer "http://timestamp.digicert.com" `
            -HashAlgorithm SHA256 `
            -IncludeChain All

        if ($result.Status -ne "Valid") {
            throw "Signing failed. Status: $($result.Status), StatusMessage: $($result.StatusMessage)"
        }
        
        Write-Host "✓ Successfully signed $($file.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to sign $($file.Name)" -ForegroundColor Red
        throw
    }
}
