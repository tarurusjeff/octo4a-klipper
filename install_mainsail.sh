#!/bin/bash
set -e
COL='\033[1;32m'
NC='\033[0m' # No Color
echo -e "${COL}Setting up Mainsail"

echo -e "${COL}Installing dependencies...\n${NC}"

: "${CONFIG_PATH:="/opt/config"}"
: "${GCODE_PATH:="/opt/gcode"}"

: "${CLIENT:="mainsail"}"
: "${CLIENT_PATH:="/opt/www"}"

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
CLIENT_RELEASE_URL='https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip'
test -d $CLIENT_PATH && rm -rf $CLIENT_PATH
mkdir -p $CLIENT_PATH
(cd $CLIENT_PATH && wget -q -O $CLIENT.zip $CLIENT_RELEASE_URL && unzip $CLIENT.zip && rm $CLIENT.zip)

# rc-update add caddy
# service caddy start

mkdir -p /root/extensions/mainsail
cat <<EOF >/root/extensions/mainsail/manifest.json
{
        "title": "Mainsail",
        "description": "Requires plugin"
}
EOF

cat <<EOF >/root/extensions/mainsail/start.sh
#!/bin/sh
caddy run --config /etc/caddy/Caddyfile
EOF

cat <<EOF >/root/extensions/mainsail/kill.sh
#!/bin/sh
caddy stop
EOF

chmod +x /root/extensions/mainsail/start.sh
chmod +x /root/extensions/mainsail/kill.sh
chmod 777 /root/extensions/mainsail/start.sh
chmod 777 /root/extensions/mainsail/kill.sh

echo -e "${COL}\nMainsail installed! Please kill the app and restart it again to see it in extension settings${NC}"
