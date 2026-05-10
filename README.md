# Auto Monitoring - 자동화된 서버 모니터링 시스템

## 📋 프로젝트 소개

**Auto Monitoring**은 Linux 서버 운영 환경에서 **보안 설정**, **권한 관리**, **시스템 모니터링**을 통합적으로 자동화하는 프로젝트입니다. 

실제 서버 장애 시 로그가 없으면 원인 분석이 어려워집니다. 이 프로젝트는 사전에 필요한 모니터링 인프라를 구축하여, 시스템 상태를 지속적으로 수집하고 기록하는 엔지니어링 역량을 갖추는 것을 목표로 합니다.

---

## 🎯 핵심 목표

- ✅ SSH 포트 변경 및 Root 원격 접속 차단으로 기본 보안 구성
- ✅ UFW 방화벽으로 필요한 포트만 개방(SSH 20022, APP 15034)
- ✅ 역할 기반 계정/그룹과 ACL을 통한 권한 분리
- ✅ 환경 변수로 실행 환경 표준화
- ✅ Shell 스크립트로 프로세스/포트/리소스 상태 자동 수집
- ✅ Crontab으로 주기적 모니터링 자동화

---

## 📦 최종 산출물

### 1. 요구사항 수행 내역서 (문서)
- 설정/명령어 기록
- 필수 증거 자료 체크리스트
  - SSH 설정 확인
  - 방화벽 규칙 확인
  - 계정/그룹 생성 확인
  - 디렉토리 구조 및 권한 확인
  - 앱 부팅 시퀀스 확인
  - 모니터링 로그 확인
  - Crontab 등록 확인

### 2. 자동화 스크립트 소스코드
- `monitor.sh`: 시스템 상태 수집 및 로깅 스크립트

---

## 🔧 시스템 구성 요소

### 1. 기본 보안 설정
| 항목 | 설정값 | 목적 |
|------|-------|------|
| SSH 포트 | 20022 | 기본 포트 차단 |
| Root 원격 로그인 | 차단 | 직접 루트 접속 방지 |

### 2. 방화벽 설정
| 포트 | 프로토콜 | 용도 |
|------|---------|------|
| 20022 | TCP | SSH 원격 접속 |
| 15034 | TCP | 애플리케이션 서비스 |

### 3. 계정 및 그룹 체계

**계정:**
- `agent-admin`: 운영/관리 담당
- `agent-dev`: 개발/운영 담당
- `agent-test`: QA/테스트 담당

**그룹:**
- `agent-common`: 일반 공유 자원 접근 (admin, dev, test)
- `agent-core`: 보안 자원 접근 (admin, dev만)

### 4. 디렉토리 구조 및 권한

```
$AGENT_HOME (예: /home/agent-admin/agent-app)
├── upload_files/       (공개, agent-common 그룹 R/W)
├── api_keys/           (보안, agent-core 그룹 R/W)
│   └── t_secret.key    (API 키)
└── bin/
    └── monitor.sh      (모니터링 스크립트)

/var/log/agent-app/     (보안, agent-core 그룹 R/W)
└── monitor.log         (모니터링 로그)
```

### 5. 환경 변수
```bash
AGENT_HOME=/home/agent-admin/agent-app
AGENT_PORT=15034
AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
AGENT_KEY_PATH=$AGENT_HOME/api_keys/t_secret.key
AGENT_LOG_DIR=/var/log/agent-app
```

---

## 📊 Monitor.sh 기능

### Health Check (실패 시 종료)
1. **프로세스 확인**: agent_app.py 실행 여부 검증
2. **포트 확인**: TCP 15034 LISTEN 상태 검증

### 상태 점검 (경고만 출력)
1. **방화벽 확인**: UFW/firewalld 활성화 상태 점검

### 자원 수집 (로그 기록)
1. CPU 사용률(%)
2. 메모리 사용률(%)
3. 디스크 사용률(%)
4. 네트워크 연결 상태
5. 활성 프로세스 목록

---

## � Docker/OrbStack 환경 설정

### 선행 요구사항

- **macOS**: Apple Silicon 또는 Intel CPU
- **OrbStack**: macOS에서 Docker Desktop 대체 경량 가상화 도구
  - [OrbStack 설치](https://orbstack.dev)
  - OrbStack 시작 확인: `docker version`

### Docker 환경에서 실습하기

본 프로젝트는 **컨테이너 기반 Linux 실습 환경**에서 진행할 수 있습니다.

#### Step 0: Docker 설치 및 확인
```bash
# Docker 버전 확인
docker --version
# 예상 결과: Docker version 28.x.x

# Docker 데몬 상태 확인
docker info | grep "Operating System"
# 예상 결과: Operating System: OrbStack
```

#### Step 1: 프로젝트 디렉토리 구조
```
auto-monitoring/
├── Dockerfile              # Ubuntu 기반 Linux 실습 이미지
├── docker-compose.yml      # 컨테이너 실행 설정
├── src/                    # 실습용 스크립트 (plan.md 기반)
│   └── setup.sh            # 자동화 설정 스크립트
└── README.md
```

#### Step 2: Dockerfile 작성

[Dockerfile](Dockerfile) - Ubuntu 기반 Linux 환경 이미지
```dockerfile
FROM ubuntu:22.04

# 기본 패키지 설치
RUN apt-get update && apt-get install -y \
    openssh-server \
    sudo \
    curl \
    wget \
    vim \
    net-tools \
    iproute2 \
    ufw \
    systemctl \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# SSH 설정
RUN mkdir -p /run/sshd
RUN echo 'PermitRootLogin no' >> /etc/ssh/sshd_config
RUN echo 'Port 20022' >> /etc/ssh/sshd_config

# 일반 사용자 생성
RUN useradd -m -s /bin/bash agent-admin

# SSH 시작
EXPOSE 20022 15034
CMD ["/usr/sbin/sshd", "-D"]
```

#### Step 3: docker-compose.yml 작성

[docker-compose.yml](docker-compose.yml)
```yaml
version: '3.8'

services:
  linux-practice:
    build: .
    container_name: auto-monitoring-lab
    ports:
      - "20022:20022"    # SSH 포트
      - "15034:15034"    # App 포트
    volumes:
      - ./src:/home/agent-admin/src    # 스크립트 마운트
      - ./logs:/var/log/agent-app      # 로그 영속성
    environment:
      - AGENT_HOME=/home/agent-admin/agent-app
      - AGENT_PORT=15034
      - AGENT_LOG_DIR=/var/log/agent-app
    privileged: true  # systemctl 사용을 위해 필요
    stdin_open: true
    tty: true
```

#### Step 4: 컨테이너 실행

```bash
# 이미지 빌드 및 컨테이너 실행
docker-compose up -d

# 컨테이너 상태 확인
docker-compose ps
# 예상 결과:
# NAME                   IMAGE                    STATUS
# auto-monitoring-lab    auto-monitoring:latest   Up ...

# 컨테이너 접속
docker-compose exec linux-practice bash

# 컨테이너 내에서 실습 시작
su - agent-admin
cd ~/src
source ../setup.sh
```

#### Step 5: 컨테이너 내 실습

컨테이너 내에서 plan.md의 **Phase 2 ~ Phase 10**을 순차적으로 진행합니다.

```bash
# SSH 설정 확인
sudo grep -E "^Port|^PermitRootLogin" /etc/ssh/sshd_config

# 계정 생성 및 권한 설정 (Phase 3, 4 진행)
# ...

# 모니터링 스크립트 개발 (Phase 8)
# ...
```

#### Step 6: 컨테이너 종료 및 정리

```bash
# 컨테이너 종료 (데이터 유지)
docker-compose down

# 컨테이너 및 볼륨 완전 삭제
docker-compose down -v

# 재실습 시 (이미지 캐시 사용)
docker-compose up -d
```

### 📝 Docker 환경의 장점

| 항목 | 설명 |
|------|------|
| **격리성** | 호스트 시스템 영향 없음 |
| **재현성** | 팀 모두 동일한 환경 제공 |
| **빠른 초기화** | 한 번의 `docker-compose up` |
| **볼륨 관리** | 호스트-컨테이너 파일 동기화 |
| **빠른 정리** | `docker-compose down -v`로 완전 초기화 |

### ⚠️ Docker 환경 주의사항

1. **루트 권한**
   - 컨테이너에서 `sudo`가 필요한 작업 (firewall, ssh 설정)
   - 실습용이므로 권한 제한 최소화

2. **SSH 포트**
   - 호스트: `localhost:20022` → 컨테이너: `22` 매핑
   - `ssh -p 20022 agent-admin@localhost`

3. **로그 영속성**
   - `./logs` 디렉토리에 모니터링 로그 누적
   - 호스트에서 `tail -f logs/monitor.log`로 실시간 확인

---

## � Docker/OrbStack 환경 설정 (모든 경로는 `~` 기반)

### 선행 요구사항

- **macOS**: Apple Silicon 또는 Intel CPU + OrbStack
- **Linux**: Docker 및 Docker Compose 설치
- **OrbStack (macOS)**: [orbstack.dev](https://orbstack.dev)에서 설치
  - OrbStack이 Docker를 제공합니다
  - 확인: `docker version`

### 🚀 빠른 시작

모든 경로는 홈 디렉토리(`~`)를 기준으로 작성되어 **어느 컴퓨터에서든 동일하게 실행** 가능합니다.

```bash
# 1. 프로젝트 디렉토리로 이동
cd ~/auto-monitoring

# 2. Ubuntu 22.04 이미지 다운로드 (첫 1회만)
docker pull ubuntu:22.04

# 3. 컨테이너 빌드 및 실행
docker-compose up -d --build

# 4. 컨테이너 접속
docker-compose exec linux-practice bash

# 5. 컨테이너 내에서 Linux 실습 시작
su - agent-admin
```

---

### Step 1: Docker 설치 및 확인

```bash
# Docker 버전 확인
docker --version
# 예상 결과: Docker version 28.x.x

# Docker 데몬 상태 확인
docker info | grep "Operating System"
# macOS: Operating System: OrbStack
# Linux: Operating System: <your-linux>
```

### Step 2: 프로젝트 디렉토리 구조 (홈 기준)

```
~/auto-monitoring/
├── Dockerfile              # Ubuntu 기반 Linux 실습 이미지
├── docker-compose.yml      # 컨테이너 실행 설정
├── src/                    # 실습용 스크립트 (plan.md 기반)
│   └── setup.sh            # 자동화 설정 스크립트
├── logs/                   # 모니터링 로그 (호스트에 저장)
├── docs/
│   ├── MISSION.md
│   ├── README.md
│   └── plan.md
└── README.md
```

### Step 3: 프로젝트 디렉토리 생성

```bash
# 프로젝트 디렉토리 생성
mkdir -p ~/auto-monitoring/{src,logs,docs}

# 이동 확인
cd ~/auto-monitoring
pwd

# 구조 확인
ls -la ~/auto-monitoring
```

### Step 4: Dockerfile 작성

파일: `~/auto-monitoring/Dockerfile`

자세한 내용은 [docs/plan.md](docs/plan.md) **사전-3: 사전 설정 섹션** 및 **Phase 0.3**을 참고하세요.

### Step 5: docker-compose.yml 작성

파일: `~/auto-monitoring/docker-compose.yml`

자세한 내용은 [docs/plan.md](docs/plan.md) **Phase 0.4**를 참고하세요.

### Step 6: 컨테이너 실행

```bash
# 홈 디렉토리 기준
cd ~/auto-monitoring

# 이미지 빌드 및 컨테이너 실행
docker-compose up -d --build

# 컨테이너 상태 확인
docker-compose ps
# 예상 결과:
# NAME                   IMAGE                    STATUS
# auto-monitoring-lab    auto-monitoring:latest   Up ...

# 컨테이너 접속
docker-compose exec linux-practice bash

# 컨테이너 내에서
root@<container-id>:/#
```

### Step 7: 컨테이너 내에서 실습

[docs/plan.md](docs/plan.md)의 **Phase 2 ~ Phase 10**을 순차적으로 진행합니다.

```bash
# 컨테이너 내에서
su - agent-admin
source /etc/profile.d/agent-app.sh
cd ~/agent-app
```

### Step 8: 컨테이너 종료 및 정리

```bash
# 컨테이너 종료 (데이터 유지)
docker-compose down

# 컨테이너 및 볼륨 완전 삭제
docker-compose down -v

# 재실습 시 (이미지 캐시 사용)
docker-compose up -d
```

---

## 📚 컨테이너 내 Linux 실습

모든 실습은 컨테이너 내에서 [docs/plan.md](docs/plan.md)의 **Phase 2 ~ Phase 10**을 따라 진행합니다.

자세한 내용은 [docs/plan.md](docs/plan.md)를 참고하세요.

---

## ✅ 성공 기준

[docs/plan.md](docs/plan.md)의 **Phase 10: 최종 검증 및 문서화**를 참고하세요.

---

## 📚 학습 성과

이 프로젝트 완료 후 다음을 이해할 수 있습니다:

1. **Docker 실습 환경**: 이식 가능한 Linux 컨테이너 환경 구축
2. **보안 기본**: SSH 포트 변경과 Root 접속 차단의 중요성
3. **방화벽 관리**: UFW를 이용한 포트 정책 관리
4. **권한 분리**: 역할 기반 계정/그룹과 ACL 활용
5. **환경 표준화**: 환경 변수를 통한 실행 환경 고정
6. **시스템 모니터링**: Shell 스크립트로 시스템 상태 수집
7. **자동화**: Crontab을 이용한 주기적 작업 자동화
8. **로그 관리**: 운영 로그 기록 및 추적

---

## 📝 이식성 및 재현성

### 경로 기준: `~` (홈 디렉토리)

모든 경로가 `~` 기준으로 작성되어 있으므로:

- ✅ **macOS**: `/Users/<username>/auto-monitoring/` 
- ✅ **Linux (Ubuntu)**: `/home/<username>/auto-monitoring/`
- ✅ **Linux (Fedora)**: `/home/<username>/auto-monitoring/`

어느 컴퓨터에서든 `mkdir -p ~/auto-monitoring` 후 파일만 준비하면 **동일하게 실행** 가능합니다.

### Docker 버전 호환성

- ✅ Docker 28.5.2 (OrbStack)
- ✅ Docker 25.x ~ 28.x
- ✅ Docker Compose v2.x

---

## 💡 팁

1. **로그 실시간 확인** (호스트에서):
   ```bash
   tail -f ~/auto-monitoring/logs/monitor.log
   ```

2. **컨테이너 일시 중지**:
   ```bash
   docker-compose pause
   docker-compose unpause
   ```

3. **컨테이너 재시작**:
   ```bash
   docker-compose restart
   ```

4. **컨테이너 내 다른 사용자로 실행**:
   ```bash
   docker-compose exec -u agent-dev linux-practice bash
   ```

---

**최종 목표**: 서버 장애 시 원인 분석을 위한 충분한 로그와 체계적인 모니터링 인프라 구축
