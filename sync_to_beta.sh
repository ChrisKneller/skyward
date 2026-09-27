#!/bin/bash

# sync_to_beta.sh
# This script synchronizes the Skyward addon files from the local WSL environment
# to the World of Warcraft Forever Beta AddOns folder on the Windows host.

# WSL Mount Path for Windows C: drive
WOW_ADDON_DIR="/mnt/c/Program Files (x86)/World of Warcraft/_classic_beta_/Interface/AddOns/Skyward"

echo "Syncing Skyward to WoW Forever Beta directory..."
echo "Target: $WOW_ADDON_DIR"

# Create the directory if it doesn't exist
mkdir -p "$WOW_ADDON_DIR"

# Copy the core addon files and directories
cp -r src "$WOW_ADDON_DIR/"
cp Skyward.toc "$WOW_ADDON_DIR/"

echo "Sync complete!"
