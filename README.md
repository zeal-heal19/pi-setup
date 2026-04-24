# Salah-e-Waqt — Pi Deployer

Web-based deployment tool for the Salah-e-Waqt Prayer Timetable Kiosk.  
Deploy to a Raspberry Pi from your browser — no terminal commands after setup.

---

## One-Time Setup

Download or clone this repo, then run **once**:

```bash
python install.py
```

This will:
1. Install required dependencies (`flask`, `paramiko`)
2. Create a **Pi Deployer** icon on your Desktop

---

## Deploy a Pi (every time)

1. **Connect your laptop** to the same WiFi as the Raspberry Pi
2. **Double-click** `Pi Deployer` icon on your Desktop
3. Browser opens automatically at `http://localhost:5001`
4. **Login** with your credentials
5. **Fill the form** and click **Start Deployment**
6. Watch the live pipeline — all steps run automatically
7. **Reboot the Pi** when complete

---

## Login Credentials

| Field    | Default     |
|----------|-------------|
| Username | `admin`     |
| Password | `admin@123` |

> To change: edit `ADMIN_USER` and `ADMIN_PASS` in `app.py`

---

## Form Fields

| Field | Description |
|-------|-------------|
| Pi Hostname | Always `mysystem.local` |
| SSH Password | Password set during Pi Imager |
| GitHub Token | Personal access token to fetch setup script |
| Mosque Name | Full mosque name |
| Latitude / Longitude | Mosque GPS coordinates |
| Mosque Code | Unique code e.g. `001` |
| Admin Username | For the kiosk admin panel |
| Admin Password | For the kiosk admin panel |

---

## Requirements

- Python 3.7+
- Laptop and Pi on the **same WiFi network**
- Pi must have **SSH enabled** (configured in Pi Imager)

---

## Project Structure

```
pi-setup/
├── app.py              ← Flask backend (SSH + live streaming)
├── install.py          ← One-time setup script
├── requirements.txt    ← Python dependencies
├── templates/
│   ├── login.html      ← Login page
│   └── index.html      ← Deployment UI with live pipeline
├── static/
│   └── logo-email.png  ← App logo
└── pi-setup.sh         ← Raspberry Pi setup script
```
