## Provides a head's up to user for AZURE_NETWORK_ISOLATION

# Check if AZURE_NETWORK_ISOLATION environment variable is defined
if (-not $env:AZURE_NETWORK_ISOLATION) {
    exit 0
}

# Check if AZURE_NETWORK_ISOLATION environment variable is set to a positive value
if ($env:AZURE_NETWORK_ISOLATION -match '^[1-9][0-9]*$' -or $env:AZURE_NETWORK_ISOLATION -match '^[Tt][Rr][Uu][Ee]$' -or $env:AZURE_NETWORK_ISOLATION -match '^[Tt]$') {
    
    # Display a heads up warning
    Write-Host "Heads up! AZURE_NETWORK_ISOLATION is set to a positive value."

    # Prompt for user confirmation
    $confirmation = Read-Host "Continue with the script? [Y/n]: "

    # Check if the confirmation is positive
    if ($confirmation -ne "Y" -and $confirmation -ne "y" -and $confirmation) {
        exit 1
    }
}

exit 0
