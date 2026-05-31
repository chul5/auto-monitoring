#!/bin/bash
# setup.sh - docker-compose up -d --build 이후 컨테이너 내부에서 실행
# 실행: docker-compose exec linux-practice bash /home/agent-admin/src/setup.sh

set -euo pipefail

source /etc/profile.d/agent-app.sh

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] root로 실행해야 합니다."
    echo "  docker-compose exec linux-practice bash /home/agent-admin/src/setup.sh"
    exit 1
fi

echo ""
echo "====== Phase 1: UFW 방화벽 설정 ======"
ufw default deny incoming
ufw default allow outgoing
ufw allow 20022/tcp
ufw allow 15034/tcp
ufw --force enable
ufw status numbered

echo ""
echo "====== Phase 2: API 키 파일 생성 ======"
echo "agent_api_key_test" > "$AGENT_KEY_PATH"
chmod 600 "$AGENT_KEY_PATH"
chown agent-dev:agent-core "$AGENT_KEY_PATH"
ls -l "$AGENT_KEY_PATH"

echo ""
echo "====== Phase 3: 앱 바이너리 배치 ======"
cp /home/agent-admin/src/agent-app "$AGENT_HOME/agent-app"
chmod +x "$AGENT_HOME/agent-app"
chown agent-admin:agent-common "$AGENT_HOME/agent-app"
ls -la "$AGENT_HOME/agent-app"

echo ""
echo "====== Phase 4: monitor.sh 배치 및 권한 설정 ======"
cp /home/agent-admin/src/monitor.sh "$AGENT_HOME/bin/monitor.sh"
chmod 750 "$AGENT_HOME/bin/monitor.sh"
chown agent-dev:agent-core "$AGENT_HOME/bin/monitor.sh"
ls -la "$AGENT_HOME/bin/monitor.sh"

echo ""
echo "====== Phase 4.4: sudoers 설정 (cron 무인 실행용) ======"
echo "agent-admin ALL=(ALL) NOPASSWD: /usr/sbin/ufw status" > /etc/sudoers.d/agent-monitor
chmod 440 /etc/sudoers.d/agent-monitor
echo "[OK] /etc/sudoers.d/agent-monitor"

echo ""
echo "====== Phase 5: Cron 서비스 시작 및 crontab 등록 ======"
service cron start || service cron restart
# 절대경로 사용 (cron은 환경변수 미상속)
MONITOR_CRON="* * * * * /home/agent-admin/agent-app/bin/monitor.sh"
echo "$MONITOR_CRON" | su - agent-admin -c 'crontab -'
echo "[OK] crontab 등록:"
su - agent-admin -c 'crontab -l'

echo ""
echo "====== 자동 설정 완료 ======"
echo "다음 단계 (수동 실행):"
echo "  su - agent-admin"
echo "  cd \$AGENT_HOME && ./agent-app"
