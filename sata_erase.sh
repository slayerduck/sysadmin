#!/bin/bash

# Destroys all SATA SSD's, use with caution. Only use if you use a different drive as main OS eg nvme.
# Secure erase password (must be simple, e.g., 'p' for hdparm compatibility)
SECURE_PASS="p"

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Exiting."
   exit 1
fi

# Check if hdparm is installed
if ! command -v hdparm &> /dev/null; then
    echo "hdparm is not installed. Please install it (e.g., 'apt install hdparm' or 'yum install hdparm'). Exiting."
    exit 1
fi

# Function to check if a drive is an SSD
is_ssd() {
    local drive=$1
    # Check if rotational file exists and is 0 (SSD) or 1 (HDD)
    if [[ -f "/sys/block/${drive##*/}/queue/rotational" ]]; then
        rotational=$(cat "/sys/block/${drive##*/}/queue/rotational")
        if [[ "$rotational" == "0" ]]; then
            return 0 # SSD
        else
            return 1 # HDD
        fi
    else
        echo "Cannot determine if $drive is an SSD. Skipping."
        return 1
    fi
}

# Function to perform secure erase
secure_erase_drive() {
    local drive=$1

    echo "Processing $drive..."

    # Set the security password
    echo "Setting temporary password for $drive..."
    hdparm --user-master u --security-set-pass "$SECURE_PASS" "$drive" 2>&1
    if [[ $? -ne 0 ]]; then
        echo "Failed to set security password on $drive. Skipping."
        return 1
    fi

    # Brief sleep to ensure drive is ready for erase
    sleep 1

    # Perform secure erase
    echo "Initiating secure erase on $drive. This may take some time..."
    time hdparm --user-master u --security-erase "$SECURE_PASS" "$drive" 2>&1
    if [[ $? -ne 0 ]]; then
        echo "Secure erase failed on $drive."
        return 1
    fi

    echo "Secure erase completed successfully on $drive."
}

# Main script
echo "WARNING: This script will PERMANENTLY ERASE ALL DATA on all SATA SSDs under /dev/sd*."
echo "Ensure no critical data is on these drives. This action is IRREVERSIBLE."
read -p "Type 'YES' to continue: " confirmation

if [[ "$confirmation" != "YES" ]]; then
    echo "Confirmation not received. Exiting."
    exit 1
fi

# Iterate over all /dev/sd* devices
for drive in /dev/sd[a-z]; do
    if [[ -b "$drive" ]]; then
        # Skip if not an SSD
        if ! is_ssd "$drive"; then
            echo "$drive is not an SSD. Skipping."
            continue
        fi

        # Perform secure erase
        secure_erase_drive "$drive"

        # Sleep between drives to avoid controller issues
        echo "Waiting 5 seconds before processing next drive..."
        sleep 5
    else
        echo "No device found at $drive. Skipping."
    fi
done

echo "Secure erase process completed for all detected SSDs."