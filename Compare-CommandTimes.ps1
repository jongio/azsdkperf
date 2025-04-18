param(
    [Parameter()]
    [string]$CertificateSubject = "CN=azuresdk",
    [Parameter()]
    [string]$Filter
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Function to read .env file
function Get-EnvValue {
    param ([string]$key)
    $envFile = Join-Path $PSScriptRoot ".env"
    if (Test-Path $envFile) {
        $value = Get-Content $envFile | Where-Object { $_ -match "^$key=" } | ForEach-Object { $_.Split('=')[1] }
        if ($value) {
            return $value
        }
        throw "Cannot find $key in .env file"
    }
    throw "Cannot find .env file"
}

function Clean-DotNet {
    Push-Location net
    dotnet clean --nologo -v quiet
    Pop-Location
}

function Build-DotNet {
    param([string]$Configuration)
    Push-Location net
    try {
        dotnet clean --nologo -v quiet
        $buildOutput = dotnet build -c $Configuration --nologo
        if ($LASTEXITCODE -ne 0) {
            throw "Build failed: $buildOutput"
        }
        # Verify DLL exists
        $dllPath = Join-Path "bin" $Configuration "net9.0" "azsdkperf.dll"
        if (-not (Test-Path $dllPath)) {
            throw "Build completed but DLL not found at: $dllPath"
        }
    }
    finally {
        Pop-Location
    }
}

function Verify-Signature {
    param([string]$FilePath)
    
    if ($IsWindows) {
        $signature = Get-AuthenticodeSignature $FilePath
        if ($signature.Status -ne 'Valid') {
            throw "Signature verification failed for $FilePath. Status: $($signature.Status)"
        }
        Write-Host "✓ Verified signature for $FilePath" -ForegroundColor Green
    } else {
        # On Linux, use osslsigncode
        if (Get-Command "osslsigncode" -ErrorAction SilentlyContinue) {
            $result = osslsigncode verify $FilePath 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Signature verification failed for $FilePath. Error: $result"
            }
            Write-Host "✓ Verified signature for $FilePath" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Signature verification not supported on this platform - osslsigncode not found" -ForegroundColor Yellow
        }
    }
}

function Sign-Build {
    param([string]$Configuration)
    # Only sign Release builds
    if ($Configuration -ne "Release") {
        Write-Host "Skipping signing for $Configuration build - only Release builds are signed" -ForegroundColor Yellow
        return
    }

    if ($CertificateSubject) {
        Write-Host "Signing $Configuration build..." -ForegroundColor Cyan
        
        # Ensure we're in the script root directory
        Push-Location $PSScriptRoot
        try {
            # Call Sign-Outputs.ps1 which now only handles Release builds
            .\Sign-Outputs.ps1 -CertificateSubject $CertificateSubject
            
            # Get paths to verify
            $binPath = Join-Path "net" "bin" $Configuration "net9.0"
            $filesToVerify = @(
                (Join-Path $binPath "azsdkperf.dll"),
                (Join-Path $binPath "azsdkperf.exe")
            ) | Where-Object { Test-Path $_ }
            
            if ($filesToVerify) {
                Write-Host "`nVerifying signatures..." -ForegroundColor Cyan
                $filesToVerify | ForEach-Object {
                    Verify-Signature $_
                }
            }
        }
        finally {
            Pop-Location
        }
    }
}

# Add package installation functions
function Install-NodePackages {
    if (-not (Test-Path (Join-Path "js" "node_modules"))) {
        Push-Location js
        Write-Host "Installing Node.js packages..." -ForegroundColor Gray
        npm install
        Pop-Location
    }
}

function Install-PythonPackages {
    Push-Location python
    # Check if any required package is missing
    $missing = python -c "import pkg_resources, sys; sys.exit(len({'azure-storage-table'} - {pkg.key for pkg in pkg_resources.working_set}))" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Installing Python packages..." -ForegroundColor Gray
        python -m pip install -r requirements.txt
    }
    Pop-Location
}

# Store original location and change to src directory
$originalLocation = Get-Location
Set-Location $PSScriptRoot

$storageAccountName = Get-EnvValue "STORAGE_ACCOUNT_NAME"

$commands = @(
    @{
        Name = "dotnet run (JIT) - exclude MI"
        Setup = {
            Clean-DotNet
            Push-Location net
            dotnet build --nologo -v quiet
        }
        Command = {
            dotnet run --no-build --excludeMI true
        }
        Cleanup = {
            Pop-Location
        }
    },
    @{
        Name = "dotnet run (JIT) - include MI"
        Setup = {
            Clean-DotNet
            Push-Location net
            dotnet build --nologo -v quiet
        }
        Command = {
            dotnet run --no-build --excludeMI false
        }
        Cleanup = {
            Pop-Location
        }
    },
    @{
        Name = "dotnet debug dll (unsigned) - exclude MI"
        Setup = {
            Clean-DotNet
            Build-DotNet "Debug"
            Push-Location net
        }
        Command = {
            $dllPath = Join-Path "bin" "Debug" "net9.0" "azsdkperf.dll"
            dotnet $dllPath --excludeMI true
        }
        Cleanup = {
            Pop-Location
        }
    },
    @{
        Name = "dotnet debug dll (unsigned) - include MI"
        Setup = {
            Clean-DotNet
            Build-DotNet "Debug"
            Push-Location net
        }
        Command = {
            $dllPath = Join-Path "bin" "Debug" "net9.0" "azsdkperf.dll"
            dotnet $dllPath --excludeMI false
        }
        Cleanup = {
            Pop-Location
        }
    },
    @{
        Name = "python command"
        Setup = { 
            Push-Location python
        }
        Command = { 
            python program.py
        }
        Cleanup = {
            Pop-Location
        }
    },
    @{
        Name = "node command"
        Setup = { 
            Push-Location js
        }
        Command = { 
            node index.js
        }
        Cleanup = {
            Pop-Location
        }
    },
    @{
        Name = "java command"
        Setup = { 
            mvn -f java/pom.xml clean compile
        }
        Command = { 
            mvn -f java/pom.xml exec:java "-Dexec.mainClass=com.azsdkperf.App" -q 
        }
        Cleanup = { }
    },
    @{
        Name = "az command"
        Setup = { }
        Command = { 
            az storage table list --account-name $storageAccountName --auth-mode login 
        }
        Cleanup = { }
    },
    @{
        Name = "python command (production)"
        Setup = { 
            Push-Location python
            # Clean and build with PyInstaller
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue dist, build, *.spec
            pyinstaller --onefile program.py
        }
        Command = { 
            ./dist/program
        }
        Cleanup = {
            Pop-Location
        }
    },
    @{
        Name = "node command (production)"
        Setup = { 
            Push-Location js
            npm run build
        }
        Command = { 
            ./azsdkperf-js-linux
        }
        Cleanup = {
            Pop-Location
        }
    },
    @{
        Name = "java command (production)"
        Setup = { 
            mvn -f java/pom.xml clean package assembly:single -DskipTests -q
        }
        Command = { 
            java -jar java/target/azsdkperf-1.0-SNAPSHOT-jar-with-dependencies.jar
        }
        Cleanup = { }
    }
)

$signedCommands = @(
    @{
        Name = "dotnet release dll (signed) - exclude MI"
        Setup = {
            Clean-DotNet
            Build-DotNet "Release"
            Sign-Build "Release"
            Push-Location net
        }
        Command = {
            $dllPath = Join-Path "bin" "Release" "net9.0" "azsdkperf.dll"
            dotnet $dllPath --excludeMI true
        }
        Cleanup = {
            Pop-Location
        }
    },
    @{
        Name = "dotnet release dll (signed) - include MI"
        Setup = {
            Clean-DotNet
            Build-DotNet "Release"
            Sign-Build "Release"
            Push-Location net
        }
        Command = {
            $dllPath = Join-Path "bin" "Release" "net9.0" "azsdkperf.dll"
            dotnet $dllPath --excludeMI false
        }
        Cleanup = {
            Pop-Location
        }
    }
)

$results = @()

Write-Host "Starting command execution time comparison..." -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Filter commands if a filter is specified
$commandsToRun = $commands
if ($Filter) {
    Write-Host "Filtering commands matching: $Filter" -ForegroundColor Yellow
    $commandsToRun = $commands | Where-Object { $_.Name -like "*$Filter*" }
    if ($commandsToRun.Count -eq 0) {
        Write-Host "No commands found matching filter: $Filter" -ForegroundColor Red
        exit 1
    }
}

# Only install packages for commands we'll actually run
if ($commandsToRun | Where-Object { $_.Name -like "*node*" }) {
    Install-NodePackages
}
if ($commandsToRun | Where-Object { $_.Name -like "*python*" }) {
    Install-PythonPackages
}

foreach ($cmd in $commandsToRun) {
    Write-Host "`nPreparing: $($cmd.Name)" -ForegroundColor Yellow
    
    try {
        # Run setup
        if ($cmd.Setup) {
            Write-Host "Running setup..." -ForegroundColor Gray
            & $cmd.Setup
            if ($LASTEXITCODE -ne 0) {
                throw "Setup failed with exit code $LASTEXITCODE"
            }
        }

        Write-Host "`nExecuting: $($cmd.Name)" -ForegroundColor Yellow
        Write-Host "Command to execute:" -ForegroundColor Yellow
        Write-Host $cmd.Command.ToString() -ForegroundColor Gray
        
        # Time only the actual command
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $output = & $cmd.Command
        $lastExitCode = $LASTEXITCODE
        $sw.Stop()
        
        if ($lastExitCode -ne 0) {
            throw "Command failed with exit code $lastExitCode"
        }
        
        # Display the output immediately after command execution
        Write-Host "`nCommand Output:" -ForegroundColor Green
        $output | ForEach-Object { Write-Host $_ }
        
        $results += [PSCustomObject]@{
            Name = $cmd.Name
            Command = $cmd.Command.ToString()
            ExecutionTime = $sw.Elapsed
            Success = $true
            Output = $output
        }

        # Run cleanup
        if ($cmd.Cleanup) {
            Write-Host "Running cleanup..." -ForegroundColor Gray
            & $cmd.Cleanup
            if ($LASTEXITCODE -ne 0) {
                throw "Cleanup failed with exit code $LASTEXITCODE"
            }
        }
    }
    catch {
        $sw.Stop()
        Write-Host "`nCommand failed:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        
        # Add failed command to results
        $results += [PSCustomObject]@{
            Name = $cmd.Name
            Command = $cmd.Command.ToString()
            ExecutionTime = $sw.Elapsed
            Success = $false
            Error = $_.Exception.Message
        }
        
        # Try to run cleanup even if command failed
        if ($cmd.Cleanup) {
            Write-Host "Running cleanup..." -ForegroundColor Gray
            try {
                & $cmd.Cleanup
            }
            catch {
                Write-Host "Cleanup also failed:" -ForegroundColor Red
                Write-Host $_.Exception.Message -ForegroundColor Red
            }
        }
        # Continue with next command instead of exiting
        continue
    }
}

# Now sign and test the signed builds
Write-Host "`nSigning .NET assemblies..." -ForegroundColor Cyan

$signedCommandsToRun = $signedCommands
if ($Filter) {
    $signedCommandsToRun = $signedCommands | Where-Object { $_.Name -like "*$Filter*" }
}

foreach ($cmd in $signedCommandsToRun) {
    Write-Host "`nPreparing: $($cmd.Name)" -ForegroundColor Yellow
    
    try {
        # Run setup
        if ($cmd.Setup) {
            Write-Host "Running setup..." -ForegroundColor Gray
            & $cmd.Setup
            if ($LASTEXITCODE -ne 0) {
                throw "Setup failed with exit code $LASTEXITCODE"
            }
        }

        Write-Host "`nExecuting: $($cmd.Name)" -ForegroundColor Yellow
        Write-Host "Command to execute:" -ForegroundColor Yellow
        Write-Host $cmd.Command.ToString() -ForegroundColor Gray
        
        # Time only the actual command
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $output = & $cmd.Command
        $lastExitCode = $LASTEXITCODE
        $sw.Stop()
        
        if ($lastExitCode -ne 0) {
            throw "Command failed with exit code $lastExitCode"
        }
        
        # Display the output immediately after command execution
        Write-Host "`nCommand Output:" -ForegroundColor Green
        $output | ForEach-Object { Write-Host $_ }
        
        $results += [PSCustomObject]@{
            Name = $cmd.Name
            Command = $cmd.Command.ToString()
            ExecutionTime = $sw.Elapsed
            Success = $true
            Output = $output
        }

        # Run cleanup
        if ($cmd.Cleanup) {
            Write-Host "Running cleanup..." -ForegroundColor Gray
            & $cmd.Cleanup
            if ($LASTEXITCODE -ne 0) {
                throw "Cleanup failed with exit code $LASTEXITCODE"
            }
        }
    }
    catch {
        $sw.Stop()
        Write-Host "`nCommand failed:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        
        # Add failed command to results
        $results += [PSCustomObject]@{
            Name = $cmd.Name
            Command = $cmd.Command.ToString()
            ExecutionTime = $sw.Elapsed
            Success = $false
            Error = $_.Exception.Message
        }
        
        # Try to run cleanup even if command failed
        if ($cmd.Cleanup) {
            Write-Host "Running cleanup..." -ForegroundColor Gray
            try {
                & $cmd.Cleanup
            }
            catch {
                Write-Host "Cleanup also failed:" -ForegroundColor Red
                Write-Host $_.Exception.Message -ForegroundColor Red
            }
        }
        # Continue with next command instead of exiting
        continue
    }
}

# Show all results including failures
Write-Host "`nResults Summary:" -ForegroundColor Green
Write-Host "================" -ForegroundColor Green

Write-Host "`nExecution Time Summary:" -ForegroundColor Blue
Write-Host "======================" -ForegroundColor Blue

$summaryTable = $results | 
    Select-Object @{N='Command';E={$_.Name}}, 
                 @{N='Time (seconds)';E={$_.ExecutionTime.TotalSeconds}},
                 Success |
    Sort-Object 'Time (seconds)'

$summaryTable | Format-Table -AutoSize

# Restore original location
Set-Location $originalLocation