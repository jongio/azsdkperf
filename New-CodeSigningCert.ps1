param(
    [Parameter(Mandatory=$true)]
    [string]$CertName = "azuresdk",
    
    [Parameter()]
    [string]$Password = "Dev123!@#",
    
    [Parameter()]
    [string]$OutputPath = ".\cert"
)

# Ensure output directory exists
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

# Create certificate
$cert = New-SelfSignedCertificate `
    -Subject "CN=$CertName" `
    -Type CodeSigningCert `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -HashAlgorithm SHA256 `
    -KeyLength 2048 `
    -KeyAlgorithm RSA `
    -KeyExportPolicy Exportable `
    -NotAfter (Get-Date).AddYears(5)

# Export public certificate
$certPath = Join-Path $OutputPath "CodeSigning.cer"
Export-Certificate -Cert $cert -FilePath $certPath -Type CERT

# Export pfx with private key
$pfxPath = Join-Path $OutputPath "CodeSigning.pfx"
$securePwd = ConvertTo-SecureString -String $Password -Force -AsPlainText
Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $securePwd

Write-Host "`nCertificate created successfully:" -ForegroundColor Green
Write-Host "Public certificate: $certPath"
Write-Host "Private key file:  $pfxPath"
Write-Host "Thumbprint:        $($cert.Thumbprint)"
Write-Host "`nTo use this certificate:"
Write-Host "1. Double-click the .pfx file"
Write-Host "2. Install in 'Current User' store"
Write-Host "3. Use password: $Password"
Write-Host "`nNote: This is a self-signed certificate for development only!"
Write-Host "For production, purchase a certificate from a trusted CA like DigiCert or Sectigo."
