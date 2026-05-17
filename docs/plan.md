# Implementation Plan - 단계별 구현 가이드

---

## 역할 분담 구조

| 구분 | 처리 위치 | 항목 |
|------|-----------|------|
| **Dockerfile** | 빌드 시 자동 | 패키지 설치, SSH 설정, 계정/그룹 생성, 디렉토리/권한, 환경변수, 비밀번호 |
| **컨테이너 안** | 직접 수행 | UFW 방화벽, API 키 파일, 앱 실행, monitor.sh 개발, crontab 등록 |

---

## Phase 0: Docker 환경 구성

### 0.1 프로젝트 디렉토리 구조

```
~/auto-monitoring/
├── Dockerfile
├── docker-compose.yml
├── src/                    # 컨테이너에 마운트 (/home/agent-admin/src)
├── logs/                   # 로그 영속성 (/var/log/agent-app)
└── docs/
    ├── agent-app           # 제공 바이너리 (PyInstaller, Linux x86-64)
    ├── MISSION.md
    └── plan.md
```

### 0.2 Dockerfile

```dockerfile
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    openssh-server openssh-client sudo curl wget vim nano \
    net-tools iproute2 ufw systemctl python3 python3-pip git \
    && rm -rf /var/lib/apt/lists/*

# SSH 서버 설정
RUN mkdir -p /run/sshd
RUN mkdir -p /var/log/agent-app

# SSH 포트 20022, Root 로그인 차단
RUN sed -i 's/#Port 22/Port 20022/' /etc/ssh/sshd_config
RUN echo 'PermitRootLogin no' >> /etc/ssh/sshd_config

# 그룹 생성
RUN groupadd -f agent-common && groupadd -f agent-core

# 사용자 생성
RUN useradd -m -s /bin/bash -g agent-common agent-admin && \
    usermod -aG agent-core agent-admin && \
    usermod -aG sudo agent-admin
RUN useradd -m -s /bin/bash -g agent-common agent-dev && \
    usermod -aG agent-core agent-dev
RUN useradd -m -s /bin/bash -g agent-common agent-test

# 비밀번호 설정
RUN echo "agent-admin:qwe123" | chpasswd && \
    echo "agent-dev:qwe123" | chpasswd && \
    echo "agent-test:qwe123" | chpasswd

# 디렉토리 생성 (Dockerfile RUN은 /bin/sh → brace expansion 미지원)
RUN mkdir -p /home/agent-admin/agent-app/bin \
    && mkdir -p /home/agent-admin/agent-app/upload_files \
    && mkdir -p /home/agent-admin/agent-app/api_keys

ENV AGENT_HOME=/home/agent-admin/agent-app
ENV AGENT_PORT=15034
ENV AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
ENV AGENT_KEY_PATH=$AGENT_HOME/api_keys/t_secret.key
ENV AGENT_LOG_DIR=/var/log/agent-app

# 디렉토리 권한 설정
RUN chmod 770 $AGENT_HOME/upload_files && \
    chmod 770 $AGENT_HOME/api_keys && \
    chmod 770 $AGENT_LOG_DIR && \
    chown -R agent-admin:agent-common $AGENT_HOME/upload_files && \
    chown -R agent-dev:agent-core $AGENT_HOME/api_keys && \
    chown -R agent-admin:agent-core $AGENT_LOG_DIR

EXPOSE 20022 15034

# -e: sshd 로그를 stderr로 출력 (docker-compose logs로 확인 가능)
CMD ["/usr/sbin/sshd", "-D", "-e"]
```

### 0.3 docker-compose.yml

```yaml
services:
  linux-practice:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: auto-monitoring-lab
    image: auto-monitoring:latest
    ports:
      - "20022:20022"    # SSH 포트
      - "15034:15034"    # 애플리케이션 포트
    volumes:
      - ./src:/home/agent-admin/src      # 호스트 스크립트
      - ./logs:/var/log/agent-app        # 로그 영속성
    environment:
      - AGENT_HOME=/home/agent-admin/agent-app
      - AGENT_PORT=15034
      - AGENT_LOG_DIR=/var/log/agent-app
    privileged: true
    stdin_open: true
    tty: true
    restart: unless-stopped
```

### 0.4 컨테이너 빌드 및 실행

```bash
cd ~/auto-monitoring

# 빌드 및 실행
docker-compose up -d --build

# 상태 확인
docker-compose ps
# 기대 결과: auto-monitoring-lab   Up ...

# SSH 시작 로그 확인
docker-compose logs linux-practice
# 기대 결과: Server listening on 0.0.0.0 port 20022.
```

### 0.5 컨테이너 접속 및 초기 검증

```bash
# 컨테이너 접속 (root로 진입)
docker-compose exec linux-practice bash

# SSH 설정 확인
grep -E "^Port|^PermitRootLogin" /etc/ssh/sshd_config
# 기대 결과:
# Port 20022
# PermitRootLogin no

# 계정 확인
id agent-admin
id agent-dev
id agent-test
# 기대 결과:
# uid=1001(agent-admin) gid=1002(agent-common) groups=...,1003(agent-core),27(sudo)
# uid=1002(agent-dev)   gid=1002(agent-common) groups=...,1003(agent-core)
# uid=1003(agent-test)  gid=1002(agent-common) groups=...

# 디렉토리/권한 확인 (root 접속 시 절대경로 사용)
ls -ld /home/agent-admin/agent-app/upload_files
ls -ld /home/agent-admin/agent-app/api_keys
ls -ld /var/log/agent-app
# 기대 결과: drwxrwx--- ... agent-admin agent-common (upload_files)
#           drwxrwx--- ... agent-dev   agent-core   (api_keys)
#           drwxrwx--- ... agent-admin agent-core   (agent-app)

# 환경변수 확인
echo "AGENT_HOME=$AGENT_HOME"
echo "AGENT_PORT=$AGENT_PORT"
echo "AGENT_LOG_DIR=$AGENT_LOG_DIR"

# sudo 동작 확인 (agent-admin으로 전환)
su - agent-admin
sudo whoami   # 비밀번호: qwe123 → 기대 결과: root
```

### 0.6 호스트에서 SSH 접속 테스트 (선택)

```bash
ssh -p 20022 agent-admin@localhost
# 비밀번호: qwe123

whoami   # 기대 결과: agent-admin
exit
```

---

## Phase 1: UFW 방화벽 설정

> 컨테이너 안에서 수행. UFW는 런타임에 활성화해야 하므로 Dockerfile로 처리 불가.

```bash
# 컨테이너 접속 후 agent-admin으로 전환
docker-compose exec linux-practice bash
su - agent-admin

# 기본 정책 설정
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 필요 포트만 개방 (순서 중요: 활성화 전에 반드시 설정)
sudo ufw allow 20022/tcp   # SSH
sudo ufw allow 15034/tcp   # APP

# UFW 활성화
sudo ufw enable

# 검증
sudo ufw status numbered
# 기대 결과:
#      To                         Action      From
#      --                         ------      ----
# [ 1] 20022/tcp                  ALLOW IN    Anywhere
# [ 2] 15034/tcp                  ALLOW IN    Anywhere
```

---

## Phase 2: API 키 파일 생성

```bash
# agent-admin 계정에서 수행
echo "agent_api_key_test" | sudo tee $AGENT_KEY_PATH > /dev/null

# 권한 설정
sudo chmod 600 $AGENT_KEY_PATH
sudo chown agent-dev:agent-core $AGENT_KEY_PATH

# 검증
ls -l $AGENT_KEY_PATH
# 기대 결과: -rw------- ... agent-dev agent-core ... t_secret.key

sudo cat $AGENT_KEY_PATH
# 기대 결과: agent_api_key_test
```

---

## Phase 3: 애플리케이션 배포 및 실행

### 3.1 바이너리 배치

`docs/agent-app`은 PyInstaller로 패키징된 Linux x86-64 ELF 실행 파일입니다.

```bash
# 호스트 docs/agent-app → 컨테이너 $AGENT_HOME 으로 복사
# (컨테이너 안에서, docs는 src 경로 기준)
cp /home/agent-admin/src/../docs/agent-app $AGENT_HOME/agent-app
chmod +x $AGENT_HOME/agent-app

ls -la $AGENT_HOME/agent-app
```

### 3.2 앱 실행

```bash
# agent-admin 계정에서 실행 (루트 금지)
cd $AGENT_HOME
./agent-app

# 기대 결과:
# Starting Agent Boot Sequence...
# [1/5] Checking User Account               [OK]
# [2/5] Verifying Environment Variables     [OK]
# [3/5] Checking Required Files             [OK]
# [4/5] Checking Port Availability          [OK]
# [5/5] Verifying Log Permission            [OK]
# ------------------------------------------------------------
# All Boot Checks Passed!
# Agent READY
```

### 3.3 포트 리슨 확인 (다른 터미널)

```bash
ss -tulnp | grep 15034
# 기대 결과: tcp LISTEN 0.0.0.0:15034 ... python3

curl http://localhost:15034/
```

---

## Phase 4: monitor.sh 개발

### 4.1 파일 위치/권한 정책

| 항목 | 값 |
|------|----|
| 경로 | `$AGENT_HOME/bin/monitor.sh` |
| 소유자 | `agent-dev` |
| 그룹 | `agent-core` |
| 권한 | `750` (rwxr-x---) |
| cron 실행 계정 | `agent-admin` |

### 4.2 스크립트 구조

```bash
#!/bin/bash
set -euo pipefail

# ===== 환경 변수 로드 =====
source /etc/profile.d/agent-app.sh

# ===== 변수 정의 =====
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="${AGENT_LOG_DIR}/monitor.log"

CPU_THRESHOLD=20
MEM_THRESHOLD=10
DISK_THRESHOLD=80

LOG_MAX_SIZE=$((10 * 1024 * 1024))  # 10MB
LOG_MAX_FILES=10

# ===== 함수 정의 =====

check_process() {
    pgrep -f "agent-app" > /dev/null
}

check_port() {
    ss -tulnp | grep -q ":${AGENT_PORT}.*LISTEN"
}

check_firewall() {
    sudo ufw status | grep -q "Status: active"
}

get_pid() {
    pgrep -f "agent-app" | head -1
}

get_cpu_usage() {
    top -bn1 | grep "%Cpu" | awk '{print $2}' | tr -d '%'
}

get_memory_usage() {
    free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}'
}

get_disk_usage() {
    df / | tail -1 | awk '{print $5}' | tr -d '%'
}

rotate_log() {
    [ -f "$LOG_FILE" ] || return 0
    local size
    size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$size" -ge "$LOG_MAX_SIZE" ]; then
        local i
        for i in $(seq $((LOG_MAX_FILES - 1)) -1 1); do
            [ -f "${LOG_FILE}.${i}" ] && mv "${LOG_FILE}.${i}" "${LOG_FILE}.$((i + 1))"
        done
        [ -f "${LOG_FILE}.${LOG_MAX_FILES}" ] && rm -f "${LOG_FILE}.${LOG_MAX_FILES}"
        mv "$LOG_FILE" "${LOG_FILE}.1"
    fi
}

# ===== Health Check (실패 시 exit 1) =====

if ! check_process; then
    echo "[ERROR] ${TIMESTAMP} | Process agent-app is not running" >> "$LOG_FILE"
    exit 1
fi

if ! check_port; then
    echo "[ERROR] ${TIMESTAMP} | Port ${AGENT_PORT}/tcp is not LISTEN" >> "$LOG_FILE"
    exit 1
fi

# ===== Warning Check (경고만, 계속 진행) =====

if ! check_firewall; then
    echo "[WARNING] ${TIMESTAMP} | Firewall is not active" >> "$LOG_FILE"
fi

# ===== 자원 수집 =====

APP_PID=$(get_pid)
CPU_USAGE=$(get_cpu_usage)
MEMORY_USAGE=$(get_memory_usage)
DISK_USAGE=$(get_disk_usage)

# ===== 임계값 경고 =====

if awk "BEGIN{exit !($CPU_USAGE > $CPU_THRESHOLD)}"; then
    echo "[WARNING] ${TIMESTAMP} | CPU threshold exceeded (${CPU_USAGE}% > ${CPU_THRESHOLD}%)" >> "$LOG_FILE"
fi

if awk "BEGIN{exit !($MEMORY_USAGE > $MEM_THRESHOLD)}"; then
    echo "[WARNING] ${TIMESTAMP} | MEM threshold exceeded (${MEMORY_USAGE}% > ${MEM_THRESHOLD}%)" >> "$LOG_FILE"
fi

if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
    echo "[WARNING] ${TIMESTAMP} | DISK threshold exceeded (${DISK_USAGE}% > ${DISK_THRESHOLD}%)" >> "$LOG_FILE"
fi

# ===== 로그 회전 후 기록 =====

rotate_log

echo "[${TIMESTAMP}] PID:${APP_PID} CPU:${CPU_USAGE}% MEM:${MEMORY_USAGE}% DISK_USED:${DISK_USAGE}%" >> "$LOG_FILE"

echo "Monitoring completed at ${TIMESTAMP}"
exit 0
```

### 4.3 배치 및 권한 설정

```bash
# 스크립트 생성
cat > $AGENT_HOME/bin/monitor.sh << 'EOF'
# (위 스크립트 내용)
EOF

chmod 750 $AGENT_HOME/bin/monitor.sh
sudo chown agent-dev:agent-core $AGENT_HOME/bin/monitor.sh

# 검증
ls -la $AGENT_HOME/bin/monitor.sh
# 기대 결과: -rwxr-x--- ... agent-dev agent-core ... monitor.sh
```

### 4.4 sudoers 설정 (cron 무인 실행용)

`monitor.sh`에서 `sudo ufw status`를 사용하므로, cron 비대화형 환경에서 패스워드 없이 실행되도록 설정합니다.

```bash
sudo visudo -f /etc/sudoers.d/agent-monitor
# 아래 내용 추가:
# agent-admin ALL=(ALL) NOPASSWD: /usr/sbin/ufw status
```

```bash
# 검증: 패스워드 없이 실행되는지 확인
sudo ufw status
# 패스워드 프롬프트 없이 결과 출력되면 성공
```

### 4.5 테스트

```bash
# agent-admin으로 실행
$AGENT_HOME/bin/monitor.sh

# 로그 확인
tail -5 $AGENT_LOG_DIR/monitor.log
# 기대 결과:
# [2026-05-17 12:00:01] PID:1234 CPU:5.0% MEM:3.2% DISK_USED:23%
```

---

## Phase 5: Crontab 자동화 설정

```bash
# agent-admin 계정에서 수행
su - agent-admin

# cron 데몬 시작 (Docker 컨테이너는 자동 시작 안 됨)
sudo service cron start
sudo service cron status   # 기대 결과: cron is running

# crontab 등록
crontab -e
# 아래 라인 추가 (매분 실행):
* * * * * /home/agent-admin/agent-app/bin/monitor.sh >> /var/log/agent-app/monitor.log 2>&1

# 등록 확인
crontab -l
```

### 자동 실행 검증

```bash
# 현재 로그 라인 수 저장
wc -l $AGENT_LOG_DIR/monitor.log

# 1분 대기 후 재확인 (라인 수 증가 여부)
sleep 70
wc -l $AGENT_LOG_DIR/monitor.log

# 실시간 확인 (호스트에서)
tail -f ~/auto-monitoring/logs/monitor.log
```

---

## Phase 6: 최종 검증

```bash
#!/bin/bash
# final-verification.sh

echo "========== Final Verification =========="

echo "1. SSH Configuration:"
grep -E "^Port|^PermitRootLogin" /etc/ssh/sshd_config

echo "2. SSH Port Listening:"
ss -tulnp | grep ssh

echo "3. Firewall Status:"
sudo ufw status verbose

echo "4. User Accounts:"
id agent-admin
id agent-dev
id agent-test

echo "5. Directory Permissions:"
ls -ld /home/agent-admin/agent-app/upload_files
ls -ld /home/agent-admin/agent-app/api_keys
ls -ld /var/log/agent-app

echo "6. API Key File:"
ls -la $AGENT_KEY_PATH

echo "7. Application Port (15034):"
ss -tulnp | grep 15034

echo "8. Monitor.sh Permissions:"
ls -la $AGENT_HOME/bin/monitor.sh

echo "9. Monitor Log (last 5 lines):"
tail -5 $AGENT_LOG_DIR/monitor.log

echo "10. Crontab (agent-admin):"
crontab -l

echo "11. Log Rotation:"
ls -lh $AGENT_LOG_DIR/monitor.log* 2>/dev/null || echo "No rotated logs yet"

echo "========== End =========="
```

---

## 트러블슈팅

### SSH 설정 변경 후 적용

```bash
# sshd는 PID 1이므로 systemctl/service restart 시 컨테이너 종료됨
# 설정 문법 검증 후 HUP 시그널로 리로드
sudo sshd -t
sudo kill -HUP $(pgrep -f "sshd -D")
```

### UFW 활성화 후 설정 복구

```bash
# SSH 포트 허용 추가 후 리로드
sudo ufw allow 20022/tcp
sudo ufw reload
```

### 환경변수 미인식

```bash
# su - 로 전환하면 /etc/profile.d/agent-app.sh 자동 로드
# 미로드 시 수동 소싱
source /etc/profile.d/agent-app.sh
```

### 로그 파일 쓰기 불가

```bash
ls -ld /var/log/agent-app
sudo chmod 770 /var/log/agent-app
sudo chown agent-admin:agent-core /var/log/agent-app
```

---

## 구현 체크리스트

- [ ] **Phase 0**: Docker 환경 구성 및 초기 검증
- [ ] **Phase 1**: UFW 방화벽 설정 (20022, 15034)
- [ ] **Phase 2**: API 키 파일 생성
- [ ] **Phase 3**: 애플리케이션 배포 및 실행 (Boot Sequence 5단계 [OK])
- [ ] **Phase 4**: monitor.sh 개발 (health check, 자원수집, 로그, sudoers)
- [ ] **Phase 5**: Crontab 매분 실행 등록 및 자동 누적 확인
- [ ] **Phase 6**: 최종 검증 및 수행 내역서 작성
