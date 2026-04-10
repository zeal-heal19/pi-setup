#!/bin/bash
###############################################################################
# Raspberry Pi Prayer Timetable - Complete Setup Script
# This script sets up everything needed to run the prayer timetable in kiosk mode
#
# Usage:
#   ./pi-setup.sh [OPTIONS]
#
# Options:
#   --repo-url URL        Git repository URL (for private repos)
#   --git-token TOKEN     Personal Access Token for private repo authentication
#   --git-user USERNAME   Git username (alternative to token)
#   --git-pass PASSWORD   Git password (alternative to token)
#   --help                Show this help message
#
# Examples:
#   # Local setup (copy files from current directory)
#   ./pi-setup.sh
#
#   # Clone from private GitHub repo using Personal Access Token
#   ./pi-setup.sh --repo-url https://github.com/username/alt-prayer-timetable.git --git-token ghp_xxxxx
#
#   # Clone from private repo using username/password
#   ./pi-setup.sh --repo-url https://github.com/username/alt-prayer-timetable.git --git-user myuser --git-pass mypass
#
###############################################################################

set -e  # Exit on any error

# Prevent ALL apt/dpkg interactive prompts globally
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PI_USER="pi"
PI_HOME="$HOME"
PROJECT_NAME="alt-prayer-timetable"
PROJECT_DIR="$PI_HOME/my-application"
VENV_DIR="$PI_HOME/myenv"
LOG_FILE="$PI_HOME/setup.log"

# Git repository settings (can be overridden by command-line arguments)
GIT_REPO_URL=""
GIT_TOKEN=""
GIT_USERNAME=""
GIT_PASSWORD=""

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo "" | tee -a "$LOG_FILE"
    echo "=========================================" | tee -a "$LOG_FILE"
    echo "$1" | tee -a "$LOG_FILE"
    echo "=========================================" | tee -a "$LOG_FILE"
}

# Show help message
show_help() {
    cat << EOF
Raspberry Pi Prayer Timetable - Complete Setup Script

Usage:
  ./pi-setup.sh [OPTIONS]

Options:
  --repo-url URL        Git repository URL (HTTPS format)
  --git-token TOKEN     Personal Access Token for private repo
  --git-user USERNAME   Git username (alternative to token)
  --git-pass PASSWORD   Git password (alternative to token)
  --help                Show this help message

Examples:
  # Local setup (copy files from current directory)
  ./pi-setup.sh

  # Clone from private GitHub repo using Personal Access Token
  ./pi-setup.sh --repo-url https://github.com/username/alt-prayer-timetable.git --git-token ghp_xxxxx

  # Clone from private repo using username/password
  ./pi-setup.sh --repo-url https://github.com/username/repo.git --git-user myuser --git-pass mypass

Notes:
  - For GitHub, create a Personal Access Token at: https://github.com/settings/tokens
  - Token needs 'repo' permission for private repositories
  - HTTPS URL format: https://github.com/username/repository.git

EOF
    exit 0
}

# Parse command-line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --repo-url)
                GIT_REPO_URL="$2"
                shift 2
                ;;
            --git-token)
                GIT_TOKEN="$2"
                shift 2
                ;;
            --git-user)
                GIT_USERNAME="$2"
                shift 2
                ;;
            --git-pass)
                GIT_PASSWORD="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

###############################################################################
# Step 1: System Update
###############################################################################
setup_system() {
    print_header "STEP 1: Updating System Packages"

    print_info "Updating package lists..."
    sudo apt update | tee -a "$LOG_FILE"

    print_info "Upgrading installed packages..."
    sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y \
        -o Dpkg::Options::="--force-confold" \
        -o Dpkg::Options::="--force-confdef" | tee -a "$LOG_FILE"

    print_success "System updated successfully"
}

###############################################################################
# Step 2: Install Required Packages
###############################################################################
install_dependencies() {
    print_header "STEP 2: Installing Required Packages"

    # Fix any broken dpkg/apt state before installing
    print_info "Fixing any broken package state..."
    sudo DEBIAN_FRONTEND=noninteractive dpkg \
        --force-confold --force-confdef \
        --configure -a || true
    sudo DEBIAN_FRONTEND=noninteractive apt --fix-broken install -y \
        -o Dpkg::Options::="--force-confold" \
        -o Dpkg::Options::="--force-confdef" || true

    print_info "Installing system packages..."
    sudo DEBIAN_FRONTEND=noninteractive apt install -y \
        -o Dpkg::Options::="--force-confold" \
        -o Dpkg::Options::="--force-confdef" \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        chromium \
        unclutter \
        feh \
        x11-xserver-utils \
        git \
        curl \
        vim \
        xdotool \
        matchbox-window-manager \
        xautomation \
        cec-utils | tee -a "$LOG_FILE"

    # Fix again after install in case anything broke mid-way
    sudo DEBIAN_FRONTEND=noninteractive dpkg --configure -a || true
    sudo DEBIAN_FRONTEND=noninteractive apt --fix-broken install -y \
        -o Dpkg::Options::="--force-confold" \
        -o Dpkg::Options::="--force-confdef" || true

    print_success "All system packages installed (including cec-utils for TV control)"
}

###############################################################################
# Step 3: Create Project Directory Structure
###############################################################################
setup_directories() {
    print_header "STEP 3: Setting Up Directory Structure"

    print_info "Creating project directory at $PROJECT_DIR..."
    mkdir -p "$PROJECT_DIR"

    print_info "Setting correct ownership..."
    sudo chown -R $PI_USER:$PI_USER "$PROJECT_DIR"

    print_success "Directory structure created"
}

###############################################################################
# Step 4: Get Project Files (Clone from Git or Copy Locally)
###############################################################################
copy_project_files() {
    print_header "STEP 4: Getting Project Files"

    if [ -n "$GIT_REPO_URL" ]; then
        # Clone from Git repository
        print_info "Cloning from repository: $GIT_REPO_URL"

        # Remove existing directory if it exists
        if [ -d "$PROJECT_DIR" ]; then
            print_info "Removing existing project directory..."
            rm -rf "$PROJECT_DIR"
        fi

        # Build authenticated clone URL
        CLONE_URL=""
        if [ -n "$GIT_TOKEN" ]; then
            # Use Personal Access Token
            print_info "Authenticating with Personal Access Token..."
            # Extract domain and path from URL
            REPO_DOMAIN=$(echo "$GIT_REPO_URL" | sed -E 's|https://([^/]+)/.*|\1|')
            REPO_PATH=$(echo "$GIT_REPO_URL" | sed -E 's|https://[^/]+/(.*)|\1|')
            CLONE_URL="https://x-access-token:${GIT_TOKEN}@${REPO_DOMAIN}/${REPO_PATH}"
        elif [ -n "$GIT_USERNAME" ] && [ -n "$GIT_PASSWORD" ]; then
            # Use username and password
            print_info "Authenticating with username and password..."
            REPO_DOMAIN=$(echo "$GIT_REPO_URL" | sed -E 's|https://([^/]+)/.*|\1|')
            REPO_PATH=$(echo "$GIT_REPO_URL" | sed -E 's|https://[^/]+/(.*)|\1|')
            CLONE_URL="https://${GIT_USERNAME}:${GIT_PASSWORD}@${REPO_DOMAIN}/${REPO_PATH}"
        else
            # Public repository or already authenticated
            CLONE_URL="$GIT_REPO_URL"
        fi

        # Clone the repository
        print_info "Cloning repository..."
        if git clone "$CLONE_URL" "$PROJECT_DIR" 2>&1 | tee -a "$LOG_FILE"; then
            print_success "Repository cloned successfully"
        else
            print_error "Failed to clone repository"
            print_error "Please check your repository URL and credentials"
            exit 1
        fi

        # Set correct ownership
        sudo chown -R $PI_USER:$PI_USER "$PROJECT_DIR"

    else
        # Copy from local directory
        CURRENT_DIR=$(pwd)

        if [ "$CURRENT_DIR" != "$PROJECT_DIR" ]; then
            print_info "Copying files from $CURRENT_DIR to $PROJECT_DIR..."

            # Copy all files except venv, .git, and __pycache__
            rsync -av \
                --exclude='venv' \
                --exclude='__pycache__' \
                --exclude='.git' \
                --exclude='*.pyc' \
                --exclude='.DS_Store' \
                "$CURRENT_DIR/" "$PROJECT_DIR/" | tee -a "$LOG_FILE"

            print_success "Project files copied"
        else
            print_info "Already in project directory, skipping copy"
        fi
    fi
}

###############################################################################
# Step 5: Set Up Python Virtual Environment
###############################################################################
setup_python_venv() {
    print_header "STEP 5: Setting Up Python Virtual Environment"

    cd "$PROJECT_DIR"

    print_info "Creating virtual environment at $VENV_DIR..."
    python3 -m venv "$VENV_DIR"

    print_info "Activating virtual environment..."
    source "$VENV_DIR/bin/activate"

    print_info "Upgrading pip..."
    pip install --upgrade pip | tee -a "$LOG_FILE"

    print_info "Installing Python dependencies from requirements.txt..."
    if [ -f "requirments.txt" ]; then
        pip install -r requirments.txt | tee -a "$LOG_FILE"
        print_success "Python dependencies installed"
    else
        print_warning "requirments.txt not found, skipping Python dependencies"
    fi
}

###############################################################################
# Step 6: Configure WiFi Auto-Switcher and Open Hotspot Profiles
###############################################################################
setup_wifi_profiles() {
    print_header "STEP 6: Setting Up WiFi Auto-Switcher"

    print_info "Creating WiFi profiles for open hotspots..."

    # Create profile for primary open hotspot
    print_info "Creating profile: salah-e-waqt-android (open hotspot)"
    sudo nmcli connection add \
        type wifi \
        con-name "salah-e-waqt-android" \
        ssid "salah-e-waqt" \
        wifi-sec.key-mgmt none \
        connection.autoconnect yes \
        connection.autoconnect-priority 100 2>/dev/null

    # Create backup profile for same hotspot
    print_info "Creating profile: salah-e-waqt-iphone (open hotspot)"
    sudo nmcli connection add \
        type wifi \
        con-name "salah-e-waqt-iphone" \
        ssid "salah-e-waqt" \
        wifi-sec.key-mgmt none \
        connection.autoconnect yes \
        connection.autoconnect-priority 100 2>/dev/null


    print_success "WiFi profiles created"

    # Create WiFi switcher script
    WIFI_SCRIPT="/usr/local/bin/wifi-switcher.sh"
    print_info "Creating WiFi auto-switcher script..."

    sudo tee "$WIFI_SCRIPT" > /dev/null << 'EOFWIFI'
#!/bin/bash
###############################################################################
# WiFi Auto-Switcher for Prayer Timetable
# Automatically switches between open hotspots
###############################################################################

TARGET_SSID="salah-e-waqt"
FALLBACK_SSID="my-hotspot"
LOG_FILE="/var/log/wifi-switcher.log"

# Get current connection
CURRENT_SSID=$(iwgetid -r)

# Scan for available networks
nmcli device wifi rescan 2>/dev/null
sleep 3

# Check if target network is available
TARGET_AVAILABLE=$(nmcli -t -f SSID device wifi list | grep -x "$TARGET_SSID")

if [ -n "$TARGET_AVAILABLE" ]; then
    # Target network found
    if [ "$CURRENT_SSID" != "$TARGET_SSID" ]; then
        echo "$(date): Switching to $TARGET_SSID" >> $LOG_FILE

        # Try Android profile first
        nmcli connection up "salah-e-waqt-android" 2>/dev/null
        sleep 5

        # Check if connected
        NEW_SSID=$(iwgetid -r)
        if [ "$NEW_SSID" != "$TARGET_SSID" ]; then
            # Android failed, try iPhone profile
            echo "$(date): Android profile failed, trying iPhone" >> $LOG_FILE
            nmcli connection up "salah-e-waqt-iphone" 2>/dev/null
            sleep 5
        fi

        # If both profiles failed, try direct connection
        NEW_SSID=$(iwgetid -r)
        if [ "$NEW_SSID" != "$TARGET_SSID" ]; then
            echo "$(date): Both profiles failed, trying direct connection" >> $LOG_FILE
            nmcli device wifi connect "$TARGET_SSID" 2>/dev/null
        fi

        # Log final result
        FINAL_SSID=$(iwgetid -r)
        FINAL_IP=$(hostname -I | awk '{print $1}')
        if [ "$FINAL_SSID" = "$TARGET_SSID" ]; then
            echo "$(date): ✓ Connected to $FINAL_SSID with IP $FINAL_IP" >> $LOG_FILE
        else
            echo "$(date): ✗ Failed to connect to $TARGET_SSID" >> $LOG_FILE
        fi
    fi
else
    # Target not available, use fallback
    if [ "$CURRENT_SSID" != "$FALLBACK_SSID" ]; then
        echo "$(date): $TARGET_SSID not found, connecting to $FALLBACK_SSID" >> $LOG_FILE
        nmcli connection up "$FALLBACK_SSID" 2>/dev/null
        sleep 5

        FINAL_SSID=$(iwgetid -r)
        FINAL_IP=$(hostname -I | awk '{print $1}')
        if [ "$FINAL_SSID" = "$FALLBACK_SSID" ]; then
            echo "$(date): ✓ Fallback connected to $FINAL_SSID with IP $FINAL_IP" >> $LOG_FILE
        else
            echo "$(date): ✗ Failed to connect to fallback" >> $LOG_FILE
        fi
    fi
fi

# Keep log file reasonable size (last 1000 lines)
if [ -f "$LOG_FILE" ]; then
    tail -1000 "$LOG_FILE" > "$LOG_FILE.tmp" 2>/dev/null && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi
EOFWIFI

    sudo chmod +x "$WIFI_SCRIPT"
    print_success "WiFi switcher script created"

    # Create log file
    sudo touch /var/log/wifi-switcher.log
    sudo chmod 666 /var/log/wifi-switcher.log

    # Create systemd service
    print_info "Creating systemd service..."
    sudo tee /etc/systemd/system/wifi-switcher.service > /dev/null << 'EOFSERVICE'
[Unit]
Description=WiFi Auto Switcher
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/wifi-switcher.sh
StandardOutput=append:/var/log/wifi-switcher.log
StandardError=append:/var/log/wifi-switcher.log
EOFSERVICE

    # Create systemd timer
    print_info "Creating systemd timer (runs every 2 minutes)..."
    sudo tee /etc/systemd/system/wifi-switcher.timer > /dev/null << 'EOFTIMER'
[Unit]
Description=Run WiFi switcher every 2 minutes

[Timer]
OnBootSec=60
OnUnitActiveSec=120

[Install]
WantedBy=timers.target
EOFTIMER

    # Reload systemd and enable timer
    print_info "Enabling WiFi auto-switcher..."
    sudo systemctl daemon-reload
    sudo systemctl enable wifi-switcher.timer
    sudo systemctl start wifi-switcher.timer

    print_success "WiFi auto-switcher configured (systemd timer)"

    # Run once immediately to test (non-fatal - hotspot may not be in range)
    print_info "Testing WiFi connection..."
    sudo "$WIFI_SCRIPT" || true
    sleep 3

    CURRENT_WIFI=$(iwgetid -r)
    CURRENT_IP=$(hostname -I | awk '{print $1}')

    if [ -n "$CURRENT_WIFI" ]; then
        print_success "Connected to: $CURRENT_WIFI (IP: $CURRENT_IP)"
    else
        print_warning "Not connected to any WiFi. Hotspots may not be in range yet."
        print_info "WiFi switcher will automatically connect when hotspots are available"
    fi
}

###############################################################################
# Step 7: Setup Raspberry Pi as WiFi Hotspot
###############################################################################
setup_pi_hotspot() {
    print_header "STEP 7: Setting Up Raspberry Pi as WiFi Hotspot"

    HOTSPOT_SSID="my-hotspot"
    HOTSPOT_IP="192.168.50.1"
    DHCP_RANGE_START="192.168.50.10"
    DHCP_RANGE_END="192.168.50.50"

    print_info "Installing hotspot packages..."
    sudo apt-get install -y hostapd dnsmasq > /dev/null 2>&1

    print_info "Stopping services..."
    sudo systemctl stop hostapd 2>/dev/null || true
    sudo systemctl stop dnsmasq 2>/dev/null || true

    print_info "Configuring static IP for wlan0..."
    # Backup dhcpcd.conf if not already backed up
    if [ ! -f /etc/dhcpcd.conf.backup ]; then
        sudo cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup
    fi

    # Add static IP configuration for hotspot
    sudo tee -a /etc/dhcpcd.conf > /dev/null << EOF

# Static IP for WiFi Hotspot (added by pi-setup.sh)
interface wlan0
    static ip_address=${HOTSPOT_IP}/24
    nohook wpa_supplicant
EOF

    print_info "Configuring DHCP server..."
    # Backup dnsmasq.conf if exists
    if [ -f /etc/dnsmasq.conf ]; then
        sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.backup 2>/dev/null || true
    fi

    # Create dnsmasq configuration
    sudo tee /etc/dnsmasq.conf > /dev/null << EOF
# DHCP server for WiFi hotspot
interface=wlan0
dhcp-range=${DHCP_RANGE_START},${DHCP_RANGE_END},255.255.255.0,24h
domain=wlan
address=/gw.wlan/${HOTSPOT_IP}
bogus-priv
EOF

    print_info "Configuring WiFi Access Point..."
    # Create hostapd configuration for OPEN hotspot
    sudo tee /etc/hostapd/hostapd.conf > /dev/null << EOF
# WiFi Access Point Configuration (Open Hotspot)
interface=wlan0
driver=nl80211
ssid=${HOTSPOT_SSID}
hw_mode=g
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
EOF

    # Point hostapd to config file
    sudo tee /etc/default/hostapd > /dev/null << EOF
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF

    print_info "Enabling hotspot services..."
    sudo systemctl unmask hostapd
    sudo systemctl enable hostapd
    sudo systemctl enable dnsmasq

    print_success "Pi Hotspot configured"
    print_info "Hotspot details:"
    echo "  • SSID: $HOTSPOT_SSID (open - no password)"
    echo "  • IP Address: $HOTSPOT_IP"
    echo "  • DHCP Range: $DHCP_RANGE_START - $DHCP_RANGE_END"
    echo "  • Admin Panel: http://$HOTSPOT_IP:5000/home"
}

###############################################################################
# Step 8: Configure Boot Config for Performance (1080p + Overclock + RTC)
###############################################################################
configure_boot_config() {
    print_header "STEP 8: Configuring Boot Settings for Performance"

    CONFIG_FILE="/boot/firmware/config.txt"

    # Backup original config
    if [ ! -f "${CONFIG_FILE}.backup" ]; then
        print_info "Backing up original config.txt..."
        sudo cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
        print_success "Backup created at ${CONFIG_FILE}.backup"
    fi

    print_info "Adding performance optimizations to config.txt..."

    # Add performance settings
    sudo tee -a "$CONFIG_FILE" > /dev/null << 'EOFCONFIG'

# ========================================
# Performance Optimizations (Added by pi-setup.sh)
# ========================================

# DISPLAY SETTINGS - Force 1080p @ 60Hz
hdmi_enable_4k=0
hdmi_group=2
hdmi_mode=82
hdmi_force_hotplug=1
hdmi_drive=2
config_hdmi_boost=7
hdmi_ignore_edid=0xa5000080
max_framebuffer_width=1920
max_framebuffer_height=1080

# PERFORMANCE - CPU/GPU Overclock
force_turbo=1
over_voltage=2
arm_freq=1800
gpu_freq=600
gpu_mem=256
sdram_freq=3200
over_voltage_sdram=2

# FAN CONTROL (if fan connected to GPIO 14)
dtoverlay=gpio-fan,gpiopin=14,temp=80000

# RTC MODULE (DS3231) - Enable I2C RTC for offline time keeping
dtoverlay=i2c-rtc,ds3231
EOFCONFIG

    print_success "Boot config optimized for 1080p + performance"
    print_info "Settings applied:"
    echo "  • Resolution: 1080p @ 60Hz (forced)"
    echo "  • CPU: 1800MHz (overclocked from 1500MHz)"
    echo "  • GPU: 600MHz (overclocked from 500MHz)"
    echo "  • GPU Memory: 256MB"
    echo "  • Fan: Activates at 80°C"
    echo "  • RTC: DS3231 module enabled (I2C)"
}

###############################################################################
# Step 8b: Setup RTC Module (DS3231)
###############################################################################
setup_rtc_module() {
    print_header "STEP 8b: Setting Up RTC Module (DS3231)"

    print_info "Installing I2C tools and hwclock utility..."
    sudo apt install -y i2c-tools util-linux-extra 2>/dev/null || sudo apt install -y i2c-tools util-linux 2>/dev/null

    # Enable I2C if not already enabled
    print_info "Enabling I2C interface..."
    sudo raspi-config nonint do_i2c 0 2>/dev/null || true

    # Check if RTC is detected
    print_info "Checking for RTC module at address 0x68..."
    RTC_DETECTED=$(sudo i2cdetect -y 1 2>/dev/null | grep -o "68\|UU" | head -1)

    if [ -n "$RTC_DETECTED" ]; then
        if [ "$RTC_DETECTED" = "UU" ]; then
            print_success "RTC module detected and driver loaded"
        else
            print_success "RTC module detected at address 0x68"
            print_info "RTC driver will be loaded after reboot"
        fi

        # Sync system time to RTC if hwclock is available
        if command -v hwclock &> /dev/null; then
            print_info "Syncing system time to RTC..."
            sudo hwclock -w 2>/dev/null && print_success "Time synced to RTC" || print_warning "Could not sync time (will work after reboot)"
        fi

        print_success "RTC module configured"
        print_info "RTC Details:"
        echo "  • Module: DS3231 (high accuracy)"
        echo "  • I2C Address: 0x68"
        echo "  • Battery: CR2032 (3-5 year lifespan)"
        echo "  • Accuracy: ±2ppm (~1 min/year drift)"
    else
        print_warning "RTC module not detected at address 0x68"
        print_info "If RTC is connected, it will be detected after reboot"
        print_info "RTC Wiring (DS3231 to Pi GPIO):"
        echo "  • VCC → Pin 1 (3.3V)"
        echo "  • GND → Pin 9 (GND)"
        echo "  • SDA → Pin 3 (GPIO 2)"
        echo "  • SCL → Pin 5 (GPIO 3)"
    fi
}

###############################################################################
# Step 9: Create Optimized Kiosk Run Script
###############################################################################
create_kiosk_script() {
    print_header "STEP 9: Creating Optimized Kiosk Run Script"

    KIOSK_SCRIPT="$PI_HOME/kiosk_run.sh"

    print_info "Creating kiosk script at $KIOSK_SCRIPT..."

    cat > "$KIOSK_SCRIPT" << 'EOFKIOSK'
#!/bin/bash
###############################################################################
# Prayer Timetable Kiosk Mode Runner (Performance Optimized)
###############################################################################

# ========================================
# LOGGING TOGGLE - Change to "true" to enable logging
# ========================================
ENABLE_LOGGING="false"

LOGFILE="/home/pi/kiosk.log"
PROJECT_DIR="/home/pi/my-application"
SPLASH_IMAGE="$PROJECT_DIR/images/splash.png"

log() {
    if [ "$ENABLE_LOGGING" = "true" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
    fi
}

log "========================================="
log "Starting Prayer Timetable Kiosk"
log "========================================="

# ========================================
# HDMI-CEC: Turn on TV and switch input
# ========================================
if command -v cec-client &> /dev/null; then
    log "HDMI-CEC: Turning on TV..."

    # Turn on TV (device 0 = TV)
    echo 'on 0' | cec-client -s -d 1 2>/dev/null
    sleep 2

    # Make Raspberry Pi the active source (switch TV to Pi's HDMI input)
    echo 'as' | cec-client -s -d 1 2>/dev/null
    sleep 2

    log "HDMI-CEC: TV powered on and switched to Pi HDMI input"
else
    log "WARNING: cec-client not installed. TV control disabled."
    log "Install with: sudo apt install cec-utils"
fi

# Set display environment variable
export DISPLAY=:0

# Wait for X server to be ready
log "Waiting for X server..."
while ! xset q &>/dev/null; do
    sleep 1
done
log "X server ready"

# Hide cursor
log "Hiding mouse cursor..."
unclutter -idle 0.1 -root &

# Hide desktop and taskbar
log "Hiding desktop elements..."
killall lxpanel 2>/dev/null
killall lxqt-panel 2>/dev/null
killall pcmanfm 2>/dev/null
xsetroot -solid black

# Disable notification daemons (prevents WiFi/hotspot popups)
log "Disabling notifications..."
killall notification-daemon 2>/dev/null
killall xfce4-notifyd 2>/dev/null
killall dunst 2>/dev/null
killall lxqt-notificationd 2>/dev/null
killall nm-applet 2>/dev/null

sleep 0.5

# Show splash screen
if command -v feh &> /dev/null && [ -f "$SPLASH_IMAGE" ]; then
    log "Displaying splash screen..."
    feh --fullscreen --hide-pointer --borderless --auto-zoom "$SPLASH_IMAGE" &
    SPLASH_PID=$!
    log "Splash screen displayed (PID: $SPLASH_PID)"
else
    log "WARNING: feh not installed or splash image not found"
fi

sleep 4

# Start HTTP server
log "Starting HTTP server on port 8000..."
cd "$PROJECT_DIR"
if [ "$ENABLE_LOGGING" = "true" ]; then
    $HOME/myenv/bin/python -m http.server 8000 --directory "$PROJECT_DIR" >> "$LOGFILE" 2>&1 &
else
    $HOME/myenv/bin/python -m http.server 8000 --directory "$PROJECT_DIR" > /dev/null 2>&1 &
fi
HTTP_PID=$!
log "HTTP server started (PID: $HTTP_PID)"

sleep 60

# Start Flask server
log "Starting Flask server on port 5000..."
if [ "$ENABLE_LOGGING" = "true" ]; then
    $HOME/myenv/bin/python "$PROJECT_DIR/server.py" >> "$LOGFILE" 2>&1 &
else
    $HOME/myenv/bin/python "$PROJECT_DIR/server.py" > /dev/null 2>&1 &
fi
FLASK_PID=$!
log "Flask server started (PID: $FLASK_PID)"

# Wait for Flask to be ready
log "Waiting for Flask server to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:5000 > /dev/null 2>&1; then
        log "Flask server is responding!"
        break
    fi
    log "Waiting... attempt $i/30"
    sleep 2
done

# Force 1080p resolution before launching browser
log "Setting resolution to 1080p..."
xrandr --output HDMI-1 --mode 1920x1080 --rate 60 2>/dev/null || true
sleep 2
log "Resolution set to 1080p"

# Disable screen blanking and power management
xset s off
xset -dpms
xset s noblank

log "Launching Chromium in kiosk mode with GPU acceleration..."
if [ "$ENABLE_LOGGING" = "true" ]; then
    CHROMIUM_LOG="/home/pi/chromium.log"
else
    CHROMIUM_LOG="/dev/null"
fi
/bin/chromium-browser \
  --kiosk \
  --incognito \
  --noerrdialogs \
  --disable-session-crashed-bubble \
  --disable-infobars \
  --check-for-update-interval=31536000 \
  --start-fullscreen \
  --overscroll-history-navigation=0 \
  --disable-pinch \
  --disable-translate \
  --fast --fast-start --disable-features=TranslateUI \
  --enable-gpu-rasterization \
  --enable-zero-copy \
  --enable-native-gpu-memory-buffers \
  --ignore-gpu-blocklist \
  --disable-smooth-scrolling \
  --disable-low-res-tiling \
  --enable-accelerated-2d-canvas \
  --disable-site-isolation-trials \
  --disable-features=IsolateOrigins,site-per-process \
  --disk-cache-size=1 \
  --disable-hang-monitor \
  http://localhost:8000 >> "$CHROMIUM_LOG" 2>&1 &

CHROMIUM_PID=$!
log "Chromium launched (PID: $CHROMIUM_PID)"

# Close splash screen after browser loads
sleep 10
if [ ! -z "$SPLASH_PID" ]; then
    log "Closing splash screen..."
    kill $SPLASH_PID 2>/dev/null
    log "Splash screen closed"
fi

# Monitor processes
while kill -0 $CHROMIUM_PID 2>/dev/null; do
    sleep 60

    # Check if Flask is still running
    if ! kill -0 $FLASK_PID 2>/dev/null; then
        log "ERROR: Flask server died! Restarting..."
        cd "$PROJECT_DIR"
        if [ "$ENABLE_LOGGING" = "true" ]; then
            $HOME/myenv/bin/python "$PROJECT_DIR/server.py" >> "$LOGFILE" 2>&1 &
        else
            $HOME/myenv/bin/python "$PROJECT_DIR/server.py" > /dev/null 2>&1 &
        fi
        FLASK_PID=$!
        log "Flask server restarted (PID: $FLASK_PID)"
    fi
done

log "Chromium exited"
log "Shutting down servers..."
kill $FLASK_PID 2>/dev/null
kill $HTTP_PID 2>/dev/null
log "Finished"
EOFKIOSK

    chmod +x "$KIOSK_SCRIPT"
    print_success "Optimized kiosk script created at $KIOSK_SCRIPT"
    print_info "Features included:"
    echo "  • HDMI-CEC: Auto turn on TV and switch input"
    echo "  • Splash screen display (kabba image)"
    echo "  • GPU hardware acceleration enabled"
    echo "  • Zero-copy rendering for better performance"
    echo "  • 1080p resolution forced via xrandr"
    echo "  • Process monitoring and auto-restart"
    echo "  • Clean desktop (hidden panels and cursor)"
}

###############################################################################
# Step 10: Configure Autostart
###############################################################################
setup_autostart() {
    print_header "STEP 10: Configuring Autostart"

    AUTOSTART_DIR="$PI_HOME/.config/autostart"
    KIOSK_DESKTOP="$AUTOSTART_DIR/kiosk.desktop"

    print_info "Creating autostart directory..."
    mkdir -p "$AUTOSTART_DIR"

    print_info "Creating kiosk.desktop file..."

    cat > "$KIOSK_DESKTOP" << EOFDESKTOP
[Desktop Entry]
Type=Application
Exec=/home/pi/kiosk_run.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Kiosk Script
EOFDESKTOP

    print_success "kiosk.desktop created at $KIOSK_DESKTOP"
    print_info "Kiosk will auto-start on boot"
}

###############################################################################
# Step 11: Configure Display Settings
###############################################################################
configure_display() {
    print_header "STEP 11: Configuring Display Settings"

    # Disable screen blanking in lightdm
    print_info "Configuring lightdm..."
    sudo bash -c 'cat > /etc/lightdm/lightdm.conf.d/01_my.conf' << EOFLIGHTDM
[Seat:*]
xserver-command=X -s 0 -dpms
EOFLIGHTDM

    print_success "Display settings configured"
}

###############################################################################
# Step 12: Create Environment File
###############################################################################
create_env_file() {
    print_header "STEP 12: Creating Environment Configuration"

    ENV_FILE="$PROJECT_DIR/.env"

    print_info "Creating .env file..."

    cat > "$ENV_FILE" << EOFENV
# Flask Configuration
FLASK_APP=server.py
FLASK_ENV=production
SECRET_KEY=super-secret-key-change-in-production

# Server Configuration
HOST=0.0.0.0
PORT=5000
DEBUG=False

# Application Configuration
PROJECT_DIR=$PROJECT_DIR
VENV_DIR=$VENV_DIR
EOFENV

    print_success "Environment file created"
}

###############################################################################
# Step 13: Final Configuration
###############################################################################
final_configuration() {
    print_header "STEP 13: Final Configuration"

    # Create config backup directory
    BACKUP_DIR="$PROJECT_DIR/config_backup"
    mkdir -p "$BACKUP_DIR"
    print_info "Created backup directory: $BACKUP_DIR"

    # Set timezone (change as needed)
    print_info "Setting timezone to Asia/Kolkata..."
    sudo timedatectl set-timezone Asia/Kolkata

    print_success "Final configuration complete"
}

###############################################################################
# Main Installation Flow
###############################################################################
main() {
    # Parse command-line arguments
    parse_arguments "$@"

    print_header "RASPBERRY PI PRAYER TIMETABLE SETUP"
    echo "This script will set up everything needed for the prayer timetable kiosk" | tee -a "$LOG_FILE"
    echo ""

    # Show setup mode
    if [ -n "$GIT_REPO_URL" ]; then
        print_info "Setup Mode: Clone from Git repository"
        print_info "Repository: $GIT_REPO_URL"
    else
        print_info "Setup Mode: Copy from local directory"
    fi
    echo ""

    # Check if running as correct user
    if [ "$(whoami)" != "$PI_USER" ]; then
        print_warning "This script should be run as user '$PI_USER'"
        print_info "Switching to user $PI_USER..."
        sudo -u $PI_USER bash "$0" "$@"
        exit $?
    fi

    setup_system
    install_dependencies
    setup_directories
    copy_project_files
    setup_python_venv
    setup_wifi_profiles
# This should be commented     setup_pi_hotspot
    configure_boot_config
    setup_rtc_module
    create_kiosk_script
    setup_autostart
#   configure_display
#   create_env_file
#    final_configuration

    print_header "SETUP COMPLETE!"
    print_success "Prayer Timetable setup completed successfully!"
    echo ""
    print_info "Summary:"
    echo "  • Project directory: $PROJECT_DIR"
    echo "  • Kiosk script: $PI_HOME/kiosk_run.sh"
    echo "  • Autostart: $PI_HOME/.config/autostart/kiosk.desktop"
    echo "  • Log file: $PI_HOME/kiosk.log"
    echo "  • Virtual environment: $VENV_DIR"
    echo "  • WiFi switcher: /usr/local/bin/wifi-switcher.sh"
    echo "  • WiFi log: /var/log/wifi-switcher.log"
    echo ""
    print_info "Performance Optimizations:"
    echo "  • Display: 1080p @ 60Hz (forced, not 4K)"
    echo "  • CPU: Overclocked to 1800MHz (+20%)"
    echo "  • GPU: Overclocked to 600MHz (+20%)"
    echo "  • GPU Memory: 256MB allocated"
    echo "  • Browser: GPU hardware acceleration enabled"
    echo "  • Config backup: /boot/firmware/config.txt.backup"
    echo ""
    print_info "RTC Module (DS3231):"
    echo "  • Offline time keeping without internet"
    echo "  • I2C Address: 0x68"
    echo "  • Battery: CR2032 (3-5 year lifespan)"
    echo "  • Accuracy: ±2ppm (~1 minute/year drift)"
    echo "  • Wiring: VCC→Pin1, SDA→Pin3, SCL→Pin5, GND→Pin9"
    echo ""
    print_info "TV Control (HDMI-CEC):"
    echo "  • Auto turn on TV when Pi boots"
    echo "  • Auto switch to Pi's HDMI input"
    echo "  • No manual remote control needed"
    echo ""
    print_warning "REMINDER: Enable CEC in your TV settings!"
    echo "  Go to: TV Settings → HDMI/External Inputs → CEC"
    echo "  Enable: 'HDMI Device Control' or similar option"
    echo "  (Samsung: Anynet+, LG: SimpLink, Sony: Bravia Sync)"
    echo ""
    print_info "WiFi Configuration:"
    echo "  • Primary hotspot: salah-e-waqt (open)"
    echo "  • Fallback hotspot: my-hotspot (open)"
    echo "  • Auto-switch: Every 2 minutes (systemd timer)"
    echo "  • Current WiFi: $(iwgetid -r || echo 'Not connected')"
    echo "  • Current IP: $(hostname -I | awk '{print $1}' || echo 'No IP')"
    echo ""
    print_info "Pi Hotspot (Access Point):"
    echo "  • SSID: my-hotspot (open - no password)"
    echo "  • Pi IP Address: 192.168.50.1"
    echo "  • Admin Panel: http://192.168.50.1:5000/home"
    echo "  • Connect mobile to 'my-hotspot' to update remotely"
    echo ""
    print_info "Useful commands:"
    echo "  • View kiosk logs: tail -f $PI_HOME/kiosk.log"
    echo "  • Stop kiosk: pkill -f chromium-browser"
    echo "  • WiFi status: iwgetid -r"
    echo "  • WiFi logs: tail -f /var/log/wifi-switcher.log"
    echo "  • WiFi timer status: sudo systemctl status wifi-switcher.timer"
    echo "  • Hotspot status: sudo systemctl status hostapd"
    echo "  • Restart hotspot: sudo systemctl restart hostapd dnsmasq"
    echo ""
    print_info "Performance check commands:"
    echo "  • Verify performance: $PROJECT_DIR/verify_performance.sh"
    echo "  • Check resolution: DISPLAY=:0 xrandr | grep '\*'"
    echo "  • Check CPU speed: vcgencmd measure_clock arm"
    echo "  • Check GPU speed: vcgencmd measure_clock core"
    echo "  • Check temperature: vcgencmd measure_temp"
    echo "  • View full guide: cat $PROJECT_DIR/PERFORMANCE_OPTIMIZATION_GUIDE.md"
    echo ""
    print_info "TV Control commands (HDMI-CEC):"
    echo "  • Turn on TV: echo 'on 0' | cec-client -s -d 1"
    echo "  • Turn off TV: echo 'standby 0' | cec-client -s -d 1"
    echo "  • Switch to Pi input: echo 'as' | cec-client -s -d 1"
    echo "  • Scan CEC devices: echo 'scan' | cec-client -s -d 1"
    echo ""
    print_info "RTC commands:"
    echo "  • Read RTC time: sudo hwclock -r"
    echo "  • Sync system to RTC: sudo hwclock -s"
    echo "  • Sync RTC from system: sudo hwclock -w"
    echo "  • Check RTC detection: sudo i2cdetect -y 1"
    echo "  • View RTC driver: dmesg | grep rtc"
    echo ""
    print_warning "IMPORTANT: Reboot the Raspberry Pi to start kiosk mode"
    echo ""
    read -p "Would you like to reboot now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Rebooting in 5 seconds..."
        sleep 5
        sudo reboot
    else
        print_info "Please reboot manually when ready: sudo reboot"
    fi
}

# Run main function with all command-line arguments
main "$@"
