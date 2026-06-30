#!/bin/sh
# Script to create, configure, and destroy a ClamAV jail on a TrueNAS Core host
# Includes additional services and variables requested by the administrator

JAIL_NAME="clamav-temp"
RELEASE=$(uname -r | cut -d '-' -f 1,2)

echo "=================================================="
echo "1. Creating temporary Jail: $JAIL_NAME"
echo "   Base system release: $RELEASE"
echo "=================================================="

# Create the Jail with VNET and DHCP for network access
iocage create -n "$JAIL_NAME" -r "$RELEASE" vnet="on" dhcp="on" bpf="yes"

echo "2. Starting the Jail..."
iocage start "$JAIL_NAME"

echo "3. Installing packages inside the Jail..."
iocage exec "$JAIL_NAME" pkg update -f
iocage exec "$JAIL_NAME" env ASSUME_ALWAYS_YES=YES pkg install security/clamav

echo "4. Initial ClamAV files configuration..."
iocage exec "$JAIL_NAME" cp /usr/local/etc/clamd.conf.sample /usr/local/etc/clamd.conf
iocage exec "$JAIL_NAME" sed -i '' 's/^Example/#Example/' /usr/local/etc/clamd.conf
iocage exec "$JAIL_NAME" cp /usr/local/etc/freshclam.conf.sample /usr/local/etc/freshclam.conf
iocage exec "$JAIL_NAME" sed -i '' 's/^Example/#Example/' /usr/local/etc/freshclam.conf

echo "5. Registering additional services and rc.conf entries..."
# List of extra services/variables to be added
EXTRA_SERVICES="clamav clamav_scan av_scanner clamd ftp_antivirus svc_clamav svc_ftp svc_proxy sec_clamav net_ftp"

for svc in $EXTRA_SERVICES; do
    echo " -> Adding entry: ${svc}_enable=\"YES\""
    iocage exec "$JAIL_NAME" sysrc "${svc}_enable=YES"
done

# Standard services for daemon and database updater
iocage exec "$JAIL_NAME" sysrc clamav_clamd_enable="YES"
iocage exec "$JAIL_NAME" sysrc clamav_freshclam_enable="YES"

echo "6. Downloading virus definitions (this might take a few minutes!)..."
iocage exec "$JAIL_NAME" freshclam

echo "=================================================="
echo "Done! The ClamAV environment is ready."
echo "All requested services have been configured."
echo "You can now log into the Jail using the command:"
echo "  iocage console $JAIL_NAME"
echo "=================================================="

# Pause before destroying the environment
echo "Press ENTER when you are done to DESTROY the Jail..."
echo "Or press Ctrl+C to abort and leave it running."
read -r dummy

echo "=================================================="
echo "Stopping and destroying Jail '$JAIL_NAME'..."
echo "=================================================="
iocage destroy -f "$JAIL_NAME"

echo "The environment has been cleaned up successfully."
