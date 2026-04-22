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
    HOTSPOT_IP="192.168.4.1"

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
        connection.autoconnect no 2>/dev/null || true

    print_success "Hotspot profile created"
    print_info "Hotspot details:"
    echo "  • SSID: $HOTSPOT_SSID (open - no password)"
    echo "  • Pi IP: 10.42.0.1 (assigned by NetworkManager)"
    echo "  • Mobile connects to: my-hotspot (no password)"
    echo "  • Admin panel: http://10.42.0.1:5000/home"
    echo "  • Mode: Broadcasts by default, switches to salah-e-waqt when found"
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

xrandr --output HDMI-1 --mode 1920x1080 --rate 60 2>/dev/null || true
sleep 2

xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true
xset s noblank 2>/dev/null || true

if [ "$ENABLE_LOGGING" = "true" ]; then
    CHROMIUM_LOG="/home/pi/chromium.log"
else
    CHROMIUM_LOG="/dev/null"
fi

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
        $CHROMIUM_BIN \
          --kiosk \
          --noerrdialogs \
          --disable-session-crashed-bubble \
          --disable-infobars \
          --start-fullscreen \
          "file://$PROJECT_DIR/unauthorized.html" > /dev/null 2>&1 &
        log "Unauthorized page displayed."
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
log "Finished"
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
EOFLIGHTDM
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

    setup_system
    install_dependencies
    setup_directories
    copy_project_files
    setup_python_venv
    setup_wifi_profiles
    disable_bluetooth
    setup_pi_hotspot
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
    echo "  • SSID: my-hotspot (open - no password)"
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
