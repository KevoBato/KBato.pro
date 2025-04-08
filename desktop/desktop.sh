#!/bin/bash

# Step 0: Install main dependencies
echo "Installing BatoAddons base dependencies..."
curl -L install.batoaddons.app | bash

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)
if [ "$arch" != "x86_64" ]; then
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi
echo "Architecture: $arch detected."

# Step 2: Prepare & Download Docker & Podman wrapper
echo "Preparing & Downloading Docker wrapper..."
directory="$HOME/batocera-containers"
url="https://github.com/DTJW92/batocera-unofficial-addons/releases/download/AppImages/batocera-containers"
filename="batocera-containers"
mkdir -p "$directory"
cd "$directory"
wget -q --show-progress "$url" -O "$filename"
chmod +x "$filename"

# Step 3: Autostart batocera-containers
startup="/userdata/system/batocera-containers/batocera-containers &"
csh=/userdata/system/custom.sh
if [ ! -f "$csh" ]; then
    echo -e "#!/bin/bash\n$startup\n" > "$csh"
else
    grep -qF "$startup" "$csh" || echo "$startup" >> "$csh"
fi
chmod +x "$csh"
dos2unix "$csh" 2>/dev/null

# Step 4: Start Docker wrapper
cd ~/batocera-containers
clear
echo "Starting Docker..."
./batocera-containers

# Step 5: Install Portainer
echo "Installing Portainer..."
docker volume create portainer_data
docker run --device /dev/dri:/dev/dri --privileged --net host --ipc host -d \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /media:/media \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

# Step 6: Enable Docker service
curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/docker/docker -o /userdata/system/services/docker && chmod +x /userdata/system/services/docker
batocera-services enable docker
batocera-services start docker

# Step 7: Install Webtop container
echo "Installing Webtop..."
mkdir -p /userdata/system/add-ons/webtop
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

# Step 8: Download Google Chrome AppImage (stable)
echo "Downloading Google Chrome AppImage..."
appimage_url=$(curl -s https://api.github.com/repos/ivan-hc/Chrome-appimage/releases/latest | jq -r '.assets[] | select(.name | endswith(".AppImage") and contains("Google-Chrome-stable")) | .browser_download_url')
mkdir -p /userdata/system/add-ons/google-chrome/extra
wget -q --show-progress -O /userdata/system/add-ons/google-chrome/GoogleChrome.AppImage "$appimage_url"
chmod +x /userdata/system/add-ons/google-chrome/GoogleChrome.AppImage

# Step 9: Create BatoDesktop launcher in Ports
echo "Creating BatoDesktop launcher..."
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/BatoDesktop.sh
#!/bin/bash
DISPLAY=:0.0 /userdata/system/add-ons/google-chrome/GoogleChrome.AppImage --no-sandbox --test-type --start-fullscreen --force-device-scale-factor=1.6 'http://localhost:3000'
EOF
chmod +x /userdata/roms/ports/BatoDesktop.sh

# Step 10: Create controller keybinds (.sh.keys)
echo "Adding controller key mapping..."
cat << 'EOF' > /userdata/roms/ports/BatoDesktop.sh.keys
{
    "actions_player1": [
        { "trigger": "up", "type": "key", "target": "KEY_UP" },
        { "trigger": "down", "type": "key", "target": "KEY_DOWN" },
        { "trigger": "left", "type": "key", "target": "KEY_LEFT" },
        { "trigger": "right", "type": "key", "target": "KEY_RIGHT" },
        { "trigger": "b", "type": "key", "target": "KEY_ENTER" },
        { "trigger": "start", "type": "key", "target": "KEY_ENTER" },
        { "trigger": "joystick1up", "type": "key", "target": "KEY_UP" },
        { "trigger": "joystick1down", "type": "key", "target": "KEY_DOWN" },
        { "trigger": "joystick1left", "type": "key", "target": "KEY_LEFT" },
        { "trigger": "joystick1right", "type": "key", "target": "KEY_RIGHT" },
        { "trigger": "select", "type": "key", "target": "KEY_ESC" },
        { "trigger": "a", "type": "key", "target": "KEY_ESC" },
        { "trigger": "pageup", "type": "exec", "target": "batocera-audio setSystemVolume -5" },
        { "trigger": "pagedown", "type": "exec", "target": "batocera-audio setSystemVolume +5" },
        { "trigger": "l2", "type": "exec", "target": "batocera-audio setSystemVolume -5" },
        { "trigger": "r2", "type": "exec", "target": "batocera-audio setSystemVolume +5" },
        { "trigger": "joystick2", "type": "mouse" },
        {
            "trigger": ["hotkey", "start"],
            "type": "key",
            "target": ["KEY_LEFTALT", "KEY_F4"]
        },
        { "trigger": "r3", "type": "key", "target": "BTN_LEFT" }
    ]
}
EOF

# Step 11: Final message
echo "KevoBato Was Here! Launch Desktop from Ports menu."
