import winrm
import sys
import os
import time

def get_log(session, remote_path, local_path):
    print(f"--- Downloading {remote_path} to {local_path} ---")
    r = session.run_ps(f"Get-Content '{remote_path}'")
    if r.status_code == 0:
        content = r.std_out.decode()
        if content.strip():
            with open(local_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Saved {len(content)} bytes.")
        else:
            print("Log file is empty.")
    else:
        err = r.std_err.decode().strip()
        print(f"Error downloading {remote_path}: {err}")

try:
    print("Connecting to WinRM (localhost:5985)...")
    s = winrm.Session('http://127.0.0.1:5985', auth=('packer', 'packer'))
    
    timestamp = int(time.time())
    
    # Download setuperr.log
    get_log(s, r"C:\Windows\System32\Sysprep\Panther\setuperr.log", f"sysprep_setuperr_{timestamp}.log")
    
    # Download setupact.log
    get_log(s, r"C:\Windows\System32\Sysprep\Panther\setupact.log", f"sysprep_setupact_{timestamp}.log")

except Exception as e:
    print(f"Connection failed: {e}")
    # Don't exit with error to avoid breaking the bash loop if network blips
    sys.exit(0) 
