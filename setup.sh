#!/bin/bash

read -p "Do you want to run with private or public network? (private/public): " network

if [ "$network" == "private" ]; then
    cp infra/main-privatenet.bicep infra/main.bicep
elif [ "$network" == "public" ]; then
    cp infra/main-publicnet.bicep infra/main.bicep
else
    echo "Invalid input. Please enter 'private' or 'public'."
    exit 1
fi

azd auth login

azd up

rm infra/main.bicep