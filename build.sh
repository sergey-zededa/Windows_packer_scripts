#!/bin/bash
mkdir -p /tmp/swtpm-sock
swtpm socket --tpmstate dir=/tmp/swtpm-sock --ctrl type=unixio,path=/tmp/swtpm-sock/swtpm-sock --tpm2 --log level=0 >/dev/null 2>&1  &
SWTPM_PID=$!
echo "Started swtpm with PID $SWTPM_PID"

# Wait for socket
sleep 1

cp /usr/share/OVMF/OVMF_VARS_4M.fd ./OVMF_VARS.fd
chmod 666 ./OVMF_VARS.fd

# Run Packer in background
# Use -on-error=abort to keep artifacts on failure
echo "Starting Packer..."
env PACKER_LOG=1 packer build -on-error=abort windows11-qemu.pkr.hcl > packer.log 2>&1 &
PACKER_PID=$!

echo "Packer started with PID $PACKER_PID. Monitoring logs..."

# Monitoring Loop
SYSPRP_STARTED=0
while kill -0 $PACKER_PID 2>/dev/null; do
    if [ $SYSPRP_STARTED -eq 0 ]; then
        if grep -q "Starting Sysprep" packer.log; then
            echo "Sysprep detected! Starting log dump loop..."
            SYSPRP_STARTED=1
        fi
    else
        # Try to dump logs every 60 seconds
        python3 dump_logs.py
        sleep 60
    fi
    sleep 5
done

wait $PACKER_PID
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
    echo "Packer build failed (Exit Code: $PACKER_EXIT_CODE). Artifacts should be preserved in output-windows11/"
    echo "Check sysprep_*.log files for diagnosis."
fi

exit $PACKER_EXIT_CODE
