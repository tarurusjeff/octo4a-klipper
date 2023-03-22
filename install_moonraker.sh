#!/bin/bash
set -e
COL='\033[1;32m'
NC='\033[0m' # No Color
echo -e "${COL}Setting up Moonraker"

echo -e "${COL}Installing dependencies...\n${NC}"

: "${CONFIG_PATH:="/opt/config"}"
: "${GCODE_PATH:="/opt/gcode"}"

: "${MOONRAKER_REPO:="https://github.com/Arksine/moonraker"}"
: "${MOONRAKER_PATH:="/opt/moonraker"}"
: "${MOONRAKER_VENV_PATH:="/opt/venv/moonraker"}"

################################################################################
# PRE
################################################################################

apk add git unzip libffi-dev make gcc g++ \
  ncurses-dev avrdude gcc-avr binutils-avr avr-libc \
  python3 py3-virtualenv \
  python3-dev freetype-dev fribidi-dev harfbuzz-dev jpeg-dev lcms2-dev openjpeg-dev tcl-dev tiff-dev tk-dev zlib-dev \
  jq udev

################################################################################
# MOONRAKER
################################################################################
mkdir -p $CONFIG_PATH $GCODE_PATH

apk add libsodium curl-dev

test -d $MOONRAKER_PATH || git clone $MOONRAKER_REPO $MOONRAKER_PATH
test -d $MOONRAKER_VENV_PATH || virtualenv -p python3 $MOONRAKER_VENV_PATH
$MOONRAKER_VENV_PATH/bin/python -m pip install --upgrade pip
$MOONRAKER_VENV_PATH/bin/pip install -r $MOONRAKER_PATH/scripts/moonraker-requirements.txt

tee "$CONFIG_PATH"/moonraker.conf <<EOF
[server]
host: 0.0.0.0
config_path: $CONFIG_PATH

[authorization]
trusted_clients:
  192.168.0.0/16

[octoprint_compat]

[update_manager]

[update_manager client fluidd]
type: web
repo: cadriel/fluidd
path: $CLIENT_PATH
EOF

mkdir -p /root/extensions/moonraker
cat <<EOF >/root/extensions/moonraker/manifest.json
{
        "title": "Klipper + Moonraker + Mainsail / FluidD",
        "description": "Requires plugin"
}
EOF

cat <<EOF >/root/extensions/moonraker/start.sh
#!/bin/sh
$MOONRAKER_VENV_PATH/bin/python $MOONRAKER_PATH/moonraker/moonraker.py
EOF

cat <<EOF >/root/extensions/moonraker/kill.sh
#!/bin/sh
pkill -f 'moonraker.py'
EOF

chmod +x /root/extensions/moonraker/start.sh
chmod +x /root/extensions/moonraker/kill.sh
chmod 777 /root/extensions/moonraker/start.sh
chmod 777 /root/extensions/moonraker/kill.sh

echo -e "${COL}\nMoonraker installed! Please kill the app and restart it again to see it in extension settings${NC}"
