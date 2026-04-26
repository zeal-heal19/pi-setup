from flask import Flask, render_template, request, Response, stream_with_context, session, redirect, url_for
import paramiko
import json
import re
import time
import os
import webbrowser
import threading

_ANSI = re.compile(r'\x1b(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')

def strip_ansi(text):
    return _ANSI.sub('', text)

app = Flask(__name__)
app.secret_key = os.urandom(24)

ADMIN_USER = "admin"
ADMIN_PASS = "admin@123"

STAGES = [
    {"id": "connect",  "label": "Connect to Pi"},
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

def detect_stage(line):
    if line.startswith('##STAGE:') and line.endswith('##'):
        return line[8:-2]
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
                f'-H "Accept: application/vnd.github.v3.raw" '
                f'"https://api.github.com/repos/zeal-heal19/pi-setup/contents/pi-setup.sh") '
                f'--pi-version 4 '
                f'--repo-url https://github.com/zeal-heal19/alt-prayer-timetable-master.git '
                f'--git-token {github_token} '
                f'--git-branch feature/pi-os-lite-support\n'
            )
            channel.send(cmd)

            # Repeatable prompts — stay in list (sudo can appear multiple times)
            repeat_prompts = [
                ('[sudo] password for pi:', ssh_password + '\n'),
            ]
            # One-shot prompts — removed after first match to prevent false re-triggers
            once_prompts = [
                ('Mosque Name:',   mosque_name    + '\n'),
                ('Latitude (e.g.', latitude       + '\n'),
                ('Longitude (e.g.',longitude      + '\n'),
                ('Mosque Code (e.g',mosque_code   + '\n'),
                ('Admin Username:', admin_user     + '\n'),
                ('Admin Password:', admin_password + '\n'),
                ('reboot now',     'n\n'),
                ('(y/n)',          'n\n'),
            ]

            current_stage = None
            buffer = ''

            while True:
                if channel.recv_ready():
                    chunk = channel.recv(4096).decode('utf-8', errors='replace')
                    # \r\n → \n, lone \r (progress overwrites) → \n
                    chunk = chunk.replace('\r\n', '\n').replace('\r', '\n')
                    buffer += chunk

                    lines = buffer.split('\n')
                    buffer = lines[-1]

                    for line in lines[:-1]:
                        clean = strip_ansi(line).strip()
                        if not clean:
                            continue
                        yield evt('log', msg=clean)
                        stage = detect_stage(clean)
                        if stage and stage != current_stage:
                            if current_stage:
                                yield evt('stage', id=current_stage, status='success')
                            yield evt('stage', id=stage, status='running')
                            current_stage = stage

                    responded = False
                    for i, (prompt, response) in enumerate(once_prompts):
                        if prompt.lower() in buffer.lower():
                            channel.send(response)
                            yield evt('log', msg=f'[ auto-filled: {prompt.strip()} ]')
                            once_prompts.pop(i)
                            buffer = ''
                            responded = True
                            break
                    if not responded:
                        for prompt, response in repeat_prompts:
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


@app.route('/reboot', methods=['POST'])
def reboot_pi():
    if 'logged_in' not in session:
        return {'success': False, 'error': 'Unauthorized'}, 401

    data         = request.json
    pi_host      = data.get('pi_host', 'mysystem.local')
    ssh_password = data.get('ssh_password', '')

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(pi_host, username='pi', password=ssh_password, timeout=15)
        ssh.exec_command('sudo reboot')
        return {'success': True}
    except Exception as e:
        return {'success': False, 'error': str(e)}
    finally:
        ssh.close()


if __name__ == '__main__':
    def open_browser():
        time.sleep(1)
        webbrowser.open('http://localhost:5001')
    threading.Thread(target=open_browser).start()
    app.run(host='0.0.0.0', port=5001, debug=False, threaded=True)
