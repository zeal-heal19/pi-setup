from flask import Flask, render_template, request, Response, stream_with_context, session, redirect, url_for
import paramiko
import json
import time
import os
import webbrowser
import threading

app = Flask(__name__)
app.secret_key = os.urandom(24)

ADMIN_USER = "admin"
ADMIN_PASS = "admin@123"

STAGES = [
    {"id": "connect",  "label": "Connect to Pi"},
    {"id": "update",   "label": "System Update"},
    {"id": "packages", "label": "Install Packages"},
    {"id": "python",   "label": "Python Environment"},
    {"id": "clone",    "label": "Clone Application"},
    {"id": "mosque",   "label": "Mosque Configuration"},
    {"id": "network",  "label": "WiFi & Hotspot"},
    {"id": "rtc",      "label": "RTC Clock (DS3231)"},
    {"id": "kiosk",    "label": "Kiosk Autostart"},
    {"id": "tv",       "label": "TV Schedule"},
    {"id": "security", "label": "Security (USB)"},
    {"id": "cleanup",  "label": "Cleanup Files"},
    {"id": "email",    "label": "Completion Email"},
    {"id": "complete", "label": "Setup Complete"},
]

STAGE_KEYWORDS = {
    "update":   ["updating system", "apt-get update", "apt upgrade", "package list"],
    "packages": ["installing packages", "apt install", "chromium", "openbox", "cec-utils"],
    "python":   ["python environment", "virtualenv", "pip install", "myenv"],
    "clone":    ["cloning", "git clone", "repository", "application files"],
    "mosque":   ["mosque", "prayer config", "latitude", "longitude", "mosque code"],
    "network":  ["hotspot", "wi-fi", "networkmanager", "my-hotspot", "access point"],
    "rtc":      ["rtc module", "ds3231", "i2cdetect", "hwclock", "real-time clock", "setting up rtc"],
    "kiosk":    ["autostart", "kiosk", "lightdm", "graphical target", "xorg"],
    "tv":       ["tv schedule", "cron", "tv-control", "hdmi-cec", "tv on"],
    "security": ["usb", "blacklist", "initramfs", "modprobe", "disabling usb"],
    "cleanup":  ["cleanup", "removing non", "cleaning up"],
    "email":    ["sending email", "smtp", "completion email", "notification"],
    "complete": ["setup complete", "completed successfully", "all done", "setup finished"],
}

def detect_stage(line):
    line_lower = line.lower()
    for stage_id, keywords in STAGE_KEYWORDS.items():
        if any(k in line_lower for k in keywords):
            return stage_id
    return None

@app.route('/')
def index():
    if 'logged_in' not in session:
        return redirect(url_for('login'))
    return render_template('index.html', stages=STAGES)

@app.route('/login', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
        if request.form['username'] == ADMIN_USER and request.form['password'] == ADMIN_PASS:
            session['logged_in'] = True
            return redirect(url_for('index'))
        error = 'Invalid credentials. Please try again.'
    return render_template('login.html', error=error)

@app.route('/logout')
def logout():
    session.pop('logged_in', None)
    return redirect(url_for('login'))

@app.route('/deploy', methods=['POST'])
def deploy():
    if 'logged_in' not in session:
        return Response('Unauthorized', status=401)

    data           = request.json
    pi_host        = data.get('pi_host', 'mysystem.local')
    ssh_password   = data.get('ssh_password', '')
    github_token   = data.get('github_token', '')
    mosque_name    = data.get('mosque_name', '')
    latitude       = data.get('latitude', '')
    longitude      = data.get('longitude', '')
    mosque_code    = data.get('mosque_code', '')
    admin_user     = data.get('admin_user', 'admin')
    admin_password = data.get('admin_password', '')

    def generate():
        def evt(type, **kwargs):
            return f"data: {json.dumps({'type': type, **kwargs})}\n\n"

        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

        try:
            yield evt('stage', id='connect', status='running')
            yield evt('log', msg=f'Connecting to {pi_host}...')

            ssh.connect(pi_host, username='pi', password=ssh_password, timeout=15)

            yield evt('stage', id='connect', status='success')
            yield evt('log', msg='Connected to Pi successfully')

            channel = ssh.invoke_shell(width=220, height=50)
            time.sleep(1)
            if channel.recv_ready():
                channel.recv(65535)

            cmd = (
                f'bash <(curl -s '
                f'-H "Authorization: token {github_token}" '
                f'-H "Accept: application/vnd.github.v3.raw" '
                f'"https://api.github.com/repos/zeal-heal19/alt-prayer-timetable-master'
                f'/contents/pi-setup.sh?ref=feature/pi-os-lite-support") '
                f'--pi-version 4 '
                f'--repo-url https://github.com/zeal-heal19/alt-prayer-timetable.git '
                f'--git-token {github_token} '
                f'--git-branch main\n'
            )
            channel.send(cmd)

            prompts = [
                ('Mosque Name:',     mosque_name    + '\n'),
                ('Latitude:',        latitude       + '\n'),
                ('Longitude:',       longitude      + '\n'),
                ('Mosque Code:',     mosque_code    + '\n'),
                ('Admin Username:',  admin_user     + '\n'),
                ('Admin Password:',  admin_password + '\n'),
                ('Confirm Password:', admin_password + '\n'),
                ('reboot now',       'n\n'),
                ('(y/n)',            'n\n'),
            ]

            current_stage = None
            buffer = ''

            while True:
                if channel.recv_ready():
                    chunk = channel.recv(4096).decode('utf-8', errors='replace')
                    buffer += chunk

                    lines = buffer.split('\n')
                    buffer = lines[-1]

                    for line in lines[:-1]:
                        clean = line.strip()
                        if not clean:
                            continue
                        yield evt('log', msg=clean)
                        stage = detect_stage(clean)
                        if stage and stage != current_stage:
                            if current_stage:
                                yield evt('stage', id=current_stage, status='success')
                            yield evt('stage', id=stage, status='running')
                            current_stage = stage

                    for prompt, response in prompts:
                        if prompt.lower() in buffer.lower():
                            channel.send(response)
                            yield evt('log', msg=f'[ auto-filled: {prompt.strip()} ]')
                            buffer = ''
                            break

                    if any(k in buffer.lower() for k in ['setup complete', 'completed successfully', 'setup finished']):
                        if current_stage:
                            yield evt('stage', id=current_stage, status='success')
                        yield evt('stage', id='complete', status='success')
                        yield evt('done', msg='Setup completed successfully!')
                        break

                if channel.exit_status_ready():
                    break

                time.sleep(0.05)

        except paramiko.AuthenticationException:
            yield evt('error', msg='SSH authentication failed. Please check your SSH password.')
        except Exception as e:
            yield evt('error', msg=str(e))
        finally:
            ssh.close()

    return Response(
        stream_with_context(generate()),
        mimetype='text/event-stream',
        headers={'Cache-Control': 'no-cache', 'X-Accel-Buffering': 'no'}
    )


if __name__ == '__main__':
    def open_browser():
        time.sleep(1)
        webbrowser.open('http://localhost:5001')
    threading.Thread(target=open_browser).start()
    app.run(host='0.0.0.0', port=5001, debug=False, threaded=True)
