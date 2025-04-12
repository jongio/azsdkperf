param()

# Function to read .env file
function Get-EnvValue {
    param ([string]$key)
    $envFile = Join-Path $PSScriptRoot ".env"
    if (Test-Path $envFile) {
        $value = Get-Content $envFile | Where-Object { $_ -match "^$key=" } | ForEach-Object { $_.Split('=')[1] }
        return $value
    }
    throw "Cannot find .env file or $key in .env file"
}

# Store original location and change to src directory
$originalLocation = Get-Location
Set-Location $PSScriptRoot

$storageAccountName = Get-EnvValue "STORAGE_ACCOUNT_NAME"

$commands = @(
    @{
        Name = "az command"
        Command = "az storage table list --account-name $storageAccountName --auth-mode login"
    },
    @{
        Name = "dotnet run command"
        Command = "Push-Location net; dotnet run; Pop-Location"
    },
    @{
        Name = "python command"
        Command = "Push-Location python; python program.py; Pop-Location"
    },
    @{
        Name = "node command"
        Command = "Push-Location js; node index.js; Pop-Location"
    },
    # @{
    #     Name = "java command"
    #     Command = "Push-Location java; mvn exec:java -Dexec.mainClass='com.azsdkperf.App' -q; Pop-Location"
    # },
    @{
        Name = "dotnet debug (pre-built)"
        Command = "Push-Location net; dotnet '$PSScriptRoot\net\bin\Debug\net9.0\azsdkperf.dll'; Pop-Location"
    },
    @{
        Name = "dotnet release (pre-built)"
        Command = "Push-Location net; dotnet '$PSScriptRoot\net\bin\Release\net9.0\azsdkperf.dll'; Pop-Location"
    }
)

$results = @()

Write-Host "Starting command execution time comparison..." -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

foreach ($cmd in $commands) {
    Write-Host "`nExecuting: $($cmd.Name)" -ForegroundColor Yellow
    Write-Host "Command: $($cmd.Command)"
    
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        $output = Invoke-Expression $cmd.Command
        $sw.Stop()
        
        # Display the output immediately after command execution
        Write-Host "`nCommand Output:" -ForegroundColor Green
        $output | ForEach-Object { Write-Host $_ }
        
        $results += [PSCustomObject]@{
            Name = $cmd.Name
            Command = $cmd.Command
            ExecutionTime = $sw.Elapsed
            Success = $true
            Output = $output
        }
    }
    catch {
        $sw.Stop()
        $results += [PSCustomObject]@{
            Name = $cmd.Name
            Command = $cmd.Command
            ExecutionTime = $sw.Elapsed
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

Write-Host "`nResults Summary:" -ForegroundColor Green
Write-Host "================" -ForegroundColor Green

foreach ($result in $results) {
    Write-Host "`nCommand Name: $($result.Name)" -ForegroundColor Cyan
    Write-Host "Full Command: $($result.Command)" -ForegroundColor Cyan
    Write-Host "Execution Time: $($result.ExecutionTime.TotalSeconds) seconds"
    
    if ($result.Success) {
        Write-Host "Status: Success" -ForegroundColor Green
        Write-Host "`nOutput:" -ForegroundColor Gray
        $result.Output | ForEach-Object { Write-Host $_ }
    }
    else {
        Write-Host "Status: Failed" -ForegroundColor Red
        Write-Host "Error: $($result.Error)"
    }
}

# Compare the times
if ($results.Count -eq 2 -and $results[0].Success -and $results[1].Success) {
    $timeDiff = $results[0].ExecutionTime - $results[1].ExecutionTime
    $fasterCommand = if ($timeDiff.TotalSeconds -gt 0) { $results[1].Name } else { $results[0].Name }
    $difference = [Math]::Abs($timeDiff.TotalSeconds)
    
    Write-Host "`nComparison:" -ForegroundColor Magenta
    Write-Host "===========" -ForegroundColor Magenta
    Write-Host "$fasterCommand was faster by $difference seconds"
    
    Write-Host "`nFull Command Details of Faster Operation:" -ForegroundColor Magenta
    Write-Host ($results | Where-Object { $_.Name -eq $fasterCommand }).Command
}

# Add execution time summary table
Write-Host "`nExecution Time Summary:" -ForegroundColor Blue
Write-Host "======================" -ForegroundColor Blue

$summaryTable = $results | 
    Where-Object { $_.Success } |
    Select-Object @{N='Command';E={$_.Name}}, @{N='Time (seconds)';E={$_.ExecutionTime.TotalSeconds}} |
    Sort-Object 'Time (seconds)'

$summaryTable | Format-Table -AutoSize

# Restore original location
Set-Location $originalLocation