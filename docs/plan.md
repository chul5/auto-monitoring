# Implementation Plan - 단계별 구현 가이드

---

## 역할 분담 구조

| 구분 | 처리 위치 | 항목 | MISSION.md |
|------|-----------|------|------------|
| **Dockerfile** | 빌드 시 자동 | 패키지 설치, SSH 설정, 계정/그룹 생성, 디렉토리/권한/ACL, 환경변수, 비밀번호 | §4-1(SSH), §4-2, §4-3(환경변수) |
| **entrypoint.sh** | 컨테이너 시작 시 자동 | UFW 방화벽, ACL(/var/log), API 키 파일, 앱 바이너리 배치, monitor.sh 배치, sudoers, crontab, 앱 기동 | §4-1(UFW), §4-2, §4-3, §4-4(cron) |
| **수동** | 직접 수행 | Boot Sequence 확인, verification.sh 실행 | §2-1 체크리스트 5 |

> **UFW 주의**: 컨테이너 재시작 시 entrypoint.sh가 자동 재설정하므로 별도 수동 실행 불필요.

---

## Phase 0: Docker 환경 구성

### 0.1 프로젝트 디렉토리 구조

```
~/auto-monitoring/
├── Dockerfile
├── docker-compose.yml
├── src/                         # 컨테이너에 마운트 (/home/agent-admin/src)
│   ├── agent-app                # 제공 바이너리 (PyInstaller, Linux x86-64)
│   ├── entrypoint.sh            # ← 컨테이너 시작 시 자동 실행 (모든 설정 + 앱 기동)
│   ├── monitor.sh               # ← 시스템 모니터링 스크립트 본체
│   └── verification.sh          # ← 요구사항 검증 스크립트
├── logs/                        # 로그 영속성 (/var/log/agent-app) ← 반드시 사전 생성
└── docs/
    ├── MISSION.md
    └── plan.md
```

> `logs/` 디렉토리는 docker-compose 볼륨 마운트 대상이므로 **빌드 전에** 반드시 생성해야 한다.

### 0.2 Dockerfile

<!-- MISSION §4-1: SSH 포트 20022 변경, Root 원격 로그인 차단 -->
<!-- MISSION §4-2: 계정(agent-admin/dev/test), 그룹(agent-common/agent-core) 생성 -->
<!-- MISSION §4-2: 디렉토리 구조($AGENT_HOME/upload_files, api_keys, bin) 및 ACL 권한 -->
<!-- MISSION §4-3: 환경변수(AGENT_HOME, AGENT_PORT, AGENT_UPLOAD_DIR, AGENT_KEY_PATH, AGENT_LOG_DIR) -->

```dockerfile
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    openssh-server openssh-client sudo curl wget vim nano \
    net-tools iproute2 ufw systemctl python3 python3-pip git \
    && rm -rf /var/lib/apt/lists/*

# SSH 서버 설정
RUN mkdir -p /run/sshd
RUN mkdir -p /var/log/agent-app

# SSH 포트 20022, Root 로그인 차단  [MISSION §4-1 SSH 설정]
RUN sed -i 's/#Port 22/Port 20022/' /etc/ssh/sshd_config
RUN echo 'PermitRootLogin no' >> /etc/ssh/sshd_config

# 그룹 생성  [MISSION §4-2 생성 그룹]
RUN groupadd -f agent-common && groupadd -f agent-core

# 사용자 생성  [MISSION §4-2 생성 계정]
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

# 환경변수 설정  [MISSION §4-3 환경변수]
ENV AGENT_HOME=/home/agent-admin/agent-app
ENV AGENT_PORT=15034
ENV AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
ENV AGENT_KEY_PATH=$AGENT_HOME/api_keys/t_secret.key
ENV AGENT_LOG_DIR=/var/log/agent-app

RUN echo "export AGENT_HOME=${AGENT_HOME}\nexport AGENT_PORT=${AGENT_PORT}\nexport AGENT_UPLOAD_DIR=${AGENT_UPLOAD_DIR}\nexport AGENT_KEY_PATH=${AGENT_KEY_PATH}\nexport AGENT_LOG_DIR=${AGENT_LOG_DIR}" > /etc/profile.d/agent-app.sh

# 디렉토리 권한 설정  [MISSION §4-2 접근 권한]
# $AGENT_HOME, $AGENT_HOME/bin은 RUN mkdir로 생성 시 root:root → 명시적 chown 필요
RUN chown agent-admin:agent-common $AGENT_HOME && \
    chown agent-dev:agent-core $AGENT_HOME/bin && \
    chmod 755 $AGENT_HOME && \
    chmod 750 $AGENT_HOME/bin && \
    chmod 770 $AGENT_HOME/upload_files && \
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
      - ./src:/home/agent-admin/src      # 호스트 스크립트 (setup.sh, monitor.sh, agent-app)
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

# logs/ 디렉토리 사전 생성 (볼륨 마운트 대상)
mkdir -p logs

# 빌드 및 실행
docker-compose up -d --build

# 상태 확인
docker-compose ps
# 기대 결과: auto-monitoring-lab   Up ...

# SSH 시작 로그 확인
docker-compose logs linux-practice
# 기대 결과: Server listening on 0.0.0.0 port 20022.
```

### 0.5 컨테이너 초기 검증

```bash
# 컨테이너 접속 (root로 진입)
docker-compose exec linux-practice bash

# SSH 설정 확인  [MISSION §2-1 체크리스트 1]
grep -E "^Port|^PermitRootLogin" /etc/ssh/sshd_config
# 기대 결과:
# Port 20022
# PermitRootLogin no

# 계정 확인  [MISSION §2-1 체크리스트 3]
id agent-admin
id agent-dev
id agent-test
# 기대 결과:
# uid=1001(agent-admin) gid=1002(agent-common) groups=...,1003(agent-core),27(sudo)
# uid=1002(agent-dev)   gid=1002(agent-common) groups=...,1003(agent-core)
# uid=1003(agent-test)  gid=1002(agent-common) groups=...

# 디렉토리/권한 확인  [MISSION §2-1 체크리스트 4]
ls -ld /home/agent-admin/agent-app           # agent-admin:agent-common 755
ls -ld /home/agent-admin/agent-app/bin       # agent-dev:agent-core 750
ls -ld /home/agent-admin/agent-app/upload_files
ls -ld /home/agent-admin/agent-app/api_keys
ls -ld /var/log/agent-app

# 환경변수 확인
echo "AGENT_HOME=$AGENT_HOME"
echo "AGENT_PORT=$AGENT_PORT"
echo "AGENT_LOG_DIR=$AGENT_LOG_DIR"
```

---

## Phase 1–5: setup.sh 일괄 실행

<!-- MISSION §4-1: UFW 방화벽 20022/tcp, 15034/tcp 허용 -->
<!-- MISSION §4-2: API 키 파일 경로/권한 -->
<!-- MISSION §4-3: 키 파일 생성(agent_api_key_test), 앱 바이너리 배치 -->
<!-- MISSION §4-4: monitor.sh 배치/권한(750, agent-dev:agent-core), sudoers, crontab 매분 등록 -->

`docker-compose up -d --build` 이후 아래 명령 한 번으로 Phase 1~5를 완료한다.

```bash
docker-compose exec linux-practice bash /home/agent-admin/src/setup.sh
```

setup.sh가 처리하는 항목:

| Phase | 항목 | MISSION.md |
|-------|------|------------|
| 1 | UFW 방화벽 활성화 (20022/tcp, 15034/tcp) | §4-1 방화벽 설정, §2-1 체크리스트 2 |
| 2 | API 키 파일 생성 (`agent_api_key_test`, 600, agent-dev:agent-core) | §4-3 키 파일 생성 |
| 3 | agent-app 바이너리 src/ → $AGENT_HOME 배치 | §4-3 앱 실행 환경 |
| 4 | monitor.sh 배치 (750, agent-dev:agent-core) + sudoers 설정 | §4-4 파일 위치/권한 정책 |
| 5 | cron 서비스 시작 + agent-admin crontab 매분 등록 | §4-4 자동 실행(cron) 설정 |

실행 후 확인:

```bash
# 방화벽  [MISSION §2-1 체크리스트 2]
docker-compose exec linux-practice ufw status numbered

# API 키 파일  [MISSION §4-3]
docker-compose exec linux-practice ls -l /home/agent-admin/agent-app/api_keys/t_secret.key

# monitor.sh 권한  [MISSION §2-1 체크리스트 6]
docker-compose exec linux-practice ls -la /home/agent-admin/agent-app/bin/monitor.sh

# crontab  [MISSION §2-1 체크리스트 8]
docker-compose exec -u agent-admin linux-practice crontab -l
```

---

## Phase 6: 애플리케이션 실행 (수동)

<!-- MISSION §4-3: 루트 실행 금지, Boot Sequence 5단계 [OK], Agent READY 출력, 0.0.0.0:15034 LISTEN -->
<!-- MISSION §2-1 체크리스트 5: Boot Sequence 5단계 [OK] 및 "Agent READY" 확인 내역 -->

setup.sh가 처리하지 않는 유일한 수동 단계. Boot Sequence 출력이 체크리스트 증거이므로 직접 확인해야 한다.

```bash
# agent-admin으로 전환 (루트 실행 금지)
su - agent-admin

# 앱 실행
cd $AGENT_HOME
./agent-app

# 기대 출력:
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

포트 리슨 확인 (다른 터미널):

```bash
# [MISSION §2-1 체크리스트 5]
ss -tulnp | grep 15034
# 기대 결과: tcp LISTEN 0.0.0.0:15034
```

---

## Phase 7: 자동 실행 검증

<!-- MISSION §4-4 자동 실행(cron) 설정: 등록 후 1~2분 내 monitor.log 누적 확인 -->
<!-- MISSION §2-1 체크리스트 7, 8 -->

```bash
# 현재 로그 라인 수 저장
wc -l /var/log/agent-app/monitor.log

# 1분 대기 후 재확인 (라인 수 증가 여부)  [MISSION §2-1 체크리스트 8]
sleep 70
wc -l /var/log/agent-app/monitor.log

# 실시간 확인 (호스트에서)  [MISSION §2-1 체크리스트 7]
tail -f ~/auto-monitoring/logs/monitor.log
```

---

## Phase 8: 최종 검증

```bash
#!/bin/bash
# final-verification.sh

echo "========== Final Verification =========="

echo "1. SSH Configuration:"          # [MISSION §2-1 체크리스트 1]
grep -E "^Port|^PermitRootLogin" /etc/ssh/sshd_config

echo "2. SSH Port Listening:"
ss -tulnp | grep ssh

echo "3. Firewall Status:"            # [MISSION §2-1 체크리스트 2]
ufw status verbose

echo "4. User Accounts:"             # [MISSION §2-1 체크리스트 3]
id agent-admin
id agent-dev
id agent-test

echo "5. Directory Permissions:"     # [MISSION §2-1 체크리스트 4]
ls -ld /home/agent-admin/agent-app
ls -ld /home/agent-admin/agent-app/bin
ls -ld /home/agent-admin/agent-app/upload_files
ls -ld /home/agent-admin/agent-app/api_keys
ls -ld /var/log/agent-app

echo "6. API Key File:"
ls -la $AGENT_KEY_PATH

echo "7. Application Port (15034):"  # [MISSION §2-1 체크리스트 5]
ss -tulnp | grep 15034

echo "8. Monitor.sh Permissions:"    # [MISSION §4-4 파일 위치/권한 정책]
ls -la $AGENT_HOME/bin/monitor.sh

echo "9. Monitor Log (last 5 lines):" # [MISSION §2-1 체크리스트 7]
tail -5 $AGENT_LOG_DIR/monitor.log

echo "10. Crontab (agent-admin):"    # [MISSION §2-1 체크리스트 8]
su - agent-admin -c 'crontab -l'

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

### UFW 재시작 후 초기화

```bash
# 컨테이너 재시작 시 UFW 상태 리셋됨 → setup.sh 재실행
docker-compose exec linux-practice bash /home/agent-admin/src/setup.sh
```

### 환경변수 미인식

```bash
# su - 로 전환하면 /etc/profile.d/agent-app.sh 자동 로드
# cron 환경에서는 monitor.sh 내부에서 source로 로드
source /etc/profile.d/agent-app.sh
```

### 로그 파일 쓰기 불가

```bash
ls -ld /var/log/agent-app
# 소유자/권한이 올바른지 확인: agent-admin:agent-core 770
chmod 770 /var/log/agent-app
chown agent-admin:agent-core /var/log/agent-app
```

---

## 구현 체크리스트

- [ ] **Phase 0**: Docker 환경 구성 및 초기 검증 (`docker-compose up -d --build`)
- [ ] **Phase 1–5**: setup.sh 일괄 실행 (`docker-compose exec linux-practice bash /home/agent-admin/src/setup.sh`)
- [ ] **Phase 6**: 애플리케이션 실행 및 Boot Sequence 5단계 [OK] 확인 (수동)
- [ ] **Phase 7**: crontab 자동 실행 확인 (1분 후 monitor.log 라인 증가)
- [ ] **Phase 8**: 최종 검증 및 수행 내역서 작성
