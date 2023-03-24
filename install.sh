#!/bin/bash
set -e
COL='\033[1;32m'
NC='\033[0m' # No Color
echo -e "${COL}Setting up klipper"

echo -e "${COL}Installing dependencies...\n${NC}"

: "${CONFIG_PATH:="/opt/config"}"
: "${GCODE_PATH:="/opt/gcode"}"

#: "${KLIPPER_REPO:="https://github.com/KevinOConnor/klipper.git"}"
: "${KLIPPER_REPO:="https://gitee.com/taurusjeff/klipper.git"}"
: "${KLIPPER_PATH:="/opt/klipper"}"
: "${KLIPPY_VENV_PATH:="/opt/venv/klippy"}"

#: "${MOONRAKER_REPO:="https://github.com/Arksine/moonraker"}"
: "${MOONRAKER_REPO:="https://gitee.com/taurusjeff/moonraker.git"}"
: "${MOONRAKER_PATH:="/opt/moonraker"}"
: "${MOONRAKER_VENV_PATH:="/opt/venv/moonraker"}"

: "${CLIENT:="mainsail"}"
: "${CLIENT_PATH:="/opt/www"}"

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

################################################################################
# MOONRAKER
################################################################################

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

################################################################################
# MAINSAIL/FLUIDD
################################################################################

apk add caddy curl

tee /etc/caddy/Caddyfile <<EOF
:8080 {
  route * {

    @moonraker {
      path /server/* /websocket /printer/* /access/* /api/* /machine/*
    }

    handle @moonraker {
      reverse_proxy localhost:7125
    }

    handle /* {
      root * /opt/www
      file_server
    }

    handle /webcam {
        reverse_proxy localhost:8081
    }
  }
}
EOF
CLIENT_RELEASE_URL='https://nas.ddhome.top/web/mainsail.zip'
#CLIENT_RELEASE_URL='https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip'
test -d $CLIENT_PATH && rm -rf $CLIENT_PATH
mkdir -p $CLIENT_PATH
(cd $CLIENT_PATH && wget -q -O $CLIENT.zip $CLIENT_RELEASE_URL && unzip $CLIENT.zip && rm $CLIENT.zip)

# rc-update add caddy
# service caddy start

mkdir -p /root/extensions/klipper_moonraker_mainsail
cat <<EOF >/root/extensions/klipper_moonraker_mainsail/manifest.json
{
        "title": "Klipper + Moonraker + Mainsail / FluidD",
        "description": "Requires plugin"
}
EOF

cat <<EOF >/root/extensions/klipper_moonraker_mainsail/start.sh
#!/bin/sh
# python3 /klipper/klippy/klippy.py /root/printer.cfg -l /tmp/klippy.log -a /tmp/klippy_uds
# $KLIPPY_VENV_PATH/bin/python $KLIPPER_PATH/klippy/klippy.py $CONFIG_PATH/printer.cfg -l /tmp/klippy.log -a /tmp/klippy_uds
# $MOONRAKER_VENV_PATH/bin/python $MOONRAKER_PATH/moonraker/moonraker.py
service klipper start
service moonraker start
caddy run --config /etc/caddy/Caddyfile
EOF

cat <<EOF >/root/extensions/klipper_moonraker_mainsail/kill.sh
#!/bin/sh
caddy stop
pkill -f 'klippy\.py'
pkill -f 'moonraker.py'
EOF

chmod +x /root/extensions/klipper_moonraker_mainsail/start.sh
chmod +x /root/extensions/klipper_moonraker_mainsail/kill.sh
chmod 777 /root/extensions/klipper_moonraker_mainsail/start.sh
chmod 777 /root/extensions/klipper_moonraker_mainsail/kill.sh

echo -e "${COL}\nKlipper installed! Please kill the app and restart it again to see it in extension settings${NC}"
