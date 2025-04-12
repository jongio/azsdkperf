param(
    [Parameter(Mandatory=$true)]
    [string]$CertName = "azuresdk",
    
    [Parameter()]
    [string]$Password = "Dev123!@#",
    
    [Parameter()]
    [string]$OutputPath = "./cert"
)

# Ensure output directory exists
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

# Generate private key and certificate
$keyPath = Join-Path $OutputPath "private.key"
$certPath = Join-Path $OutputPath "CodeSigning.cer"
$pfxPath = Join-Path $OutputPath "CodeSigning.pfx"

# Create OpenSSL config file
$configPath = Join-Path $OutputPath "openssl.cnf"
@"
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_req

[ dn ]
CN = $CertName

[ v3_req ]
keyUsage = digitalSignature
extendedKeyUsage = codeSigning
"@ | Out-File -FilePath $configPath -Encoding ASCII

# Generate private key and certificate
$null = & openssl req -x509 -newkey rsa:2048 -keyout $keyPath -out $certPath -days 1825 -nodes -config $configPath
$null = & openssl pkcs12 -export -out $pfxPath -inkey $keyPath -in $certPath -password "pass:$Password"

# Clean up temporary files
Remove-Item $configPath
Remove-Item $keyPath

Write-Host "`nCertificate created successfully:" -ForegroundColor Green
Write-Host "Public certificate: $certPath"
Write-Host "Private key file:  $pfxPath"
Write-Host "`nTo use this certificate on Linux:"
Write-Host "1. Import the certificate: sudo cp $pfxPath /usr/local/share/ca-certificates/"
Write-Host "2. Update certificates: sudo update-ca-certificates"
Write-Host "3. Use password: $Password"
Write-Host "`nNote: This is a self-signed certificate for development only!"
