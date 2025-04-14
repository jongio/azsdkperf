param(
    [Parameter(Mandatory=$true)]
    [string]$CertName = "azuresdk",
    
    [Parameter()]
    [string]$Password = "Dev123!@#",
    
    [Parameter()]
    [string]$OutputPath = ".\cert"
)

# Adjust path for Linux systems
if (-not $IsWindows) {
    $OutputPath = "./cert"
}

# Ensure output directory exists
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

if ($IsWindows) {
    # First remove existing certificates from all stores
    $stores = @(
        @{ Name = "Root"; Location = "LocalMachine" },
        @{ Name = "Root"; Location = "CurrentUser" },
        @{ Name = "TrustedPublisher"; Location = "LocalMachine" },
        @{ Name = "TrustedPublisher"; Location = "CurrentUser" }
    )

    Write-Host "Removing any existing certificates with CN=$CertName..."
    foreach ($store in $stores) {
        try {
            $certStore = New-Object System.Security.Cryptography.X509Certificates.X509Store(
                $store.Name,
                [System.Security.Cryptography.X509Certificates.StoreLocation]::($store.Location)
            )
            $certStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
            
            $existingCerts = $certStore.Certificates | Where-Object { $_.Subject -eq "CN=$CertName" }
            if ($existingCerts) {
                foreach ($existing in $existingCerts) {
                    $certStore.Remove($existing)
                    Write-Host "✓ Removed existing certificate from $($store.Location)\$($store.Name)" -ForegroundColor Yellow
                }
            }
            
            $certStore.Close()
        }
        catch {
            Write-Host "! Failed to remove certificates from $($store.Location)\$($store.Name): $_" -ForegroundColor Red
        }
    }

    # Create Windows certificate
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

    # Modified store import section
    $stores = @(
        @{ Name = "Root"; Location = "LocalMachine" },
        @{ Name = "Root"; Location = "CurrentUser" },
        @{ Name = "TrustedPublisher"; Location = "LocalMachine" },
        @{ Name = "TrustedPublisher"; Location = "CurrentUser" }
    )

    # Import certificate into stores with additional error handling
    foreach ($store in $stores) {
        Write-Host "Installing certificate in $($store.Location)\$($store.Name) store..."
        try {
            $certStore = New-Object System.Security.Cryptography.X509Certificates.X509Store(
                $store.Name,
                [System.Security.Cryptography.X509Certificates.StoreLocation]::($store.Location)
            )
            $certStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
            
            # Check if cert already exists
            $existing = $certStore.Certificates | Where-Object { $_.Thumbprint -eq $cert.Thumbprint }
            if ($existing) {
                Write-Host "Certificate already exists in $($store.Location)\$($store.Name)" -ForegroundColor Yellow
                $certStore.Remove($existing)
            }
            
            $certStore.Add($cert)
            $certStore.Close()
            
            Write-Host "✓ Successfully added to $($store.Location)\$($store.Name)" -ForegroundColor Green
        }
        catch {
            Write-Host "! Failed to add to $($store.Location)\$($store.Name): $_" -ForegroundColor Red
        }
    }

    # Verify certificate is properly installed
    foreach ($store in $stores) {
        $certStore = New-Object System.Security.Cryptography.X509Certificates.X509Store $store.Name, $store.Location
        $certStore.Open("ReadOnly")
        $found = $certStore.Certificates | Where-Object { $_.Thumbprint -eq $cert.Thumbprint }
        $certStore.Close()
        
        if (-not $found) {
            throw "Certificate not found in $($store.Location)\$($store.Name) store"
        }
        Write-Host "✓ Certificate verified in $($store.Location)\$($store.Name) store" -ForegroundColor Green
    }

    Write-Host "`nCertificate created and installed successfully:" -ForegroundColor Green
    Write-Host "Public certificate: $certPath"
    Write-Host "Private key file:  $pfxPath"
    Write-Host "Thumbprint:        $($cert.Thumbprint)"
    Write-Host "`nTo use this certificate:"
    Write-Host "1. Double-click the .pfx file"
    Write-Host "2. Install in 'Current User' store"
} else {
    # Linux certificate creation
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
}

Write-Host "3. Use password: $Password"
Write-Host "`nNote: This is a self-signed certificate for development only!"
Write-Host "For production, purchase a certificate from a trusted CA like DigiCert or Sectigo."
