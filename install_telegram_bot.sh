#!/bin/bash
set -e
COL='\033[1;32m'
NC='\033[0m' # No Color
echo -e "${COL}Setting up Moonraker Telegram Bot"

echo -e "${COL}Installing dependencies...\n${NC}"

: "${CONFIG_PATH:="/root/config"}"
: "${GCODE_PATH:="/root/gcode"}"

: "${MOONRAKER_BOT_REPO:="https://github.com/nlef/moonraker-telegram-bot"}"
: "${MOONRAKER_BOT_PATH:="/opt/moonraker-telegram-bot"}"
: "${MOONRAKER_BOT_VENV_PATH:="/opt/venv/moonraker-telegram-bot"}"

################################################################################
# MOONRAKER_BOT
################################################################################

apk add python3 py3-virtualenv python3-dev \
  py3-cryptography py3-gevent opencv \
  x264 x264-dev libwebp-dev

test -d $MOONRAKER_BOT_PATH || git clone $MOONRAKER_BOT_REPO $MOONRAKER_BOT_PATH
test -d $MOONRAKER_BOT_VENV_PATH || virtualenv -p python3 $MOONRAKER_BOT_VENV_PATH
$MOONRAKER_BOT_VENV_PATH/bin/python -m pip install --upgrade pip
$MOONRAKER_BOT_VENV_PATH/bin/pip install -r $MOONRAKER_BOT_PATH/scripts/requirements.txt

tee "$CONFIG_PATH"/telegram.conf <<EOF
#  Please refer to the wiki(https://github.com/nlef/moonraker-telegram-bot/wiki) for detailed information on how to configure the bot

[bot]
server: localhost
bot_token: AweSomeBotToken
chat_id: 0

[camera]
host: http://localhost:8080/?action=stream

[progress_notification]
percent: 5
height: 5
time: 5

[timelapse]
cleanup: true
height: 0.2
time: 5
target_fps: 30
EOF

mkdir -p /root/extensions/moonraker-telegram-bot
cat <<EOF >/root/extensions/moonraker-telegram-bot/manifest.json
{
        "title": "Moonraker Telegram Bot",
        "description": "Requires plugin"
}
EOF

cat <<EOF >/root/extensions/moonraker-telegram-bot/start.sh
#!/bin/sh
$MOONRAKER_BOT_VENV_PATH/bin/python $MOONRAKER_BOT_PATH/bot/main.py -c $CONFIG_PATH/telegram.conf -l /tmp/moonraker.log
EOF

cat <<EOF >/root/extensions/moonraker-telegram-bot//kill.sh
#!/bin/sh
pkill -f '$MOONRAKER_BOT_VENV_PATH/bin/python'
EOF

chmod +x /root/extensions/moonraker-telegram-bot/start.sh
chmod +x /root/extensions/moonraker-telegram-bot/kill.sh
chmod 777 /root/extensions/moonraker-telegram-bot/start.sh
chmod 777 /root/extensions/moonraker-telegram-bot/kill.sh

echo -e "${COL}\nMoonraker Telegram Bot installed! Please kill the app and restart it again to see it in extension settings${NC}"
