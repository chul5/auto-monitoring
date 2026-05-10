# Implementation Plan - 단계별 구현 가이드

# Implementation Plan - 단계별 구현 가이드

---

## 📊 프로젝트 구현 로드맵

## 🔧 사전 설정: Ubuntu 22.04 LTS 설치 (첫 1회만 필요, 1-2시간)

이 섹션은 처음 실습 환경을 구성할 때 **한 번만** 진행하면 됩니다. 이후 Phase 0부터 시작하세요.

### 사전-1: Ubuntu 22.04 LTS 받기

**옵션 A: Docker Hub에서 다운로드 (권장)**
```bash
# 이미지 받기 (약 70MB, 첫 1회만)
docker pull ubuntu:22.04

# 확인
docker images | grep ubuntu
```

**옵션 B: 로컬에서 빌드하기**
```bash
# Dockerfile만 받아서 빌드
docker build -t ubuntu:22.04 .
```

**목표**: Ubuntu 22.04 LTS 이미지 확보

---

### 사전-2: 프로젝트 디렉토리 준비

모든 경로는 `~` (홈 디렉토리)를 기준으로 작성되어, **어느 컴퓨터에서든 동일하게 실행** 가능합니다.

```bash
# 1. 프로젝트 디렉토리 생성
mkdir -p ~/auto-monitoring/{src,logs,docs}

# 2. 현재 위치 확인
pwd
# 기대 결과: /Users/<username> (macOS) 또는 /home/<username> (Linux)

# 3. 디렉토리 구조 확인
cd ~/auto-monitoring
ls -la
tree ~/auto-monitoring  # 설치되어 있으면

# 기대 구조:
# ~/auto-monitoring/
# ├── Dockerfile              # 이 파일을 생성해야 함
# ├── docker-compose.yml      # 이 파일을 생성해야 함
# ├── src/                    # 호스트 스크립트 마운트 폴더
# ├── logs/                   # 로그 영속성 폴더
# └── docs/                   # 문서 폴더
```

**목표**: 프로젝트 디렉토리 구조 준비

---

### 사전-3: 호스트 시스템에 필수 도구 설치

**macOS의 경우:**
```bash
# OrbStack이 Docker를 제공하는지 확인
orbstack --version
# 또는
docker --version
```

**Linux의 경우:**
```bash
# Docker 설치 (Ubuntu 22.04 기준)
sudo apt-get update
sudo apt-get install -y docker.io docker-compose

# 권한 설정 (sudo 없이 docker 사용)
sudo usermod -aG docker $USER
newgrp docker
```

**목표**: 호스트 시스템 Docker 준비 완료

---

### 사전-4: 기본 커맨드라인 도구 확인

```bash
# 1. 기본 도구 확인
which curl wget git vim cat
# 또는
command -v curl wget git vim cat

# 2. 버전 확인 (선택)
docker --version
docker-compose --version
git --version

# 기대 결과 예시:
# Docker version 28.5.2
# Docker Compose version v2.40.3
# git version 2.53.0
```

**목표**: 필수 도구 준비 확인

---

### 사전-5: 계정 비밀번호 설정 (선택, SSH 테스트용)

SSH로 컨테이너에 접속할 때 비밀번호가 필요하면 미리 설정하세요.

```bash
# 호스트 OS의 현재 사용자 비밀번호 (이미 알고 있을 것)
# 또는 새로 설정하려면:
sudo passwd $USER
```

**목표**: 호스트 기본 설정 완료

---

**사전 설정 완료!** ✅ 이제 **Phase 0**으로 진행하세요.

---

### 실습 환경 선택

#### 옵션 A: Docker/OrbStack 환경 (권장)
- macOS에서 OrbStack으로 경량 Linux 컨테이너 실습
- 호스트 시스템 영향 최소
- 팀 전체 환경 재현성 최고

#### 옵션 B: VM/로컬 Linux 환경
- VirtualBox 등으로 전체 Linux 시스템 실습
- 더 실제에 가까운 경험

**이 가이드는 옵션 A (Docker/OrbStack)를 기준으로 작성됩니다.**

---

## Phase 0: Docker 환경 구성 (30분-1시간)

### 0.1 선행 요구사항 확인

```bash
# macOS 확인
uname -a

# OrbStack 설치 확인
docker --version
# 예상 결과: Docker version 28.x.x (OrbStack)

# Docker 데몬 상태 확인
docker info | head -20
```

**목표**: Docker 및 OrbStack 정상 작동 확인

---

### 0.2 프로젝트 디렉토리 구조 확인

```bash
# 프로젝트 루트: ~/auto-monitoring/ (홈 디렉토리 기준)

# 디렉토리 이동
cd ~/auto-monitoring

# 파일 구조 확인
ls -la ~/auto-monitoring

# 기대 구조:
# ~/auto-monitoring/
# ├── Dockerfile              # Ubuntu Linux 이미지 정의
# ├── docker-compose.yml      # 컨테이너 실행 설정
# ├── src/                    # 호스트 스크립트 (컨테이너에 마운트)
# │   └── setup.sh            # 자동화 스크립트 (선택)
# ├── logs/                   # 모니터링 로그 (호스트에 저장)
# ├── docs/
# │   ├── MISSION.md
# │   ├── README.md
# │   └── plan.md
# └── README.md
```

**목표**: 프로젝트 디렉토리 구조 확인

---

### 0.3 Dockerfile 작성

파일 위치: `~/auto-monitoring/Dockerfile`

```dockerfile
FROM ubuntu:22.04

# 패키지 업데이트
RUN apt-get update && apt-get install -y \
    openssh-server \
    openssh-client \
    sudo \
    curl \
    wget \
    vim \
    nano \
    net-tools \
    iproute2 \
    ufw \
    systemctl \
    python3 \
    python3-pip \
    git \
    && rm -rf /var/lib/apt/lists/*

# SSH 서버 설정
RUN mkdir -p /run/sshd
RUN mkdir -p /var/log/agent-app

# SSH 포트 20022로 변경 (보안 설정)
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

# 환경 변수 설정
RUN mkdir -p /home/agent-admin/agent-app/{bin,upload_files,api_keys}
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

# SSH 포트 노출
EXPOSE 20022 15034

# SSH 서버 시작
CMD ["/usr/sbin/sshd", "-D"]
```

**목표**: Ubuntu 기반 Linux 실습 이미지 정의

---

### 0.4 docker-compose.yml 작성

파일 위치: `~/auto-monitoring/docker-compose.yml`

```yaml
version: '3.8'

services:
  linux-practice:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: auto-monitoring-lab
    image: auto-monitoring:latest
    
    # 포트 매핑
    ports:
      - "20022:20022"    # SSH 포트
      - "15034:15034"    # 애플리케이션 포트
    
    # 볼륨 마운트
    volumes:
      - ./src:/home/agent-admin/src      # 호스트 스크립트
      - ./logs:/var/log/agent-app        # 로그 영속성
    
    # 환경 변수
    environment:
      - AGENT_HOME=/home/agent-admin/agent-app
      - AGENT_PORT=15034
      - AGENT_LOG_DIR=/var/log/agent-app
    
    # 옵션
    privileged: true                      # systemctl 사용
    stdin_open: true
    tty: true
    
    # 복구 정책
    restart: unless-stopped
```

**목표**: 컨테이너 실행 설정 완성

---

### 0.5 이미지 빌드 및 컨테이너 실행

```bash
# 1. 컨테이너 빌드 및 실행
cd ~/auto-monitoring
docker-compose up -d --build

# 2. 빌드 진행 상황 확인
# "Successfully built auto-monitoring:latest" 출력될 때까지 대기

# 3. 컨테이너 상태 확인
docker-compose ps

# 기대 결과:
# NAME                   IMAGE                    STATUS
# auto-monitoring-lab    auto-monitoring:latest   Up ...

# 4. 컨테이너 로그 확인 (SSH 서버 시작 확인)
docker-compose logs linux-practice

# 기대 결과:
# Server listening on 0.0.0.0 port 20022.
```

**목표**: 컨테이너 정상 실행 확인

---

### 0.6 컨테이너 접속

```bash
# 1. 컨테이너 bash 접속
docker-compose exec linux-practice bash

# 2. 컨테이너 내부에서 확인
root@<container-id>:/#

# 3. 계정 확인
id agent-admin
# 기대 결과: 
# uid=1001(agent-admin) gid=1002(agent-common) groups=1002(agent-common),1003(agent-core),27(sudo)

# 4. SSH 포트 확인
grep "^Port" /etc/ssh/sshd_config
# 기대 결과: Port 20022

# 5. 환경 변수 확인
echo $AGENT_HOME
# 기대 결과: /home/agent-admin/agent-app
```

**목표**: 컨테이너 환경 초기 설정 확인

---

### 0.7 호스트에서 SSH 접속 테스트 (선택)

```bash
# 호스트 터미널에서 (컨테이너는 실행 중)
ssh -p 20022 agent-admin@localhost

# 비밀번호 입력 (Dockerfile에서 설정 안 함, 테스트 시 키 기반 인증 권장)
# 또는 SSH 키 설정

# 접속 후 확인
whoami
# 기대 결과: agent-admin

exit  # 접속 해제
```

**목표**: 호스트에서 컨테이너 SSH 접속 확인

---

## Phase 1: 컨테이너 내 초기 검증 (15분) - 컨테이너 내에서 진행

### 1.1 컨테이너 환경 검증

Dockerfile에서 이미 설정된 내용을 확인합니다.

```bash
# 컨테이너 접속 (호스트에서)
cd ~/auto-monitoring
docker-compose exec linux-practice bash

# 컨테이너 내에서:

# 1. 시스템 정보 확인
uname -a
cat /etc/os-release

# 2. SSH 설정 확인 (Dockerfile에서 설정됨)
sudo grep -E "^Port|^PermitRootLogin" /etc/ssh/sshd_config
# 기대 결과:
# Port 20022
# PermitRootLogin no

# 3. 계정 확인 (Dockerfile에서 생성됨)
id agent-admin
id agent-dev
id agent-test
# 기대 결과: 
# uid=1001(agent-admin) gid=1002(agent-common) groups=1002(agent-common),1003(agent-core)
# uid=1002(agent-dev) gid=1002(agent-common) groups=1002(agent-common),1003(agent-core)
# uid=1003(agent-test) gid=1002(agent-common) groups=1002(agent-common)

# 4. 디렉토리 구조 확인 (Dockerfile에서 생성됨)
ls -la ~/agent-app
tree ~/agent-app  # 설치되어 있으면

# 기대 결과:
# ~/agent-app/
# ├── bin/
# ├── upload_files/
# └── api_keys/

# 5. 환경 변수 확인 (Dockerfile에서 설정됨)
echo "AGENT_HOME=$AGENT_HOME"
echo "AGENT_PORT=$AGENT_PORT"
echo "AGENT_LOG_DIR=$AGENT_LOG_DIR"

# 6. 방화벽 상태 확인
sudo ufw status
# 기대 결과: Status: inactive (컨테이너이므로 일반적으로 비활성)
```

**목표**: Dockerfile에서 설정된 사항 검증 완료

---

## Phase 2 ~ Phase 10: 리눅스 실습 진행

컨테이너 내에서 다음 단계를 순차적으로 진행합니다.

- **Phase 2**: SSH 포트 변경 및 Root 로그인 차단 (이미 Dockerfile에서 설정됨)
- **Phase 3**: 계정 및 그룹 관리 (이미 Dockerfile에서 생성됨)
- **Phase 4**: 디렉토리 구조 및 권한 관리 (이미 Dockerfile에서 설정됨)
- **Phase 5**: 환경 변수 설정
- **Phase 6**: API 키 파일 생성
- **Phase 7**: 애플리케이션 배포 및 실행
- **Phase 8**: Monitor.sh 스크립트 개발
- **Phase 9**: Crontab 자동화 설정
- **Phase 10**: 최종 검증 및 문서화

### 실행 방법

```bash
# 1. 호스트에서 컨테이너 내 bash 접속
cd ~/auto-monitoring
docker-compose exec linux-practice bash

# 2. 컨테이너 내에서 agent-admin 사용자로 전환
su - agent-admin

# 3. Phase 2부터 진행 (또는 이미 검증되었으므로 Phase 5부터 시작)
source /etc/profile.d/agent-app.sh
echo "환경 변수 확인: $AGENT_HOME"

# 4. Phase 5 ~ 10 진행
# (상세 내용은 아래 참고)
```

---

## Phase 2: 기본 보안 설정 (1-2시간)

### 2.1 SSH 포트 변경 및 Root 로그인 차단

```bash
# SSH 설정 파일 수정
sudo vi /etc/ssh/sshd_config
```

**변경 항목:**
```
# 라인 찾아서 수정 (또는 새로 추가)
Port 20022
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication yes
```

**이후 SSH 데몬 재시작:**
```bash
# 설정 문법 검증 (필수!)
sudo sshd -t

# 정상이면 재시작
sudo systemctl restart sshd
# 또는
sudo service ssh restart
```

**검증:**
```bash
# 포트 리스닝 상태 확인
sudo ss -tulnp | grep sshd
# 또는
sudo netstat -tulnp | grep sshd

# 예상 결과: 
# tcp  0  0 0.0.0.0:20022  0.0.0.0:*  LISTEN  <pid>/sshd

# 설정 파일에서 확인
sudo grep -E "^Port|^PermitRootLogin" /etc/ssh/sshd_config
```

**목표**: SSH 포트 20022, Root 원격 로그인 차단 설정 완료

---

### 2.2 방화벽 설정 (UFW 선택)

```bash
# UFW 상태 확인
sudo ufw status

# UFW가 미설치된 경우 설치
sudo apt update && sudo apt install -y ufw

# UFW 기본 정책 설정 (기본값: Deny Incoming, Allow Outgoing)
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 필요한 포트 개방 (순서 중요!)
sudo ufw allow 20022/tcp      # SSH
sudo ufw allow 15034/tcp      # APP

# UFW 활성화 (활성화 전에 SSH 접속이 안될 수 있으니 주의!)
# 활성화 후 SSH로 접속할 수 없을 수 있으므로, 로컬 콘솔에서 실행 권장
sudo ufw enable

# 활성화 확인
sudo ufw status
sudo ufw status verbose
```

**검증:**
```bash
# UFW 상태 확인
sudo ufw status numbered

# 기대 결과:
# To  Action  From
# --  ------  ----
# 20022/tcp  ALLOW IN  Anywhere
# 15034/tcp  ALLOW IN  Anywhere

# 포트 리스닝 상태 확인
sudo ss -tulnp | grep -E "20022|15034"
```

**목표**: UFW 방화벽 활성화, SSH(20022)와 APP(15034) 포트만 개방

**주의사항**:
- ⚠️ UFW 활성화 전에 SSH 포트(20022)가 허용되어 있는지 **반드시 확인**
- ⚠️ 원격에서 작업 중인 경우, UFW 활성화 후 SSH 접속이 끊길 수 있음
- 💡 로컬 콘솔에서 작업하는 것이 안전함

---

## Phase 3: 계정 및 그룹 관리 (30-45분)

### 3.1 그룹 생성

```bash
# agent-common 그룹 생성 (일반 공유 자원)
sudo groupadd agent-common

# agent-core 그룹 생성 (보안 자원)
sudo groupadd agent-core

# 생성 확인
getent group | grep agent
```

**목표**: agent-common, agent-core 그룹 생성 완료

---

### 3.2 계정 생성 및 그룹 설정

```bash
# agent-admin 생성 (운영/관리, cron 실행자)
sudo useradd -m -s /bin/bash -g agent-common agent-admin
sudo usermod -a -G agent-core agent-admin

# agent-dev 생성 (개발/운영, monitor.sh 작성자)
sudo useradd -m -s /bin/bash -g agent-common agent-dev
sudo usermod -a -G agent-core agent-dev

# agent-test 생성 (QA/테스트)
sudo useradd -m -s /bin/bash -g agent-common agent-test

# 생성 확인
id agent-admin
id agent-dev
id agent-test

# 기대 결과 예시:
# uid=1001(agent-admin) gid=1002(agent-common) groups=1002(agent-common),1003(agent-core)
# uid=1002(agent-dev) gid=1002(agent-common) groups=1002(agent-common),1003(agent-core)
# uid=1003(agent-test) gid=1002(agent-common) groups=1002(agent-common)
```

**목표**: 3개 계정 생성, 그룹 멤버십 설정 완료

---

## Phase 4: 디렉토리 구조 및 권한 관리 (1-2시간)

### 4.1 디렉토리 구조 생성

```bash
# 기본 디렉토리 구조 생성
AGENT_HOME=/home/agent-admin/agent-app
mkdir -p $AGENT_HOME/{bin,upload_files,api_keys}
mkdir -p /var/log/agent-app

# 생성 확인
tree $AGENT_HOME
# 또는
find $AGENT_HOME -type d
```

**목표**: $AGENT_HOME 디렉토리 구조 생성

---

### 4.2 권한 설정 (핵심!)

#### a) upload_files 디렉토리 (공개, agent-common 그룹 R/W)

```bash
# 소유자 및 그룹 변경
sudo chown -R agent-admin:agent-common $AGENT_HOME/upload_files

# 권한 설정: 770 (rwxrwx---)
# - 소유자: 읽기, 쓰기, 실행
# - 그룹: 읽기, 쓰기, 실행
# - 기타: 권한 없음
sudo chmod 770 $AGENT_HOME/upload_files

# 검증
ls -ld $AGENT_HOME/upload_files
# 기대 결과: drwxrwx--- <num> agent-admin agent-common
```

#### b) api_keys 디렉토리 (보안, agent-core 그룹 R/W)

```bash
# 소유자 및 그룹 변경
sudo chown -R agent-dev:agent-core $AGENT_HOME/api_keys

# 권한 설정: 770 (rwxrwx---)
sudo chmod 770 $AGENT_HOME/api_keys

# 검증
ls -ld $AGENT_HOME/api_keys
# 기대 결과: drwxrwx--- <num> agent-dev agent-core
```

#### c) /var/log/agent-app 디렉토리 (보안, agent-core 그룹 R/W)

```bash
# 소유자 및 그룹 변경
sudo chown -R agent-admin:agent-core /var/log/agent-app

# 권한 설정: 770 (rwxrwx---)
sudo chmod 770 /var/log/agent-app

# 검증
ls -ld /var/log/agent-app
# 기대 결과: drwxrwx--- <num> agent-admin agent-core
```

### 4.3 권한 검증 스크립트

```bash
#!/bin/bash
# 권한 설정 검증 (verify-permissions.sh)

AGENT_HOME=/home/agent-admin/agent-app

echo "=== 권한 설정 검증 ==="
echo ""

echo "1. upload_files (agent-common 그룹 R/W)"
ls -ld $AGENT_HOME/upload_files
getfacl $AGENT_HOME/upload_files 2>/dev/null || echo "(ACL 미설정)"
echo ""

echo "2. api_keys (agent-core 그룹 R/W)"
ls -ld $AGENT_HOME/api_keys
getfacl $AGENT_HOME/api_keys 2>/dev/null || echo "(ACL 미설정)"
echo ""

echo "3. /var/log/agent-app (agent-core 그룹 R/W)"
ls -ld /var/log/agent-app
getfacl /var/log/agent-app 2>/dev/null || echo "(ACL 미설정)"
echo ""

echo "=== 계정 소속 확인 ==="
id agent-admin
id agent-dev
id agent-test
```

**목표**: 디렉토리 소유자, 그룹, 권한 설정 완료

---

## Phase 5: 환경 변수 설정 (30분)

### 5.1 환경 변수 파일 생성

```bash
# 환경 변수 파일 생성
cat > /etc/profile.d/agent-app.sh << 'EOF'
# Agent App Environment Variables
export AGENT_HOME=/home/agent-admin/agent-app
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys/t_secret.key
export AGENT_LOG_DIR=/var/log/agent-app
EOF

# 실행 권한 부여
sudo chmod 644 /etc/profile.d/agent-app.sh

# 환경 변수 로드 (현재 세션에 적용)
source /etc/profile.d/agent-app.sh

# 또는 재로그인 후 확인
env | grep AGENT
```

**목표**: 환경 변수 설정 완료

---

### 5.2 각 계정의 .bashrc에 환경 변수 추가 (선택)

```bash
# agent-admin 계정
echo "source /etc/profile.d/agent-app.sh" >> /home/agent-admin/.bashrc

# agent-dev 계정
echo "source /etc/profile.d/agent-app.sh" >> /home/agent-dev/.bashrc

# agent-test 계정
echo "source /etc/profile.d/agent-app.sh" >> /home/agent-test/.bashrc
```

---

## Phase 6: API 키 파일 생성 (15분)

### 6.1 API 키 파일 생성

```bash
# API 키 파일 생성
AGENT_HOME=/home/agent-admin/agent-app
echo "agent_api_key_test" | sudo tee $AGENT_HOME/api_keys/t_secret.key > /dev/null

# 권한 설정: 600 (rw-------)
sudo chmod 600 $AGENT_HOME/api_keys/t_secret.key

# 소유자 및 그룹 변경
sudo chown agent-dev:agent-core $AGENT_HOME/api_keys/t_secret.key

# 검증
ls -l $AGENT_HOME/api_keys/t_secret.key
# 기대 결과: -rw------- <num> agent-dev agent-core <size> <date> t_secret.key

# 내용 확인 (agent-dev 또는 agent-admin으로)
sudo cat $AGENT_HOME/api_keys/t_secret.key
# 기대 결과: agent_api_key_test
```

**목표**: API 키 파일 생성 및 권한 설정 완료

---

## Phase 7: 애플리케이션 배포 및 실행 (1-2시간)

### 7.1 애플리케이션 파일 배치

```bash
# 제공 Python 앱 복사 (예: agent_app.py)
# agent_app.py를 $AGENT_HOME에 배치

cp agent_app.py $AGENT_HOME/

# 실행 권한 부여
chmod +x $AGENT_HOME/agent_app.py

# 검증
ls -la $AGENT_HOME/agent_app.py
```

### 7.2 애플리케이션 실행

```bash
# 로그인: agent-admin 또는 agent-dev 계정 (루트 금지!)
su - agent-admin

# 환경 변수 로드
source /etc/profile.d/agent-app.sh

# 애플리케이션 시작
cd $AGENT_HOME
python3 agent_app.py

# 기대 결과:
# [OK] Boot sequence step 1: ...
# [OK] Boot sequence step 2: ...
# [OK] Boot sequence step 3: ...
# [OK] Boot sequence step 4: ...
# [OK] Boot sequence step 5: ...
# Agent READY
```

### 7.3 포트 리스닝 확인 (다른 터미널)

```bash
# 포트 15034 리스닝 확인
sudo ss -tulnp | grep 15034
# 또는
sudo netstat -tulnp | grep 15034

# 기대 결과:
# tcp  0  0 0.0.0.0:15034  0.0.0.0:*  LISTEN  <pid>/python3

# curl로 연결 확인 (선택)
curl http://localhost:15034/
```

**목표**: 애플리케이션 정상 부팅 및 포트 리스닝 확인

---

## Phase 8: Monitor.sh 스크립트 개발 (2-3시간)

### 8.1 Monitor.sh 작성 계획

**파일 위치**: `$AGENT_HOME/bin/monitor.sh`
**소유자**: agent-dev
**그룹**: agent-core
**권한**: 750 (rwxr-x---)

**스크립트 구조:**

```bash
#!/bin/bash
set -euo pipefail

# =============================================================================
# Monitor.sh: Agent App System Monitoring Script
# Purpose: Collect system health metrics and log monitoring data
# =============================================================================

# ===== 1. 환경 변수 로드 =====
source /etc/profile.d/agent-app.sh

# ===== 2. 변수 정의 =====
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="${AGENT_LOG_DIR}/monitor.log"

# ===== 3. 함수 정의 =====

# Health Check 함수들
check_process() {
    if pgrep -f "agent_app.py" > /dev/null; then
        return 0
    else
        return 1
    fi
}

check_port() {
    if ss -tulnp | grep -q ":${AGENT_PORT}.*LISTEN"; then
        return 0
    else
        return 1
    fi
}

# Warning Check 함수
check_firewall() {
    if sudo ufw status | grep -q "Status: active"; then
        return 0
    else
        return 1
    fi
}

# 자원 수집 함수들
get_cpu_usage() {
    # CPU 사용률 수집 (%)
    top -bn1 | grep "Cpu(s)" | awk '{print $2}'
}

get_memory_usage() {
    # 메모리 사용률 수집 (%)
    free | grep Mem | awk '{printf("%.2f", $3/$2 * 100.0)}'
}

get_disk_usage() {
    # 디스크 사용률 수집 (%)
    df $AGENT_HOME | tail -1 | awk '{print $5}'
}

get_network_status() {
    # 네트워크 연결 상태 수집
    ss -s | grep -E "TCP:|UDP:" | head -2
}

get_active_processes() {
    # 활성 프로세스 수
    ps aux | wc -l
}

# ===== 4. Health Check (실패 시 exit 1) =====

# 프로세스 확인
if ! check_process; then
    echo "[ERROR] ${TIMESTAMP} | Process agent_app.py is not running" >> "$LOG_FILE"
    exit 1
fi

# 포트 확인
if ! check_port; then
    echo "[ERROR] ${TIMESTAMP} | Port ${AGENT_PORT}/tcp is not LISTEN" >> "$LOG_FILE"
    exit 1
fi

# ===== 5. Warning Check (경고만 출력, 계속 진행) =====

# 방화벽 확인
if ! check_firewall; then
    echo "[WARNING] ${TIMESTAMP} | Firewall is not active" >> "$LOG_FILE"
fi

# ===== 6. 자원 수집 및 로깅 =====

CPU_USAGE=$(get_cpu_usage)
MEMORY_USAGE=$(get_memory_usage)
DISK_USAGE=$(get_disk_usage)
PROCESS_COUNT=$(get_active_processes)

# 로그 기록
log_entry="[OK] ${TIMESTAMP} | CPU: ${CPU_USAGE} | Memory: ${MEMORY_USAGE}% | Disk: ${DISK_USAGE} | Process: ${PROCESS_COUNT}"
echo "$log_entry" >> "$LOG_FILE"

# 네트워크 상태도 함께 기록 (선택)
# echo "[INFO] ${TIMESTAMP} | Network Status:" >> "$LOG_FILE"
# get_network_status >> "$LOG_FILE"

echo "Monitoring completed at ${TIMESTAMP}"
exit 0
```

### 8.2 Monitor.sh 배치 및 권한 설정

```bash
# monitor.sh 파일 생성
mkdir -p $AGENT_HOME/bin
cat > $AGENT_HOME/bin/monitor.sh << 'EOF'
# (위의 스크립트 내용 붙여넣기)
EOF

# 실행 권한 부여
chmod 750 $AGENT_HOME/bin/monitor.sh

# 소유자 및 그룹 변경
sudo chown agent-dev:agent-core $AGENT_HOME/bin/monitor.sh

# 검증
ls -la $AGENT_HOME/bin/monitor.sh
# 기대 결과: -rwxr-x--- <num> agent-dev agent-core <size> <date> monitor.sh
```

### 8.3 Monitor.sh 테스트

```bash
# 로그인: agent-admin 계정
su - agent-admin

# 스크립트 실행 가능한지 확인
$AGENT_HOME/bin/monitor.sh

# 로그 확인
tail -5 $AGENT_LOG_DIR/monitor.log
```

**목표**: Monitor.sh 스크립트 정상 작동 및 로그 생성 확인

---

## Phase 9: Crontab 자동화 설정 (30-45분)

### 9.1 Crontab 등록

```bash
# agent-admin 계정으로 로그인
su - agent-admin

# Crontab 편집
crontab -e

# 다음 라인 추가 (매분 실행)
* * * * * /home/agent-admin/agent-app/bin/monitor.sh >> /var/log/agent-app/monitor.log 2>&1

# 저장 및 종료 (vi 에디터 기준)
# ESC -> :wq -> Enter
```

### 9.2 Crontab 검증

```bash
# 등록된 crontab 확인
crontab -l
# 기대 결과:
# * * * * * /home/agent-admin/agent-app/bin/monitor.sh >> /var/log/agent-app/monitor.log 2>&1

# Crontab 데몬 상태 확인
sudo systemctl status cron
# 또는
sudo service cron status

# Crontab 로그 확인 (1분 대기 후 로그 증가 여부 확인)
# 초기 로그 라인 수 저장
tail -20 /var/log/agent-app/monitor.log > /tmp/monitor_before.txt

# 1분 이상 대기
sleep 70

# 로그 다시 확인 (로그가 증가했는지 확인)
tail -20 /var/log/agent-app/monitor.log > /tmp/monitor_after.txt
diff /tmp/monitor_before.txt /tmp/monitor_after.txt
# 로그 라인이 증가했으면 성공!
```

**목표**: Crontab 자동 실행 확인

---

## Phase 10: 최종 검증 및 문서화 (1-2시간)

### 10.1 최종 검증 체크리스트

```bash
#!/bin/bash
# final-verification.sh - 최종 검증 스크립트

echo "========== Final Verification Checklist =========="
echo ""

# 1. SSH 설정 확인
echo "1. SSH Configuration:"
sudo grep -E "^Port|^PermitRootLogin" /etc/ssh/sshd_config
echo ""

# 2. SSH 포트 리스닝 확인
echo "2. SSH Port Listening:"
sudo ss -tulnp | grep sshd
echo ""

# 3. 방화벽 상태 확인
echo "3. Firewall Status:"
sudo ufw status verbose
echo ""

# 4. 계정 및 그룹 확인
echo "4. User Accounts:"
id agent-admin
id agent-dev
id agent-test
echo ""

# 5. 디렉토리 권한 확인
echo "5. Directory Permissions:"
ls -ld /home/agent-admin/agent-app
ls -ld /home/agent-admin/agent-app/{bin,upload_files,api_keys}
ls -ld /var/log/agent-app
echo ""

# 6. API 키 파일 확인
echo "6. API Key File:"
ls -la /home/agent-admin/agent-app/api_keys/t_secret.key
echo ""

# 7. 포트 리스닝 확인
echo "7. Application Port (15034):"
sudo ss -tulnp | grep 15034
echo ""

# 8. Monitor.sh 권한 확인
echo "8. Monitor.sh Permissions:"
ls -la /home/agent-admin/agent-app/bin/monitor.sh
echo ""

# 9. Monitor 로그 확인
echo "9. Monitor Log:"
tail -10 /var/log/agent-app/monitor.log
echo ""

# 10. Crontab 확인
echo "10. Crontab (agent-admin):"
sudo crontab -u agent-admin -l
echo ""

echo "========== End of Verification =========="
```

### 10.2 요구사항 수행 내역서 작성

문서에 포함할 내용:
- SSH 설정 변경 내역
- 방화벽 규칙 설정
- 계정/그룹 생성 명령어
- 디렉토리 구조 및 권한 설정
- 환경 변수 설정
- API 키 파일 생성
- 애플리케이션 부팅 로그
- Monitor.sh 실행 결과
- Monitor 로그 누적 기록
- Crontab 자동 실행 확인 증거

**목표**: 모든 요구사항 완료 및 증거 자료 수집

---

## 📋 구현 진행 체크리스트

### Phase별 완료 확인

- [ ] **Phase 1**: 환경 준비 및 사전 검증
- [ ] **Phase 2**: 기본 보안 설정 (SSH 포트 변경, Root 차단, UFW 방화벽)
- [ ] **Phase 3**: 계정 및 그룹 관리
- [ ] **Phase 4**: 디렉토리 구조 및 권한 설정
- [ ] **Phase 5**: 환경 변수 설정
- [ ] **Phase 6**: API 키 파일 생성
- [ ] **Phase 7**: 애플리케이션 배포 및 실행
- [ ] **Phase 8**: Monitor.sh 스크립트 개발
- [ ] **Phase 9**: Crontab 자동화 설정
- [ ] **Phase 10**: 최종 검증 및 문서화

---

## 🚨 주의사항 및 트러블슈팅

### 일반 주의사항

1. **UFW 활성화 전 주의**
   - UFW 활성화 전에 SSH 포트(20022)를 허용해야 함
   - 활성화 후 SSH 접속이 끊기면 로컬 콘솔에서만 복구 가능

2. **권한 설정 검증**
   - `ls -l` 및 `getfacl`로 권한 확인
   - 소유자, 그룹, 권한이 정확히 설정되었는지 확인

3. **환경 변수 로드**
   - 계정 전환 후 환경 변수가 로드되지 않으면 수동으로 소싱
   - `source /etc/profile.d/agent-app.sh`

4. **Crontab 경로**
   - Crontab에서는 절대 경로 사용 필수
   - 환경 변수 로드: `source /etc/profile.d/agent-app.sh && ...`

### 트러블슈팅

#### Q1: SSH 포트 변경 후 연결 불가
```bash
# 해결: 로컬 콘솔에서 원본 설정으로 복원
sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
sudo systemctl restart sshd
```

#### Q2: UFW 활성화 후 SSH 연결 불가
```bash
# 해결: 로컬 콘솔에서 SSH 포트 허용 추가
sudo ufw allow 20022/tcp
sudo ufw reload
```

#### Q3: Monitor.sh 권한 오류
```bash
# 해결: agent-admin 또는 agent-dev 계정에서만 실행 가능
# Crontab 실행: agent-admin 계정 사용
su - agent-admin
crontab -e  # 등록
```

#### Q4: 로그 파일 쓰기 불가
```bash
# 해결: 로그 디렉토리 권한 및 소유자 확인
ls -ld /var/log/agent-app
sudo chmod 770 /var/log/agent-app
sudo chown agent-admin:agent-core /var/log/agent-app
```

#### Q5: 환경 변수 인식 안 됨
```bash
# 해결: Crontab에서 명시적으로 로드
* * * * * source /etc/profile.d/agent-app.sh && /home/agent-admin/agent-app/bin/monitor.sh
```

---

## 📈 예상 소요 시간

| Phase | 작업 | 예상 시간 |
|-------|------|---------|
| 1 | 환경 준비 | 1-2시간 |
| 2 | 기본 보안 설정 | 1-2시간 |
| 3 | 계정/그룹 관리 | 30-45분 |
| 4 | 디렉토리/권한 | 1-2시간 |
| 5 | 환경 변수 | 30분 |
| 6 | API 키 파일 | 15분 |
| 7 | 애플리케이션 배포 | 1-2시간 |
| 8 | Monitor.sh 개발 | 2-3시간 |
| 9 | Crontab 설정 | 30-45분 |
| 10 | 최종 검증 | 1-2시간 |
| **총 소요 시간** | | **9-16시간** |

---

## ✅ 성공 기준

모든 요구사항이 완료되고 다음 증거 자료가 수집되었을 때:

1. ✅ SSH 포트 20022, Root 로그인 차단 설정 확인
2. ✅ UFW 활성화, SSH(20022)/APP(15034) 포트 개방 확인
3. ✅ 3개 계정(agent-admin, agent-dev, agent-test) 생성 확인
4. ✅ 2개 그룹(agent-common, agent-core) 생성 확인
5. ✅ 디렉토리 권한 및 소유자 설정 확인
6. ✅ 애플리케이션 부팅 5단계 [OK] 및 "Agent READY" 출력
7. ✅ 포트 15034 LISTEN 상태 확인
8. ✅ Monitor.sh 정상 실행 및 로그 생성
9. ✅ Monitor 로그 누적 기록 확인 (최근 라인)
10. ✅ Crontab 자동 실행 확인 (1분 후 로그 증가)

---

**프로젝트 완료 시점**: 위의 모든 성공 기준이 충족되었을 때
