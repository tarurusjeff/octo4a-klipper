#!/bin/bash
set -e
COL='\033[1;32m'
NC='\033[0m' # No Color
echo -e "${COL}Setting up klipper"

echo -e "${COL}Installing dependencies...\n${NC}"

: "${CONFIG_PATH:="/root/config"}"
: "${GCODE_PATH:="/root/gcode"}"

: "${KLIPPER_REPO:="https://github.com/KevinOConnor/klipper.git"}"
: "${KLIPPER_PATH:="/opt/klipper"}"
: "${KLIPPY_VENV_PATH:="/opt/venv/klippy"}"

################################################################################
# PRE
################################################################################

apk add git unzip libffi-dev make gcc g++ \
  ncurses-dev avrdude gcc-avr binutils-avr avr-libc \
  python3 py3-virtualenv \
  python3-dev freetype-dev fribidi-dev harfbuzz-dev jpeg-dev lcms2-dev openjpeg-dev tcl-dev tiff-dev tk-dev zlib-dev \
  jq udev

################################################################################
# KLIPPER
################################################################################

mkdir -p $CONFIG_PATH $GCODE_PATH

test -d $KLIPPER_PATH || git clone $KLIPPER_REPO $KLIPPER_PATH
test -d $KLIPPY_VENV_PATH || virtualenv -p python3 $KLIPPY_VENV_PATH
$KLIPPY_VENV_PATH/bin/python -m pip install --upgrade pip
$KLIPPY_VENV_PATH/bin/pip install -r $KLIPPER_PATH/scripts/klippy-requirements.txt

mkdir -p /root/extensions/klipper
cat <<EOF >/root/extensions/klipper/manifest.json
{
        "title": "Moonraker",
        "description": "Requires plugin"
}
EOF

cat <<EOF >/root/extensions/klipper/start.sh
#!/bin/sh
$KLIPPY_VENV_PATH/bin/python $KLIPPER_PATH/klippy/klippy.py $CONFIG_PATH/printer.cfg -l /tmp/klippy.log -a /tmp/klippy_uds
EOF

cat <<EOF >/root/extensions/klipper/kill.sh
#!/bin/sh
pkill -f 'klippy\.py'
EOF

chmod +x /root/extensions/klipper/start.sh
chmod +x /root/extensions/klipper/kill.sh
chmod 777 /root/extensions/klipper/start.sh
chmod 777 /root/extensions/klipper/kill.sh

echo -e "${COL}\nKlipper installed! Please kill the app and restart it again to see it in extension settings${NC}"
