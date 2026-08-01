#!/bin/bash
# 컨테이너 시작 시 실행되는 런타임 설정 스크립트
# 재실행해도 결과가 같도록(idempotent) 작성한다.
set -euo pipefail

# ===== 환경변수 확정 =====
# 컨테이너 환경변수(Dockerfile ENV + docker-compose environment)를 profile.d로 내보낸다.
# 빌드 시점에 굽지 않고 여기서 만들어야 compose로 덮어쓴 값이 실제로 반영된다.
# cron과 ssh 로그인 셸은 profile.d를 읽으므로, 이 파일이 있어야 모두 같은 값을 본다.
echo "[setup] 환경변수 파일 생성"
cat > /etc/profile.d/agent-app.sh <<EOF
export AGENT_HOME=${AGENT_HOME}
export AGENT_PORT=${AGENT_PORT}
export AGENT_UPLOAD_DIR=${AGENT_UPLOAD_DIR}
export AGENT_KEY_PATH=${AGENT_KEY_PATH}
export AGENT_LOG_DIR=${AGENT_LOG_DIR}
EOF
chmod 644 /etc/profile.d/agent-app.sh

# ===== 디렉토리 권한 정책 =====
# 바인드 마운트는 이미지에 구워둔 권한을 덮어쓰므로, 마운트가 끝난 런타임에 적용해야 한다.
echo "[setup] 디렉토리 권한 정책 적용"
chown agent-admin:agent-common "$AGENT_HOME"
chmod 755 "$AGENT_HOME"

chown agent-dev:agent-core "$AGENT_HOME/bin"
chmod 750 "$AGENT_HOME/bin"

chown -R agent-admin:agent-common "$AGENT_UPLOAD_DIR"
chmod 770 "$AGENT_UPLOAD_DIR"

chown -R agent-dev:agent-core "$AGENT_HOME/api_keys"
chmod 770 "$AGENT_HOME/api_keys"

chown -R agent-admin:agent-core "$AGENT_LOG_DIR"
chmod 770 "$AGENT_LOG_DIR"

echo "[setup] UFW 방화벽 설정"
ufw default deny incoming
ufw default allow outgoing
ufw allow 20022/tcp              # SSH. sshd_config에 박힌 값이라 고정
ufw allow "${AGENT_PORT}/tcp"    # APP. 환경변수로 관리하는 값이므로 변수를 그대로 사용
ufw --force enable

echo "[setup] API 키 파일 생성"
echo "agent_api_key_test" > "$AGENT_KEY_PATH"
chmod 640 "$AGENT_KEY_PATH"
chown agent-dev:agent-core "$AGENT_KEY_PATH"

# 재실행 대비: 앱이 떠 있으면 바이너리가 잠겨(Text file busy) cp가 실패하고,
# 종료하지 않으면 앱이 중복 기동되어 포트가 충돌한다.
echo "[setup] 기존 agent-app 종료"
pkill -f "$AGENT_HOME/agent-app$" || true
sleep 1

echo "[setup] 앱 바이너리 배치"
cp /home/agent-admin/src/agent-app "$AGENT_HOME/agent-app"
chmod +x "$AGENT_HOME/agent-app"
chown agent-admin:agent-common "$AGENT_HOME/agent-app"

echo "[setup] monitor.sh 배치"
cp /home/agent-admin/src/monitor.sh "$AGENT_HOME/bin/monitor.sh"
chmod 750 "$AGENT_HOME/bin/monitor.sh"
chown agent-dev:agent-core "$AGENT_HOME/bin/monitor.sh"

echo "[setup] sudoers 설정"
echo "agent-admin ALL=(ALL) NOPASSWD: /usr/sbin/ufw status" > /etc/sudoers.d/agent-monitor
chmod 440 /etc/sudoers.d/agent-monitor

echo "[setup] cron 서비스 시작 및 crontab 등록"
service cron start
MONITOR_CRON="* * * * * $AGENT_HOME/bin/monitor.sh"
echo "$MONITOR_CRON" | su - agent-admin -c 'crontab -'

echo "[setup] agent-app 시작"
su - agent-admin -c "nohup $AGENT_HOME/agent-app >> $AGENT_LOG_DIR/agent_app.log 2>&1 &"

echo "[setup] 설정 완료"
