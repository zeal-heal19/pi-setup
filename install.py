"""
Run this ONE TIME to install dependencies and create a desktop shortcut.
After that, just double-click the icon on your Desktop to launch the deployer.
"""

import subprocess
import sys
import os
import platform


def install():
    app_dir = os.path.dirname(os.path.abspath(__file__))
    desktop = os.path.join(os.path.expanduser('~'), 'Desktop')
    system  = platform.system()

    print("=" * 52)
    print("  Salah-e-Waqt Pi Deployer — One Time Setup")
    print("=" * 52)

    # Step 1 — Install dependencies
    print("\n[1/2] Installing dependencies...")
    subprocess.run(
        [sys.executable, '-m', 'pip', 'install', 'flask', 'paramiko', '--quiet'],
        check=True
    )
    print("      ✓ flask and paramiko installed.")

    # Step 2 — Create desktop shortcut
    print("\n[2/2] Creating desktop shortcut...")

    if system == 'Windows':
        # Use pythonw.exe (same dir as python.exe) — runs silently, no console window
        pythonw = os.path.join(os.path.dirname(sys.executable), 'pythonw.exe')
        if not os.path.exists(pythonw):
            pythonw = 'pythonw'  # fall back to PATH
        # VBScript launcher: window style 0 = completely hidden, no CMD flash
        shortcut = os.path.join(desktop, 'Pi Deployer.vbs')
        with open(shortcut, 'w') as f:
            f.write(f'CreateObject("WScript.Shell").Run "{pythonw} ""{app_dir}\\app.py""", 0\n')
        print(f'      ✓ Shortcut created: Desktop → Pi Deployer.vbs')

    elif system == 'Darwin':  # macOS
        shortcut = os.path.join(desktop, 'Pi Deployer.command')
        with open(shortcut, 'w') as f:
            f.write('#!/bin/bash\n')
            f.write(f'cd "{app_dir}"\n')
            f.write('python3 app.py\n')
        os.chmod(shortcut, 0o755)
        print(f'      ✓ Shortcut created: Desktop → Pi Deployer.command')

    elif system == 'Linux':
        icon = os.path.join(app_dir, 'static', 'logo-email.png')
        shortcut = os.path.join(desktop, 'pi-deployer.desktop')
        with open(shortcut, 'w') as f:
            f.write('[Desktop Entry]\n')
            f.write('Type=Application\n')
            f.write('Name=Pi Deployer\n')
            f.write('Comment=Salah-e-Waqt Pi Deployment Tool\n')
            f.write(f'Exec=python3 {app_dir}/app.py\n')
            f.write(f'Icon={icon}\n')
            f.write('Terminal=false\n')
            f.write('Categories=Utility;\n')
        os.chmod(shortcut, 0o755)
        print(f'      ✓ Shortcut created: Desktop → pi-deployer.desktop')

    else:
        print(f'      Unsupported OS ({system}). Run "python app.py" manually.')

    print("\n" + "=" * 52)
    print("  ✓ Setup complete!")
    print()
    print("  From now on, just double-click 'Pi Deployer'")
    print("  on your Desktop to open the deployment tool.")
    print("=" * 52 + "\n")


if __name__ == '__main__':
    install()
