#!/bin/bash

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    
    # Get the latest Google Chrome AppImage URL
    appimage_url=$(curl -s https://api.github.com/repos/ivan-hc/Chrome-appimage/releases/latest | jq -r ".assets[] | select(.name | endswith(\".AppImage\")) | .browser_download_url" | grep -v "eta")
    
    # Check if we got a valid URL
    if [ -z "$appimage_url" ]; then
        echo "Error: Failed to retrieve AppImage URL."
        exit 1
    fi
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Download the AppImage
echo "Downloading Google Chrome AppImage from $appimage_url..."
mkdir -p /userdata/system/add-ons/google-chrome/extra
wget -q --show-progress -O /userdata/system/add-ons/google-chrome/GoogleChrome.AppImage "$appimage_url"

# Check if the download was successful
if [ $? -ne 0 ]; then
    echo "Failed to download Google Chrome AppImage."
    exit 1
fi

# Step 3: Make the AppImage executable
chmod a+x /userdata/system/add-ons/google-chrome/GoogleChrome.AppImage
if [ $? -ne 0 ]; then
    echo "Failed to make the AppImage executable."
    exit 1
fi

echo "Google Chrome AppImage downloaded and made executable."

# Step 4: Create Google Chrome Script (GoogleChrome.sh)
echo "Creating Google Chrome launch script..."
mkdir -p /userdata/roms/ports

cat << 'EOF' > /userdata/roms/ports/GoogleChrome.sh
#!/bin/bash

# Environment setup
export DISPLAY=:0.0
export HOME="/userdata/system/add-ons/google-chrome"

# Directories and file paths
app_dir="/userdata/system/add-ons/google-chrome"
app_image="${app_dir}/GoogleChrome.AppImage"
log_dir="/userdata/system/logs"
log_file="${log_dir}/google-chrome.log"

# Ensure log directory exists
mkdir -p "${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): Launching Google Chrome"

# Launch Google Chrome AppImage
if [ -x "${app_image}" ]; then
    cd "${app_dir}"
    ./GoogleChrome.AppImage --no-sandbox --test-type --start-fullscreen --force-device-scale-factor=1.6 'http://localhost:3000' > "${log_file}" 2>&1
    echo "Google Chrome exited."
else
    echo "GoogleChrome.AppImage not found or not executable."
    exit 1
fi
EOF

chmod +x /userdata/roms/ports/GoogleChrome.sh

# Step 5: Create Desktop Entry for Google Chrome
APPNAME="Google Chrome"
DESKTOP_FILE="/usr/share/applications/${APPNAME}.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/${APPNAME,,}/${APPNAME}.desktop"
ICON_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/google-chrome/extra/icon.png"
mkdir -p "/userdata/system/configs/${APPNAME,,}"

# Download the icon
echo "Downloading Google Chrome icon..."
wget --show-progress -qO "/userdata/system/add-ons/google-chrome/extra/icon.png" "$ICON_URL"

# Create persistent desktop entry
echo "Creating persistent desktop entry for ${APPNAME}..."
cat <<EOF > "$PERSISTENT_DESKTOP"
[Desktop Entry]
Version=1.0
Type=Application
Name=Google Chrome
Exec=/userdata/roms/ports/GoogleChrome.sh
Icon=/userdata/system/add-ons/google-chrome/extra/icon.png
Terminal=false
Categories=Game;batocera.linux;
EOF

chmod +x "$PERSISTENT_DESKTOP"

cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

# Ensure the desktop entry is always restored to /usr/share/applications
echo "Ensuring ${APPNAME} desktop entry is restored at startup..."
RESTORE_SCRIPT="/userdata/system/configs/${APPNAME,,}/restore_desktop_entry.sh"

cat <<EOF > "$RESTORE_SCRIPT"
#!/bin/bash
# Restore ${APPNAME} desktop entry
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Restoring ${APPNAME} desktop entry..."
    cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
    echo "${APPNAME} desktop entry restored."
else
    echo "${APPNAME} desktop entry already exists."
fi
EOF

chmod +x "$RESTORE_SCRIPT"

# Add restore script to startup
CUSTOM_STARTUP="/userdata/system/custom.sh"

if ! grep -q "$RESTORE_SCRIPT" "$CUSTOM_STARTUP"; then
    echo "Adding ${APPNAME} restore script to startup..."
    echo "bash \"$RESTORE_SCRIPT\" &" >> "$CUSTOM_STARTUP"
fi

chmod +x "$CUSTOM_STARTUP"

# Step 6: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Download the logo for the game list
echo "Downloading Google Chrome logo..."
curl -L -o /userdata/roms/ports/images/chrome-logo.png https://github.com/DTJW92/batocera-unofficial-addons/raw/main/google-chrome/extra/chrome-logo.png

# Add logo to Google Chrome entry in gamelist.xml
echo "Adding logo to Google Chrome entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./GoogleChrome.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Google Chrome" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/chrome-logo.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml

# Refresh the game list again
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Google Chrome from the Ports menu."
