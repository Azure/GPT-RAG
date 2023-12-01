#!/bin/sh

if [ "$AZURE_ZERO_TRUST" = "TRUE" ]; then
    # Prompt for user confirmation
    echo -n "Zero Trust Infrastructe enabled. Confirm you are using a connection where resources are reachable (like VM+Bastion)? [Y/n]: "
    read confirmation

    # Check if the confirmation is positive
    if [ "$confirmation" != "Y" ] && [ "$confirmation" != "y" ] && [ -n "$confirmation" ]; then
        exit 0
    fi
    exit 1
fi
