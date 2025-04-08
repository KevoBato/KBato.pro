#!/bin/bash

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

echo "Preparing & Downloading Docker & Podman..."

# Directory and URL setup
directory="$HOME/batocera-containers"
url="https://github.com/DTJW92/batocera-unofficial-addons/releases/download/AppImages/batocera-containers"
filename="batocera-containers"

# Create directory and download batocera-containers
mkdir -p "$directory"
cd "$directory"
wget -q --show-progress "$url" -O "$filename"
chmod +x "$filename"

echo "File '$filename' downloaded and made executable."

# Update ~/custom.sh to autostart batocera-containers
csh=/userdata/system/custom.sh; dos2unix $csh 2>/dev/null
startup="/userdata/system/batocera-containers/batocera-containers &"
if [[ -f $csh ]]; then
    tmp1=/tmp/tcsh1
    tmp2=/tmp/tcsh2
    remove="$startup"
    rm -f $tmp1 $tmp2
    nl=$(cat "$csh" | wc -l); nl1=$(($nl + 1))
    for l in $(seq 1 $nl1); do
        ln=$(sed "${l}q;d" "$csh")
        if [[ "$(echo "$ln" | grep "$remove")" == "" ]]; then
            if [[ "$l" == "1" && "$(echo "$ln" | grep "#" | grep "/bin/" | grep "bash")" == "" ]]; then
                echo "$ln" >> "$tmp1"
            elif [[ "$l" != "1" ]]; then
                echo "$ln" >> "$tmp1"
            fi
        fi
    done
    echo -e '#!/bin/bash' > "$tmp2"
    echo -e "\n$startup \n" >> "$tmp2"
    cat "$tmp1" | sed -e '/./b' -e :n -e 'N;s/\n$//;tn' >> "$tmp2"
    cp "$tmp2" "$csh"; dos2unix "$csh"; chmod a+x "$csh"
else
    echo -e '#!/bin/bash\n\n'"$startup\n" > "$csh"
    dos2unix "$csh"; chmod a+x "$csh"
fi
dos2unix ~/custom.sh 2>/dev/null
chmod a+x ~/custom.sh 2>/dev/null

cd ~/batocera-containers
clear
echo "Starting Docker..."
~/batocera-containers/batocera-containers

# Step 2: Install Portainer
echo "Installing Portainer..."
docker volume create portainer_data
docker run --device /dev/dri:/dev/dri --privileged --net host --ipc host -d \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /media:/media \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

# Enable Batocera Docker service
curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/docker/docker -o /userdata/system/services/docker && chmod +x /userdata/system/services/docker
batocera-services enable docker
batocera-services start docker

# Step 3: Ensure the Webtop config directory exists
echo "Creating Webtop directory..."
mkdir -p /userdata/system/add-ons/webtop

# Step 4: Install Webtop
echo "Installing Webtop..."
docker run -d \
  --name=webtop \
  --security-opt seccomp=unconfined \
  -e PUID=0 \
  -e PGID=0 \
  -e TZ=Etc/UTC \
  -e SUBFOLDER=/ \
  -e TITLE=Webtop \
  -v /userdata/system/add-ons/webtop:/config \
  -v /userdata:/mnt/batocera \
  -v /dev/dri:/dev/dri \
  -v /dev/bus/usb:/dev/bus/usb \
  -p 3000:3000 \
  --shm-size="1gb" \
  --restart unless-stopped \
  lscr.io/linuxserver/webtop:ubuntu-kde

# Step 5: Install Google Chrome AppImage
echo "Installing Google Chrome AppImage..."
# Detecting system architecture
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    appimage_url=$(curl -s https://api.github.com/repos/ivan-hc/Chrome-appimage/releases/latest | jq -r ".assets[] | select(.name | endswith(\".AppImage\")) | .browser_download_url")
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

echo "Downloading Google Chrome AppImage from $appimage_url..."
mkdir -p /userdata/system/add-ons/google-chrome/extra
wget -q --show-progress -O /userdata/system/add-ons/google-chrome/GoogleChrome.AppImage "$appimage_url"

if [ $? -ne 0 ]; then
    echo "Failed to download Google Chrome AppImage."
    exit 1
fi

chmod a+x /userdata/system/add-ons/google-chrome/GoogleChrome.AppImage
echo "Google Chrome AppImage downloaded and marked as executable."

# Step 6: Create the Google Chrome Script in Ports
echo "Creating Google Chrome script in Ports..."
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/GoogleChrome.sh
#!/bin/bash

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
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
    ./GoogleChrome.AppImage --no-sandbox --test-type "$@" > "${log_file}" 2>&1
    echo "Google Chrome exited."
else
    echo "GoogleChrome.AppImage not found or not executable."
    exit 1
fi
EOF

chmod +x /userdata/roms/ports/GoogleChrome.sh

# Step 7: Create the persistent desktop entry
APPNAME="Chrome"
DESKTOP_FILE="/usr/share/applications/${APPNAME}.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/${APPNAME,,}/${APPNAME}.desktop"
ICON_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/${APPNAME,,}/extra/icon.png"
mkdir -p "/userdata/system/configs/${APPNAME,,}"

echo "Downloading icon..."
wget --show-progress -qO "/userdata/system/add-ons/google-chrome/extra/icon.png" "$ICON_URL"

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

# Add to startup script
CUSTOM_STARTUP="/userdata/system/custom.sh"
if ! grep -q "$RESTORE_SCRIPT" "$CUSTOM_STARTUP"; then
    echo "Adding ${APPNAME} restore script to startup..."
    echo "bash \"$RESTORE_SCRIPT\" &" >> "$CUSTOM_STARTUP"
fi

chmod +x "$CUSTOM_STARTUP"

# Step 8: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Step 9: Download the Chrome logo for the menu
echo "Downloading Google Chrome logo..."
curl -L -o /userdata/roms/ports/images/chrome-logo.png https://github.com/DTJW92/batocera-unofficial-addons/raw/main/chrome/extra/chrome-logo.png
echo "Adding logo to Google Chrome entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./GoogleChrome.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Google Chrome" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/chrome-logo.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/rom
