#!/bin/bash
mkdir -p /tmp/swtpm-sock
swtpm socket --tpmstate dir=/tmp/swtpm-sock --ctrl type=unixio,path=/tmp/swtpm-sock/swtpm-sock --tpm2 --log level=0 >/dev/null 2>&1  &
SWTPM_PID=$!
echo "Started swtpm with PID $SWTPM_PID"

# Wait for socket
sleep 1

cp /usr/share/OVMF/OVMF_VARS_4M.fd ./OVMF_VARS.fd
chmod 666 ./OVMF_VARS.fd

# Run Packer
env PACKER_LOG=1 packer build windows11-qemu.pkr.hcl
PACKER_EXIT_CODE=$?

# Cleanup
kill $SWTPM_PID
rm -rf /tmp/swtpm-sock

# Post-Process: Compress Image
if [ $PACKER_EXIT_CODE -eq 0 ]; then
    echo "Packer build successful. Compressing image..."
    if [ -f "output-windows11/windows11" ]; then
        qemu-img convert -O qcow2 -c output-windows11/windows11 windows11-compressed.qcow2
        echo "Image compressed: windows11-compressed.qcow2"
    else
        echo "Error: Output image not found!"
    fi
else
    echo "Packer build failed. Skipping compression."
fi

exit $PACKER_EXIT_CODE
