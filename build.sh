#!/bin/bash
mkdir -p /tmp/swtpm-sock
swtpm socket --tpmstate dir=/tmp/swtpm-sock --ctrl type=unixio,path=/tmp/swtpm-sock/swtpm-sock --tpm2 --log level=0 >/dev/null 2>&1  &
SWTPM_PID=$!
echo "Started swtpm with PID $SWTPM_PID"

# Wait for socket
sleep 1

cp /usr/share/OVMF/OVMF_VARS_4M.fd ./OVMF_VARS.fd
chmod 644 ./OVMF_VARS.fd

# Run Packer
env PACKER_LOG=1 packer build windows11-qemu.pkr.hcl

# Cleanup
kill $SWTPM_PID
rm -rf /tmp/swtpm-sock

