if ($env:AZURE_ZERO_TRUST -eq "TRUE") {
    # Prompt for user confirmation
    $confirmation = Read-Host -Prompt "Zero Trust Infrastructure enabled. Confirm you are using a connection where resources are reachable (like VM+Bastion)? [Y/n]"

    # Check if the confirmation is positive
    if ($confirmation -ne "Y" -and $confirmation -ne "y" -and $confirmation) {
        exit 0
    }
    exit 1
}
