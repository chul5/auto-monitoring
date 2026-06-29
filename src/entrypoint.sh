#!/bin/bash
# 컨테이너 시작 시 자동 실행되는 entrypoint
set -euo pipefail

source /etc/profile.d/agent-app.sh

echo "[entrypoint] UFW 방화벽 설정"
ufw default deny incoming
ufw default allow outgoing
ufw allow 20022/tcp
ufw allow 15034/tcp
ufw --force enable

echo "[entrypoint] API 키 파일 생성"
echo "agent_api_key_test" > "$AGENT_KEY_PATH"
chmod 640 "$AGENT_KEY_PATH"
chown agent-dev:agent-core "$AGENT_KEY_PATH"

echo "[entrypoint] 앱 바이너리 배치"
cp /home/agent-admin/src/agent-app "$AGENT_HOME/agent-app"
chmod +x "$AGENT_HOME/agent-app"
chown agent-admin:agent-common "$AGENT_HOME/agent-app"

echo "[entrypoint] monitor.sh 배치"
cp /home/agent-admin/src/monitor.sh "$AGENT_HOME/bin/monitor.sh"
chmod 750 "$AGENT_HOME/bin/monitor.sh"
chown agent-dev:agent-core "$AGENT_HOME/bin/monitor.sh"

echo "[entrypoint] sudoers 설정"
echo "agent-admin ALL=(ALL) NOPASSWD: /usr/sbin/ufw status" > /etc/sudoers.d/agent-monitor
chmod 440 /etc/sudoers.d/agent-monitor

echo "[entrypoint] ACL 설정 (/var/log/agent-app — 볼륨 마운트 후 설정)"
setfacl -m g:agent-core:rwx /var/log/agent-app
setfacl -d -m g:agent-core:rwx /var/log/agent-app

echo "[entrypoint] cron 서비스 시작 및 crontab 등록"
service cron start
MONITOR_CRON="* * * * * /home/agent-admin/agent-app/bin/monitor.sh"
echo "$MONITOR_CRON" | su - agent-admin -c 'crontab -'

echo "[entrypoint] agent-app 시작"
su - agent-admin -c "nohup $AGENT_HOME/agent-app >> $AGENT_LOG_DIR/agent_app.log 2>&1 &"

echo "[entrypoint] 설정 완료 — sshd 시작"
exec /usr/sbin/sshd -D -e
