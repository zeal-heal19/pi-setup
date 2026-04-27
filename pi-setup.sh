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
GIT_BRANCH=""  # optional branch to clone, defaults to repo default branch
PI_VERSION=""  # 3 or 4 — set via --pi-version or asked interactively

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
  --git-branch BRANCH   Git branch to clone (defaults to repo default branch)
  --pi-version VERSION  Raspberry Pi version: 3 or 4 (asked interactively if not provided)
  --help                Show this help message

Examples:
  # Setup for Pi 3B (asked interactively)
  ./pi-setup.sh

  # Setup for Pi 4 with token (non-interactive)
  ./pi-setup.sh --pi-version 4 --repo-url https://github.com/username/alt-prayer-timetable.git --git-token ghp_xxxxx

  # Setup for Pi 3B with token (non-interactive)
  ./pi-setup.sh --pi-version 3 --repo-url https://github.com/username/alt-prayer-timetable.git --git-token ghp_xxxxx

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
            --git-branch)
                GIT_BRANCH="$2"
                shift 2
                ;;
            --pi-version)
                PI_VERSION="$2"
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
    echo "##STAGE:update##"
    print_header "STEP 1: Updating System Packages"

    print_info "Updating package lists..."
    sudo apt update 2>&1 | tee -a "$LOG_FILE"

    print_info "Upgrading installed packages..."
    sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y \
        -o Dpkg::Options::="--force-confold" \
        -o Dpkg::Options::="--force-confdef" 2>&1 | tee -a "$LOG_FILE"

    print_success "System updated successfully"
}

###############################################################################
# Step 2: Install Required Packages
###############################################################################
install_dependencies() {
    echo "##STAGE:packages##"
    print_header "STEP 2: Installing Required Packages"

    print_info "Updating package lists..."
    sudo apt update 2>&1 | tee -a "$LOG_FILE"

    # Fix any broken dpkg/apt state before installing
    print_info "Fixing any broken package state..."
    sudo DEBIAN_FRONTEND=noninteractive dpkg \
        --force-confold --force-confdef \
        --configure -a 2>&1 || true
    sudo DEBIAN_FRONTEND=noninteractive apt --fix-broken install -y \
        -o Dpkg::Options::="--force-confold" \
        -o Dpkg::Options::="--force-confdef" 2>&1 || true

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
        xorg \
        lightdm \
        network-manager \
        wireless-tools \
        git \
        curl \
        vim \
        xdotool \
        matchbox-window-manager \
        xautomation \
        openbox \
        cec-utils 2>&1 | tee -a "$LOG_FILE"

    # Fix again after install in case anything broke mid-way
    sudo DEBIAN_FRONTEND=noninteractive dpkg --configure -a 2>&1 || true
    sudo DEBIAN_FRONTEND=noninteractive apt --fix-broken install -y \
        -o Dpkg::Options::="--force-confold" \
        -o Dpkg::Options::="--force-confdef" 2>&1 || true

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
    echo "##STAGE:clone##"
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
        CLONE_CMD="git clone"
        if [ -n "$GIT_BRANCH" ]; then
            CLONE_CMD="git clone --branch $GIT_BRANCH"
            print_info "Cloning branch: $GIT_BRANCH"
        fi
        $CLONE_CMD "$CLONE_URL" "$PROJECT_DIR" 2>&1 | tee -a "$LOG_FILE"
        if [ ${PIPESTATUS[0]} -eq 0 ]; then
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
    echo "##STAGE:python##"
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
    echo "##STAGE:network##"
    print_header "STEP 6: Setting Up WiFi Auto-Switcher"

    # Ensure NetworkManager is running before using nmcli
    print_info "Ensuring NetworkManager is running..."
    sudo systemctl enable NetworkManager 2>/dev/null || true
    sudo systemctl start NetworkManager 2>/dev/null || true
    sleep 3

    print_info "Creating WiFi profiles for open hotspots..."

    # Create profile for primary open hotspot
    print_info "Creating profile: salah-e-waqt-android (open hotspot)"
    sudo nmcli connection add \
        type wifi \
        con-name "salah-e-waqt-android" \
        ssid "salah-e-waqt" \
        connection.autoconnect yes \
        connection.autoconnect-priority 100 2>/dev/null || true

    # Create backup profile for same hotspot
    print_info "Creating profile: salah-e-waqt-iphone (open hotspot)"
    sudo nmcli connection add \
        type wifi \
        con-name "salah-e-waqt-iphone" \
        ssid "salah-e-waqt" \
        connection.autoconnect yes \
        connection.autoconnect-priority 100 2>/dev/null || true


    print_success "WiFi profiles created"

    # Create WiFi switcher script
    WIFI_SCRIPT="/usr/local/bin/wifi-switcher.sh"
    print_info "Creating WiFi auto-switcher script..."

    sudo tee "$WIFI_SCRIPT" > /dev/null << 'EOFWIFI'
#!/bin/bash
###############################################################################
# WiFi Auto-Switcher for Prayer Timetable
#
# Default mode : Pi broadcasts my-hotspot (mobile can connect for admin)
# When salah-e-waqt found : stop hotspot, connect to salah-e-waqt (internet)
# When salah-e-waqt lost  : disconnect, resume broadcasting my-hotspot
###############################################################################

TARGET_SSID="salah-e-waqt"
HOTSPOT_CON="my-hotspot"
LOG_FILE="/var/log/wifi-switcher.log"

log() { echo "$(date): $1" >> "$LOG_FILE"; }

# Check current state
HOTSPOT_ACTIVE=$(nmcli connection show --active 2>/dev/null | grep "$HOTSPOT_CON")
CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2)

# Scan for mosque hotspot
nmcli device wifi rescan 2>/dev/null
sleep 3
TARGET_AVAILABLE=$(nmcli -t -f SSID device wifi list 2>/dev/null | grep -x "$TARGET_SSID")

if [ -n "$TARGET_AVAILABLE" ]; then
    # salah-e-waqt is in range
    if [ "$CURRENT_SSID" != "$TARGET_SSID" ]; then
        log "salah-e-waqt found — stopping hotspot, switching to client mode"

        # Stop hotspot if running
        nmcli connection down "$HOTSPOT_CON" 2>/dev/null || true
        sleep 2

        # Try connecting to salah-e-waqt
        nmcli connection up "salah-e-waqt-android" 2>/dev/null || true
        sleep 5

        NEW_SSID=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2)
        if [ "$NEW_SSID" != "$TARGET_SSID" ]; then
            log "Android profile failed, trying iPhone profile"
            nmcli connection up "salah-e-waqt-iphone" 2>/dev/null || true
            sleep 5
        fi

        FINAL_SSID=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2)
        FINAL_IP=$(hostname -I | awk '{print $1}')
        if [ "$FINAL_SSID" = "$TARGET_SSID" ]; then
            log "✓ Connected to $TARGET_SSID (IP: $FINAL_IP)"
        else
            log "✗ Failed to connect to $TARGET_SSID — resuming hotspot"
            nmcli connection up "$HOTSPOT_CON" 2>/dev/null || true
        fi
    fi
else
    # salah-e-waqt not in range — ensure hotspot is broadcasting
    if [ -z "$HOTSPOT_ACTIVE" ]; then
        log "salah-e-waqt not found — broadcasting $HOTSPOT_CON"
        nmcli connection down "salah-e-waqt-android" 2>/dev/null || true
        nmcli connection down "salah-e-waqt-iphone" 2>/dev/null || true
        sleep 2
        nmcli connection up "$HOTSPOT_CON" 2>/dev/null || true
        sleep 3
        HOTSPOT_IP=$(nmcli -t -f IP4.ADDRESS connection show "$HOTSPOT_CON" 2>/dev/null | head -1 | cut -d: -f2 | cut -d/ -f1)
        log "✓ Hotspot broadcasting — connect to '$HOTSPOT_CON' → http://${HOTSPOT_IP}:5000/home"
    fi
fi

# Keep log file at reasonable size (last 1000 lines)
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
After=network.target NetworkManager.service
Requires=NetworkManager.service

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
# Step 7: Setup Raspberry Pi as WiFi Hotspot (NetworkManager)
# Default mode: Pi broadcasts my-hotspot
# When salah-e-waqt is found: switches to client mode automatically
# When salah-e-waqt lost: switches back to broadcasting my-hotspot
###############################################################################
setup_pi_hotspot() {
    print_header "STEP 7: Setting Up Raspberry Pi as WiFi Hotspot"

    HOTSPOT_SSID="my-hotspot"
    HOTSPOT_PASSWORD="admin@123"

    # Remove old hotspot profile if exists
    sudo nmcli connection delete "$HOTSPOT_SSID" 2>/dev/null || true

    print_info "Creating hotspot profile via NetworkManager..."
    sudo nmcli connection add \
        type wifi \
        ifname wlan0 \
        con-name "$HOTSPOT_SSID" \
        ssid "$HOTSPOT_SSID" \
        mode ap \
        ipv4.method shared \
        wifi-sec.key-mgmt wpa-psk \
        wifi-sec.psk "$HOTSPOT_PASSWORD" \
        connection.autoconnect no 2>/dev/null || true

    print_success "Hotspot profile created"
    print_info "Hotspot details:"
    echo "  • SSID: $HOTSPOT_SSID"
    echo "  • Password: $HOTSPOT_PASSWORD"
    echo "  • Pi IP: 10.42.0.1 (assigned by NetworkManager)"
    echo "  • Admin panel: http://10.42.0.1:5000/home"
    echo "  • Mode: Broadcasts by default, switches to salah-e-waqt when found"
}

###############################################################################
# Disable USB Ports (security — prevents keyboard, mouse, pen drives)
###############################################################################
disable_usb_ports() {
    echo "##STAGE:security##"
    print_header "Disabling USB Ports (Security)"

    # Block USB storage devices (pen drives, hard drives)
    print_info "Blacklisting USB storage modules..."
    sudo tee /etc/modprobe.d/disable-usb-storage.conf > /dev/null << 'EOF'
blacklist usb_storage
blacklist uas
EOF

    # Block USB keyboard and mouse
    print_info "Blacklisting USB HID modules (keyboard/mouse)..."
    sudo tee /etc/modprobe.d/disable-usb-hid.conf > /dev/null << 'EOF'
blacklist usbhid
EOF

    # Block external USB Bluetooth adapters
    print_info "Blacklisting USB Bluetooth modules..."
    sudo tee /etc/modprobe.d/disable-usb-bt.conf > /dev/null << 'EOF'
blacklist btusb
EOF

    # Update initramfs so blacklist applies on boot
    print_info "Updating initramfs..."
    sudo update-initramfs -u 2>/dev/null || true

    print_success "USB ports disabled"
    echo "  • USB storage (pen drives, hard drives) — BLOCKED"
    echo "  • USB keyboard and mouse — BLOCKED"
    echo "  • USB Bluetooth adapters — BLOCKED"
    echo "  • WiFi, Ethernet, SSH — still working (not USB on Pi 4)"
    echo "  • USB-C power — still working (power only, no data)"
}

###############################################################################
# Disable Bluetooth (not used by app, frees RAM + prevents WiFi interference)
###############################################################################
disable_bluetooth() {
    print_header "Disabling Bluetooth"

    print_info "Disabling bluetooth systemd services..."
    sudo systemctl disable bluetooth 2>/dev/null || true
    sudo systemctl disable hciuart 2>/dev/null || true
    sudo systemctl stop bluetooth 2>/dev/null || true

    print_success "Bluetooth disabled"
    echo "  • bluetoothd daemon stopped and disabled"
    echo "  • hciuart disabled"
    echo "  • dtoverlay=disable-bt will be added to config.txt"
    echo "  • WiFi interference on 2.4GHz eliminated"
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

    # Only add settings if not already present (prevent duplicates on re-run)
    if grep -q "Added by pi-setup.sh" "$CONFIG_FILE"; then
        print_warning "Boot config already modified, skipping to prevent duplicates"
        return
    fi

    if [ "$PI_VERSION" = "3" ]; then
        print_info "Applying Raspberry Pi 3B settings..."
        sudo tee -a "$CONFIG_FILE" > /dev/null << 'EOFCONFIG'

# ========================================
# Performance Optimizations (Added by pi-setup.sh) - Pi 3B
# ========================================

# DISPLAY SETTINGS - Force 1080p
hdmi_force_hotplug=1
hdmi_drive=2
config_hdmi_boost=7
max_framebuffer_width=1920
max_framebuffer_height=1080

# PERFORMANCE - Pi 3B safe overclock
arm_freq=1350
gpu_freq=400
gpu_mem=256
over_voltage=2

# RTC MODULE (DS3231) - Enable I2C RTC for offline time keeping
dtoverlay=i2c-rtc,ds3231

# BLUETOOTH - Disable completely (not used, frees RAM + prevents WiFi interference)
dtoverlay=disable-bt
EOFCONFIG

        print_success "Boot config optimized for Pi 3B"
        print_info "Settings applied:"
        echo "  • Resolution: 1080p @ 60Hz (forced)"
        echo "  • CPU: 1350MHz (safe overclock)"
        echo "  • GPU: 400MHz"
        echo "  • GPU Memory: 256MB"
        echo "  • RTC: DS3231 module enabled (I2C)"
        echo "  • Bluetooth: Disabled (frees RAM + prevents WiFi interference)"

    else
        print_info "Applying Raspberry Pi 4 settings..."
        sudo tee -a "$CONFIG_FILE" > /dev/null << 'EOFCONFIG'

# ========================================
# Performance Optimizations (Added by pi-setup.sh) - Pi 4
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

# BLUETOOTH - Disable completely (not used, frees RAM + prevents WiFi interference)
dtoverlay=disable-bt
EOFCONFIG

        print_success "Boot config optimized for Pi 4"
        print_info "Settings applied:"
        echo "  • Resolution: 1080p @ 60Hz (forced)"
        echo "  • CPU: 1800MHz (overclocked from 1500MHz)"
        echo "  • GPU: 600MHz (overclocked from 500MHz)"
        echo "  • GPU Memory: 256MB"
        echo "  • Fan: Activates at 80°C"
        echo "  • RTC: DS3231 module enabled (I2C)"
        echo "  • Bluetooth: Disabled (frees RAM + prevents WiFi interference)"
    fi
}

###############################################################################
# Step 8b: Setup RTC Module (DS3231)
###############################################################################
setup_rtc_module() {
    echo "##STAGE:rtc##"
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
    echo "##STAGE:kiosk##"
    print_header "STEP 9: Creating Optimized Kiosk Run Script"

    KIOSK_SCRIPT="$PI_HOME/kiosk_run.sh"

    print_info "Creating kiosk script at $KIOSK_SCRIPT..."

    # Copy kiosk_run.sh directly from the cloned repo
    if [ -f "$PROJECT_DIR/kiosk_run.sh" ]; then
        print_info "Copying kiosk_run.sh from project repo..."
        cp "$PROJECT_DIR/kiosk_run.sh" "$KIOSK_SCRIPT"
        chmod +x "$KIOSK_SCRIPT"
        print_success "kiosk_run.sh copied from repo to $KIOSK_SCRIPT"
    else
        print_warning "kiosk_run.sh not found in repo, writing built-in template..."
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
AUTHORIZED_DISPLAY_FILE="$PROJECT_DIR/config/authorized_display.txt"

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
    echo 'on 0' | cec-client -s -d 1 2>/dev/null
    sleep 2
    echo 'as' | cec-client -s -d 1 2>/dev/null
    sleep 2
    log "HDMI-CEC: TV powered on and switched to Pi HDMI input"
else
    log "WARNING: cec-client not installed. TV control disabled."
fi

export DISPLAY=:0

log "Waiting for X server..."
while ! xset q &>/dev/null; do sleep 1; done
log "X server ready"

unclutter -idle 0.1 -root &

# Kill any existing Chromium processes
pkill -f chromium-browser 2>/dev/null || true
pkill -f chromium 2>/dev/null || true
sleep 1

# Remove Chromium lock files to prevent "profile in use" error
CHROMIUM_PROFILE="$HOME/.config/chromium"
rm -f "$CHROMIUM_PROFILE/SingletonLock" 2>/dev/null || true
rm -f "$CHROMIUM_PROFILE/SingletonCookie" 2>/dev/null || true
rm -f "$CHROMIUM_PROFILE/SingletonSocket" 2>/dev/null || true
rm -f "$CHROMIUM_PROFILE/Default/Preferences.lock" 2>/dev/null || true

killall lxpanel 2>/dev/null || true
killall lxqt-panel 2>/dev/null || true
killall pcmanfm 2>/dev/null || true
xsetroot -solid black

killall notification-daemon 2>/dev/null || true
killall xfce4-notifyd 2>/dev/null || true
killall dunst 2>/dev/null || true
killall lxqt-notificationd 2>/dev/null || true
killall nm-applet 2>/dev/null || true

# Kill screen lockers (light-locker installed with lightdm causes login prompt)
killall light-locker 2>/dev/null || true
killall xscreensaver 2>/dev/null || true
killall gnome-screensaver 2>/dev/null || true

# Disable keyring to prevent password popup
killall gnome-keyring-daemon 2>/dev/null || true
rm -f "$HOME/.local/share/keyrings/login.keyring" 2>/dev/null || true

sleep 0.5

if command -v feh &> /dev/null && [ -f "$SPLASH_IMAGE" ]; then
    feh --fullscreen --hide-pointer --borderless --auto-zoom "$SPLASH_IMAGE" &
    SPLASH_PID=$!
fi

sleep 4

cd "$PROJECT_DIR"
if [ "$ENABLE_LOGGING" = "true" ]; then
    $HOME/myenv/bin/python -m http.server 8000 --directory "$PROJECT_DIR" >> "$LOGFILE" 2>&1 &
else
    $HOME/myenv/bin/python -m http.server 8000 --directory "$PROJECT_DIR" > /dev/null 2>&1 &
fi
HTTP_PID=$!
log "HTTP server started (PID: $HTTP_PID)"

sleep 2

if [ "$ENABLE_LOGGING" = "true" ]; then
    $HOME/myenv/bin/python "$PROJECT_DIR/server.py" >> "$LOGFILE" 2>&1 &
else
    $HOME/myenv/bin/python "$PROJECT_DIR/server.py" > /dev/null 2>&1 &
fi
FLASK_PID=$!
log "Flask server started (PID: $FLASK_PID)"

for i in {1..30}; do
    if curl -s http://localhost:5000 > /dev/null 2>&1; then break; fi
    sleep 2
done

HDMI_OUTPUT=$(xrandr 2>/dev/null | grep " connected" | head -1 | awk '{print $1}')
if [ -n "$HDMI_OUTPUT" ]; then
    xrandr --output "$HDMI_OUTPUT" --mode 1920x1080 --fb 1920x1080 --panning 0x0 2>/dev/null || \
    xrandr --output "$HDMI_OUTPUT" --auto --fb 1920x1080 --panning 0x0 2>/dev/null || true
fi
sleep 2

xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true
xset s noblank 2>/dev/null || true

if [ "$ENABLE_LOGGING" = "true" ]; then
    CHROMIUM_LOG="/home/pi/chromium.log"
else
    CHROMIUM_LOG="/dev/null"
fi

openbox --sm-disable &
sleep 1

CHROMIUM_BIN=$(command -v chromium || command -v chromium-browser || echo "/usr/bin/chromium")
$CHROMIUM_BIN \
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
  --disable-features=TranslateUI,IsolateOrigins,site-per-process \
  --password-store=basic \
  --use-mock-keychain \
  --enable-gpu-rasterization \
  --enable-zero-copy \
  --enable-native-gpu-memory-buffers \
  --ignore-gpu-blocklist \
  --disable-smooth-scrolling \
  --disable-low-res-tiling \
  --enable-accelerated-2d-canvas \
  --disable-site-isolation-trials \
  --disk-cache-size=1 \
  --disable-hang-monitor \
  --autoplay-policy=no-user-gesture-required \
  http://localhost:8000 >> "$CHROMIUM_LOG" 2>&1 &

CHROMIUM_PID=$!
log "Chromium launched (PID: $CHROMIUM_PID)"

# ========================================
# DISPLAY AUTHORIZATION CHECK (runs after 5 minutes in background)
# ========================================
(
    sleep 300  # 5 minute grace period — app runs freely during this time
    log "Running display authorization check..."

    EDID_PATH=$(ls /sys/class/drm/card*-HDMI-A-1/edid 2>/dev/null | head -1)
    EDID_SIZE=$(wc -c < "$EDID_PATH" 2>/dev/null || echo 0)

    AUTHORIZED=false

    if [ "$EDID_SIZE" -gt 0 ] && [ -f "$AUTHORIZED_DISPLAY_FILE" ]; then
        CURRENT_HASH=$(md5sum "$EDID_PATH" | awk '{print $1}')
        AUTHORIZED_HASH=$(cat "$AUTHORIZED_DISPLAY_FILE" | tr -d '[:space:]')
        if [ "$CURRENT_HASH" = "$AUTHORIZED_HASH" ]; then
            AUTHORIZED=true
        fi
    fi

    if [ "$AUTHORIZED" = true ]; then
        log "Display authorized ✅ — kiosk continues"
    else
        log "ERROR: Unauthorized display detected after 5 mins. Blocking app."
        kill $CHROMIUM_PID 2>/dev/null
        kill $FLASK_PID 2>/dev/null
        kill $HTTP_PID 2>/dev/null
        sleep 2
        while true; do
            $CHROMIUM_BIN \
              --kiosk \
              --noerrdialogs \
              --disable-session-crashed-bubble \
              --disable-infobars \
              --start-fullscreen \
              "file://$PROJECT_DIR/unauthorized.html" > /dev/null 2>&1 &
            UNAUTH_PID=$!
            log "Unauthorized page displayed (PID: $UNAUTH_PID)"
            wait $UNAUTH_PID
            sleep 2
        done
    fi
) &

sleep 10
if [ ! -z "$SPLASH_PID" ]; then
    kill $SPLASH_PID 2>/dev/null
fi

while kill -0 $CHROMIUM_PID 2>/dev/null; do
    sleep 60
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
kill $FLASK_PID 2>/dev/null
kill $HTTP_PID 2>/dev/null
log "Keeping session alive — waiting for background processes..."

# Never exit — if script exits, X session ends and lightdm shows login screen
while true; do
    sleep 60
done
EOFKIOSK
        chmod +x "$KIOSK_SCRIPT"
    fi

    print_success "Kiosk script ready at $KIOSK_SCRIPT"
    print_info "Features included:"
    echo "  • HDMI-CEC: Auto turn on TV and switch input"
    echo "  • Splash screen display"
    echo "  • Chromium lock file cleanup on launch"
    echo "  • Keyring disabled (no password popup)"
    echo "  • GPU hardware acceleration enabled"
    echo "  • 1080p resolution forced via xrandr"
    echo "  • Display authorization check after 5 minutes"
    echo "  • Process monitoring and auto-restart"
}

###############################################################################
# Step 10: Configure Autostart (lightdm auto-login + xsession)
# Works on both Pi OS Lite and Pi OS Desktop
###############################################################################
setup_autostart() {
    print_header "STEP 10: Configuring Autostart"

    # Configure lightdm for auto-login and no screen blanking
    print_info "Configuring lightdm auto-login..."
    sudo mkdir -p /etc/lightdm/lightdm.conf.d
    sudo tee /etc/lightdm/lightdm.conf.d/01_kiosk.conf > /dev/null << EOFLIGHTDM
[Seat:*]
autologin-user=$PI_USER
autologin-user-timeout=0
autologin-session=kiosk
xserver-command=X -s 0 -dpms
greeter-setup-script=/bin/true
display-setup-script=/bin/true
EOFLIGHTDM

    # Disable light-locker (screen locker that ships with lightdm — causes login prompt)
    print_info "Disabling light-locker screen locker..."
    sudo systemctl disable light-locker 2>/dev/null || true
    sudo mkdir -p /etc/xdg/autostart
    sudo tee /etc/xdg/autostart/light-locker.desktop > /dev/null << 'EOFLOCKER'
[Desktop Entry]
Hidden=true
EOFLOCKER
    print_success "light-locker disabled"
    print_success "lightdm configured for auto-login"

    # Create a kiosk session entry so lightdm knows what to launch
    print_info "Creating kiosk session for lightdm..."
    sudo mkdir -p /usr/share/xsessions
    sudo tee /usr/share/xsessions/kiosk.desktop > /dev/null << EOFSESSION
[Desktop Entry]
Name=Kiosk
Exec=$PI_HOME/kiosk_run.sh
Type=Application
EOFSESSION
    print_success "kiosk.desktop session created"

    # Create ~/.xsession as fallback
    print_info "Creating ~/.xsession fallback..."
    cat > "$PI_HOME/.xsession" << EOFXSESSION
#!/bin/bash
exec $PI_HOME/kiosk_run.sh
EOFXSESSION
    chmod +x "$PI_HOME/.xsession"
    print_success "~/.xsession created — kiosk launches directly on login"

    # Enable lightdm to start on boot
    print_info "Enabling lightdm service..."
    sudo systemctl enable lightdm
    print_success "lightdm enabled"

    # Set graphical target so lightdm starts on boot (Pi OS Lite defaults to multi-user.target)
    print_info "Setting default boot target to graphical..."
    sudo systemctl set-default graphical.target
    print_success "Boot target set to graphical.target"

    # Force 1920x1080 virtual framebuffer — prevents 4K TV causing half-screen display
    print_info "Creating Xorg monitor config (forces 1920x1080 virtual framebuffer)..."
    sudo mkdir -p /etc/X11/xorg.conf.d
    sudo tee /etc/X11/xorg.conf.d/10-monitor.conf > /dev/null << 'EOFXORG'
Section "Screen"
    Identifier "Screen0"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "1920x1080"
        Virtual 1920 1080
    EndSubSection
EndSection
EOFXORG
    print_success "Xorg monitor config created"

    print_info "Autostart configured:"
    echo "  • Boot → lightdm auto-login as $PI_USER"
    echo "  • Login → ~/.xsession → kiosk_run.sh"
    echo "  • Works on both Pi OS Lite and Pi OS Desktop"
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
# Step 4a: Cleanup non-required files from cloned project
###############################################################################
cleanup_project_files() {
    echo "##STAGE:cleanup##"
    print_header "STEP 4a: Cleaning Up Non-Required Files"

    print_info "Removing dev/setup files not needed on Pi..."

    # Setup scripts (handled by pi-setup.sh, not needed in app)
    rm -f "$PROJECT_DIR/pi-setup.sh"
    rm -f "$PROJECT_DIR/kiosk.desktop"
    rm -f "$PROJECT_DIR/wifi-switcher-setup.sh"
    rm -f "$PROJECT_DIR/application-serve.py"
    rm -f "$PROJECT_DIR/verify_performance.sh"

    # Documentation
    rm -f "$PROJECT_DIR/PERFORMANCE_OPTIMIZATION_GUIDE.md"
    rm -f "$PROJECT_DIR/PI_SETUP_CHANGES.md"
    rm -f "$PROJECT_DIR/QUICK_REFERENCE.md"

    # Testing files
    rm -f "$PROJECT_DIR/jest.config.js"
    rm -f "$PROJECT_DIR/package.json"
    rm -f "$PROJECT_DIR/package-lock.json"
    rm -rf "$PROJECT_DIR/tests"

    # Dev environment
    rm -rf "$PROJECT_DIR/.vscode"
    rm -rf "$PROJECT_DIR/__pycache__"

    # Backup files
    rm -f "$PROJECT_DIR/config/hadith_backup.json"

    print_success "Cleanup complete — only required app files kept"
}

###############################################################################
# Step 4b: Configure Mosque Details
###############################################################################
setup_mosque_config() {
    echo "##STAGE:mosque##"
    print_header "STEP 4b: Mosque Configuration"

    MOSQUE_DETAIL_FILE="$PROJECT_DIR/config/mosque-detail.json"
    PRAYER_CONFIG_FILE="$PROJECT_DIR/config/prayer-times.config.json"

    echo "========================================="
    echo " Enter Mosque Details"
    echo " (These will be saved to the config files)"
    echo "========================================="
    echo ""

    read -p " Mosque Name: " MOSQUE_NAME
    read -p " Latitude (e.g. 21.183780): " MOSQUE_LAT
    read -p " Longitude (e.g. 79.066567): " MOSQUE_LON
    read -p " Mosque Code (e.g. 002): " MOSQUE_CODE
    echo ""
    echo "-----------------------------------------"
    echo " Admin Login Details"
    echo "-----------------------------------------"
    read -p " Admin Username: " ADMIN_USERNAME
    read -s -p " Admin Password: " ADMIN_PASSWORD
    echo ""
    echo ""

    if [ -z "$MOSQUE_NAME" ] || [ -z "$MOSQUE_LAT" ] || [ -z "$MOSQUE_LON" ] || [ -z "$MOSQUE_CODE" ]; then
        print_warning "One or more mosque fields empty — skipping mosque config update"
        return
    fi

    print_info "Updating mosque-detail.json..."
    $HOME/myenv/bin/python3 << EOFPY
import json, sys

path = "$MOSQUE_DETAIL_FILE"
try:
    with open(path, 'r') as f:
        data = json.load(f)
except:
    data = {}

data['mosque_name'] = "$MOSQUE_NAME"
data['latitude'] = float("$MOSQUE_LAT")
data['longitude'] = float("$MOSQUE_LON")
data['mosque_code'] = "$MOSQUE_CODE"

with open(path, 'w') as f:
    json.dump(data, f, indent=2)
print("mosque-detail.json updated")
EOFPY

    print_info "Updating prayer-times.config.json..."
    $HOME/myenv/bin/python3 << EOFPY
import json

path = "$PRAYER_CONFIG_FILE"
try:
    with open(path, 'r') as f:
        data = json.load(f)
except:
    data = {}

data['mosque_name'] = "$MOSQUE_NAME"
data['latitude'] = float("$MOSQUE_LAT")
data['longitude'] = float("$MOSQUE_LON")
data['mosque_code'] = "$MOSQUE_CODE"

with open(path, 'w') as f:
    json.dump(data, f, indent=2)
print("prayer-times.config.json updated")
EOFPY

    if [ -n "$ADMIN_USERNAME" ] && [ -n "$ADMIN_PASSWORD" ]; then
        print_info "Updating users.json..."
        $HOME/myenv/bin/python3 << EOFPY
import json

path = "$PROJECT_DIR/users.json"
try:
    with open(path, 'r') as f:
        data = json.load(f)
except:
    data = {}

# Remove old entries and set new admin credentials
data = {"$ADMIN_USERNAME": {"password": "$ADMIN_PASSWORD"}}

with open(path, 'w') as f:
    json.dump(data, f, indent=2)
print("users.json updated")
EOFPY
        print_success "Admin credentials saved!"
    else
        print_warning "Admin username/password empty — users.json not updated"
    fi

    print_success "Mosque configuration saved!"
    echo "  • Name: $MOSQUE_NAME"
    echo "  • Latitude: $MOSQUE_LAT"
    echo "  • Longitude: $MOSQUE_LON"
    echo "  • Code: $MOSQUE_CODE"
    echo "  • Admin Username: $ADMIN_USERNAME"
    echo "  • Admin Password: (hidden)"
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
# Step 12b: TV Auto Shutdown / Startup Schedule
###############################################################################
setup_tv_schedule() {
    echo "##STAGE:tv##"
    print_header "STEP 12b: TV Auto Shutdown / Startup Schedule"

    TV_SCRIPT="/usr/local/bin/tv-control.sh"

    # Create TV control script
    print_info "Creating TV control script..."
    sudo tee "$TV_SCRIPT" > /dev/null << 'EOFTV'
#!/bin/bash
# TV control via HDMI-CEC + X display blanking
export DISPLAY=:0
export XAUTHORITY=/home/pi/.Xauthority

case "$1" in
    off)
        # Turn off TV via HDMI-CEC
        echo 'standby 0' | cec-client -s -d 1 2>/dev/null
        # Also blank X display as fallback
        xset dpms force off 2>/dev/null || true
        echo "[$(date)] TV turned OFF"
        ;;
    on)
        # Turn on TV via HDMI-CEC
        echo 'on 0' | cec-client -s -d 1 2>/dev/null
        # Switch Pi as active source
        echo 'as' | cec-client -s -d 1 2>/dev/null
        # Unblank X display
        xset dpms force on 2>/dev/null || true
        xset s reset 2>/dev/null || true
        echo "[$(date)] TV turned ON"
        ;;
    *)
        echo "Usage: $0 {on|off}"
        exit 1
        ;;
esac
EOFTV

    sudo chmod +x "$TV_SCRIPT"
    print_success "TV control script created at $TV_SCRIPT"

    # Add cron jobs for daily schedule
    print_info "Setting up daily TV schedule..."
    print_info "  • TV OFF:    11:00 PM every day"
    print_info "  • Pi REBOOT:  4:00 AM every day (TV turns on automatically during boot)"

    # TV off job in pi user crontab
    (crontab -l 2>/dev/null | grep -v "tv-control" || true; \
     echo "0 23 * * * $TV_SCRIPT off > /dev/null 2>&1") | crontab -

    # Reboot job in root crontab (sudo /sbin/reboot fails from pi crontab due to PAM)
    (sudo crontab -l 2>/dev/null | grep -v "pi-daily-reboot" || true; \
     echo "0 4 * * * /sbin/reboot # pi-daily-reboot") | sudo crontab -

    print_success "TV schedule configured!"
    echo "  • Daily OFF:    11:00 PM  (cron: 0 23 * * *)"
    echo "  • Daily REBOOT:  4:00 AM  (cron: 0 4 * * *)"
    echo "  • Manual off: sudo $TV_SCRIPT off"
    echo "  • Manual on:  sudo $TV_SCRIPT on"
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
# Send Setup Completion Email
###############################################################################
send_completion_email() {
    echo "##STAGE:email##"
    print_info "Sending setup completion email to zjahid19@gmail.com..."

    PROJECT_DIR_VAL="$PROJECT_DIR" $HOME/myenv/bin/python3 << 'EOFPY'
import smtplib, os, json, socket
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.image import MIMEImage
from datetime import datetime

project_dir = os.environ.get("PROJECT_DIR_VAL", "/home/pi/my-application")
sender      = "noreply.salahewaqt@gmail.com"
receiver    = "zjahid19@gmail.com"
password    = "sxwydlvfaxxfwwxj"
hostname    = socket.gethostname()
setup_time  = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

mosque_name = "Unknown"
mosque_code = "Unknown"
try:
    with open(project_dir + "/config/mosque-detail.json") as f:
        d = json.load(f)
        mosque_name = d.get("mosque_name", "Unknown")
        mosque_code = d.get("mosque_code", "Unknown")
except:
    pass

# Read pre-resized logo (160px, committed to repo — no Pillow needed)
logo_bytes = None
try:
    with open(project_dir + "/images/logo-email.png", "rb") as f:
        logo_bytes = f.read()
except:
    pass

subject = "✅ Salah-e-Waqt Setup Complete — " + mosque_name

html = """
<!DOCTYPE html>
<html>
<body style="margin:0;padding:0;background-color:#f0f4f0;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f4f0;padding:30px 0;">
<tr><td align="center">
<table width="620" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:10px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.12);">
  <tr>
    <td style="background:linear-gradient(135deg,#1B5E20,#388E3C);padding:35px 30px;text-align:center;">
      <img src="cid:logo" alt="Salah-e-Waqt" style="width:120px;height:auto;margin-bottom:14px;display:block;margin-left:auto;margin-right:auto;" />
      <h1 style="color:#ffffff;margin:0;font-size:22px;font-weight:bold;letter-spacing:0.5px;">Salah-e-Waqt Setup Complete</h1>
      <p style="color:#c8e6c9;margin:8px 0 0;font-size:13px;">MOSQUE_NAME</p>
    </td>
  </tr>
  <tr>
    <td style="padding:28px 30px 10px;color:#333;font-size:15px;line-height:1.6;">
      <p style="margin:0;">Assalamu Alaikum,</p>
      <p style="margin:10px 0 0;color:#555;font-size:14px;">Pi kiosk setup has been completed successfully. Please complete the following manual tasks to finalise the installation.</p>
    </td>
  </tr>
  <tr>
    <td style="padding:15px 30px;">
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#f9fbe7;border-left:4px solid #8bc34a;border-radius:0 6px 6px 0;">
        <tr><td style="padding:16px 20px;">
          <p style="margin:0 0 12px;font-weight:bold;color:#33691e;font-size:13px;text-transform:uppercase;letter-spacing:0.5px;">&#128203; Mosque Details</p>
          <table cellpadding="5" cellspacing="0" style="font-size:13px;color:#444;">
            <tr><td style="color:#777;width:100px;">Name</td><td style="font-weight:bold;color:#222;">MOSQUE_NAME</td></tr>
            <tr><td style="color:#777;">Code</td><td>MOSQUE_CODE</td></tr>
            <tr><td style="color:#777;">Hostname</td><td>HOSTNAME</td></tr>
            <tr><td style="color:#777;">Setup Time</td><td>SETUP_TIME</td></tr>
          </table>
        </td></tr>
      </table>
    </td>
  </tr>
  <tr>
    <td style="padding:20px 30px 8px;">
      <h2 style="margin:0;font-size:15px;color:#1B5E20;border-bottom:2px solid #e8f5e9;padding-bottom:10px;">&#9989; Manual Tasks &#8212; Complete in Order</h2>
    </td>
  </tr>
  <tr>
    <td style="padding:14px 30px;">
      <table width="100%" cellpadding="0" cellspacing="0">
        <tr>
          <td style="width:34px;vertical-align:top;padding-top:2px;">
            <div style="background:#1B5E20;color:#fff;border-radius:50%;width:28px;height:28px;text-align:center;line-height:28px;font-weight:bold;font-size:13px;">1</div>
          </td>
          <td style="padding-left:14px;vertical-align:top;">
            <p style="margin:0 0 6px;font-weight:bold;color:#1B5E20;font-size:14px;">Authorize the Display</p>
            <p style="margin:0 0 10px;font-size:13px;color:#c62828;font-weight:bold;">&#9888;&#65039; Do this within 5 minutes of the kiosk starting &#8212; the app will block itself if not done.</p>
            <p style="margin:0 0 8px;font-size:13px;color:#555;">SSH into the Pi and run the following command:</p>
            <div style="background:#1e1e2e;border-radius:6px;padding:14px 16px;font-family:'Courier New',Courier,monospace;font-size:12px;color:#a8d8a8;line-height:1.8;">
              mkdir -p /home/pi/my-application/config &amp;&amp;<br>
              md5sum $(ls /sys/class/drm/card*-HDMI-A-1/edid 2&gt;/dev/null | head -1)<br>
              | awk '{print $1}' &gt; /home/pi/my-application/config/authorized_display.txt
            </div>
          </td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td style="padding:14px 30px;">
      <table width="100%" cellpadding="0" cellspacing="0">
        <tr>
          <td style="width:34px;vertical-align:top;padding-top:2px;">
            <div style="background:#1B5E20;color:#fff;border-radius:50%;width:28px;height:28px;text-align:center;line-height:28px;font-weight:bold;font-size:13px;">2</div>
          </td>
          <td style="padding-left:14px;vertical-align:top;">
            <p style="margin:0 0 14px;font-weight:bold;color:#1B5E20;font-size:14px;">TV Settings <span style="color:#777;font-weight:normal;font-size:12px;">(one-time per TV)</span></p>
            <p style="margin:0 0 6px;font-size:13px;font-weight:bold;color:#333;">2a. Enable HDMI-CEC &nbsp;<span style="color:#1B5E20;font-weight:normal;font-size:12px;">&#8212; required for TV auto on/off schedule</span></p>
            <table width="100%" cellpadding="0" cellspacing="0" style="font-size:12px;border-collapse:collapse;margin-bottom:16px;border-radius:6px;overflow:hidden;border:1px solid #e0e0e0;">
              <tr style="background:#1B5E20;color:#fff;">
                <td style="padding:8px 12px;font-weight:bold;width:90px;">Brand</td>
                <td style="padding:8px 12px;font-weight:bold;width:120px;">Setting Name</td>
                <td style="padding:8px 12px;font-weight:bold;">Path</td>
              </tr>
              <tr style="background:#f1f8e9;"><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;">Samsung</td><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;font-weight:bold;">Anynet+</td><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;color:#555;">Settings &#8250; General &#8250; External Device Manager</td></tr>
              <tr style="background:#fff;"><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;">LG</td><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;font-weight:bold;">SimpLink</td><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;color:#555;">Settings &#8250; Connection &#8250; HDMI Device Settings</td></tr>
              <tr style="background:#f1f8e9;"><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;">Sony</td><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;font-weight:bold;">BRAVIA Sync</td><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;color:#555;">Settings &#8250; Watching TV &#8250; External Inputs</td></tr>
              <tr style="background:#fff;"><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;">Panasonic</td><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;font-weight:bold;">VIERA Link</td><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;color:#555;">Settings &#8250; HDMI Device Settings</td></tr>
              <tr style="background:#f1f8e9;"><td style="padding:7px 12px;">Others</td><td style="padding:7px 12px;font-weight:bold;">HDMI-CEC</td><td style="padding:7px 12px;color:#555;">Settings &#8250; Inputs / HDMI Settings</td></tr>
            </table>
            <p style="margin:0 0 6px;font-size:13px;font-weight:bold;color:#333;">2b. Enable HDMI Auto-Switch &nbsp;<span style="color:#1B5E20;font-weight:normal;font-size:12px;">&#8212; auto switch TV to Pi input on startup</span></p>
            <table width="100%" cellpadding="0" cellspacing="0" style="font-size:12px;border-collapse:collapse;margin-bottom:16px;border-radius:6px;overflow:hidden;border:1px solid #e0e0e0;">
              <tr style="background:#1B5E20;color:#fff;">
                <td style="padding:8px 12px;font-weight:bold;width:90px;">Brand</td>
                <td style="padding:8px 12px;font-weight:bold;width:150px;">Setting Name</td>
                <td style="padding:8px 12px;font-weight:bold;">Path</td>
              </tr>
              <tr style="background:#f1f8e9;"><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;">Samsung</td><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;font-weight:bold;">Auto Source Switch</td><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;color:#555;">Settings &#8250; General &#8250; External Device Manager</td></tr>
              <tr style="background:#fff;"><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;">LG</td><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;font-weight:bold;">Auto Device Detection</td><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;color:#555;">Settings &#8250; Connection &#8250; HDMI Device Settings</td></tr>
              <tr style="background:#f1f8e9;"><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;">Sony</td><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;font-weight:bold;">Auto Input Change</td><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;color:#555;">Settings &#8250; Watching TV &#8250; External Inputs</td></tr>
              <tr style="background:#fff;"><td style="padding:7px 12px;">Others</td><td style="padding:7px 12px;font-weight:bold;">Auto Input Switch</td><td style="padding:7px 12px;color:#555;">Settings &#8250; Inputs &#8250; Auto Input Switch</td></tr>
            </table>
            <p style="margin:0 0 6px;font-size:13px;font-weight:bold;color:#333;">2c. Disable Bluetooth</p>
            <table width="100%" cellpadding="0" cellspacing="0" style="font-size:12px;border-collapse:collapse;border-radius:6px;overflow:hidden;border:1px solid #e0e0e0;">
              <tr style="background:#1B5E20;color:#fff;">
                <td style="padding:8px 12px;font-weight:bold;width:90px;">Brand</td>
                <td style="padding:8px 12px;font-weight:bold;">Path</td>
              </tr>
              <tr style="background:#f1f8e9;"><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;">Samsung</td><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;color:#555;">Settings &#8250; Sound &#8250; Sound Output &#8250; Bluetooth &#8594; OFF</td></tr>
              <tr style="background:#fff;"><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;">LG</td><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;color:#555;">Settings &#8250; Sound &#8250; Sound Out &#8250; Bluetooth &#8594; OFF</td></tr>
              <tr style="background:#f1f8e9;"><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;">Sony</td><td style="padding:7px 12px;border-bottom:1px solid #e8f5e9;color:#555;">Settings &#8250; Network &#8250; Bluetooth Settings &#8594; OFF</td></tr>
              <tr style="background:#fff;"><td style="padding:7px 12px;">Others</td><td style="padding:7px 12px;color:#555;">Settings &#8250; Sound / Wireless &#8250; Bluetooth &#8594; OFF</td></tr>
            </table>
          </td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td style="padding:14px 30px 30px;">
      <table width="100%" cellpadding="0" cellspacing="0">
        <tr>
          <td style="width:34px;vertical-align:top;padding-top:2px;">
            <div style="background:#c62828;color:#fff;border-radius:50%;width:28px;height:28px;text-align:center;line-height:28px;font-weight:bold;font-size:13px;">3</div>
          </td>
          <td style="padding-left:14px;vertical-align:top;">
            <p style="margin:0 0 6px;font-weight:bold;color:#c62828;font-size:14px;">Revoke GitHub Token</p>
            <p style="margin:0 0 12px;font-size:13px;color:#555;">The GitHub token used during installation is no longer needed. Please revoke it immediately to prevent unauthorized access to the repository.</p>
            <a href="https://github.com/settings/tokens" style="display:inline-block;background:#c62828;color:#ffffff;padding:9px 20px;border-radius:5px;text-decoration:none;font-size:13px;font-weight:bold;">&#128273; Revoke Token &#8594; github.com/settings/tokens</a>
          </td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td style="background:#1B5E20;padding:22px 30px;text-align:center;">
      <p style="margin:0;color:#c8e6c9;font-size:13px;font-weight:bold;">Jazak Allah Khair</p>
      <p style="margin:6px 0 0;color:#81c784;font-size:11px;">Salah-e-Waqt &#8212; Prayer Timetable Kiosk</p>
    </td>
  </tr>
</table>
</td></tr>
</table>
</body>
</html>
""".replace("MOSQUE_NAME", mosque_name).replace("MOSQUE_CODE", mosque_code).replace("HOSTNAME", hostname).replace("SETUP_TIME", setup_time)

msg_root = MIMEMultipart("related")
msg_root["From"]    = sender
msg_root["To"]      = receiver
msg_root["Subject"] = subject

msg_alt = MIMEMultipart("alternative")
msg_alt.attach(MIMEText(html, "html"))
msg_root.attach(msg_alt)

if logo_bytes:
    img_part = MIMEImage(logo_bytes, "png")
    img_part.add_header("Content-ID", "<logo>")
    img_part.add_header("Content-Disposition", "inline", filename="logo.png")
    msg_root.attach(img_part)

try:
    with smtplib.SMTP("smtp.gmail.com", 587) as server:
        server.starttls()
        server.login(sender, password)
        server.sendmail(sender, receiver, msg_root.as_string())
    print("Email sent successfully")
except Exception as e:
    print(f"Failed to send email: {e}")
EOFPY

    print_success "Setup completion email sent to zjahid19@gmail.com"
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

    # Ask which Pi version if not provided via argument
    if [ -z "$PI_VERSION" ]; then
        echo "========================================="
        echo " Which Raspberry Pi are you using?"
        echo "   3 = Raspberry Pi 3B / 3B+"
        echo "   4 = Raspberry Pi 4"
        echo "========================================="
        read -p " Enter 3 or 4: " PI_VERSION
        echo ""
    fi

    # Validate Pi version
    if [ "$PI_VERSION" != "3" ] && [ "$PI_VERSION" != "4" ]; then
        print_error "Invalid Pi version: '$PI_VERSION'. Please enter 3 or 4."
        exit 1
    fi

    print_info "Setting up for Raspberry Pi $PI_VERSION" | tee -a "$LOG_FILE"

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

    # setup_system  # Disabled: apt upgrade breaks lightdm on Pi OS Lite; apt update moved into install_dependencies
    install_dependencies
    setup_directories
    copy_project_files
    cleanup_project_files
    setup_python_venv
    setup_mosque_config
    setup_wifi_profiles
    disable_usb_ports
    disable_bluetooth
    setup_pi_hotspot
    configure_boot_config
    setup_rtc_module
    create_kiosk_script
    setup_autostart
    setup_tv_schedule
    send_completion_email
#   configure_display
#   create_env_file
#    final_configuration

    echo "##STAGE:complete##"
    print_header "SETUP COMPLETE!"
    print_success "Prayer Timetable setup completed successfully!"
    echo ""
    print_info "Summary:"
    echo "  • Project directory: $PROJECT_DIR"
    echo "  • Kiosk script: $PI_HOME/kiosk_run.sh"
    echo "  • Autostart: lightdm auto-login → $PI_HOME/.xsession"
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
    echo "  • SSID: my-hotspot | Password: admin@123"
    echo "  • Pi IP Address: 10.42.0.1 (assigned by NetworkManager)"
    echo "  • Admin Panel: http://10.42.0.1:5000/home"
    echo "  • Connect mobile to 'my-hotspot' to update remotely"
    echo ""
    print_info "Useful commands:"
    echo "  • View kiosk logs: tail -f $PI_HOME/kiosk.log"
    echo "  • Stop kiosk: pkill -f chromium"
    echo "  • WiFi status: iwgetid -r"
    echo "  • WiFi logs: tail -f /var/log/wifi-switcher.log"
    echo "  • WiFi timer status: sudo systemctl status wifi-switcher.timer"
    echo "  • Hotspot status: nmcli connection show my-hotspot"
    echo "  • Start hotspot: sudo nmcli connection up my-hotspot"
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
