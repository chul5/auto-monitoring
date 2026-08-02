# Study Guide - 과제 핵심 개념 정리

> 비전공자도 읽을 수 있도록 비유와 함께 설명합니다.

---

## 목차

1. [리눅스 파일 권한](#1-리눅스-파일-권한)
2. [사용자와 그룹](#2-사용자와-그룹)
3. [SSH - 원격 접속](#3-ssh---원격-접속)
4. [방화벽 (UFW)](#4-방화벽-ufw)
5. [환경변수](#5-환경변수)
6. [셸 스크립트 기초](#6-셸-스크립트-기초)
7. [프로세스와 포트](#7-프로세스와-포트)
8. [시스템 자원 모니터링](#8-시스템-자원-모니터링)
9. [cron - 자동 반복 실행](#9-cron---자동-반복-실행)
10. [로그와 로그 로테이션](#10-로그와-로그-로테이션)
11. [setup.sh 명령어 해설](#11-setupsh-명령어-해설)
12. [monitor.sh 함수 해설](#12-monitorsh-함수-해설)

---

## 1. 리눅스 파일 권한

### 핵심 개념

리눅스의 모든 파일과 디렉토리에는 **누가 무엇을 할 수 있는지** 규칙이 붙어 있습니다.

마치 회사 건물 출입증처럼, 파일마다 "소유자", "소속 그룹", "그 외 모든 사람" 세 범주로 권한을 나눕니다.

### 권한의 3가지 종류

| 기호 | 의미 | 파일에서 | 디렉토리에서 |
|------|------|----------|--------------|
| `r` | read (읽기) | 파일 내용 보기 | 목록 보기 (ls) |
| `w` | write (쓰기) | 파일 내용 수정 | 파일 생성/삭제 |
| `x` | execute (실행) | 프로그램으로 실행 | 폴더 안으로 진입 (cd) |

### ls -l 읽는 법

```
-rwxr-x---  agent-dev  agent-core  monitor.sh
 ↑↑↑↑↑↑↑↑↑
 │└──┘└──┘└──┘
 │ 소유자  그룹  기타
 │ rwx    r-x   ---
 파일 타입 (- = 파일, d = 디렉토리)
```

- 소유자(agent-dev): rwx → 읽기 + 쓰기 + 실행 가능
- 그룹(agent-core): r-x → 읽기 + 실행만 가능
- 기타: --- → 아무것도 불가

### 숫자 표기법

권한을 숫자로도 표현합니다. r=4, w=2, x=1을 더합니다.

| 숫자 | 의미 |
|------|------|
| 7 | rwx (4+2+1) |
| 6 | rw- (4+2) |
| 5 | r-x (4+1) |
| 4 | r-- (4) |
| 0 | --- |

이 과제에서 사용한 권한:

| 값 | 적용 대상 | 의미 |
|----|-----------|------|
| `750` | monitor.sh | 소유자 전체, 그룹 읽기·실행, 기타 차단 |
| `640` | t_secret.key | 소유자 읽기·쓰기, 그룹 읽기만, 기타 차단 |
| `770` | upload_files, api_keys | 소유자·그룹 전체, 기타 차단 |
| `440` | sudoers 파일 | 소유자·그룹 읽기만 (수정 불가) |

### 관련 명령어

```bash
chmod 750 monitor.sh         # 권한 숫자로 변경
chmod +x agent-app           # 실행 권한만 추가
chown agent-dev:agent-core monitor.sh  # 소유자:그룹 변경
ls -l                        # 권한 확인
```

---

## 2. 사용자와 그룹

### 핵심 개념

리눅스는 **다중 사용자 시스템**입니다. 여러 사람이 동시에 사용할 수 있고, 사람마다 권한을 다르게 줄 수 있습니다.

**그룹**은 여러 사용자를 묶어서 같은 권한을 한꺼번에 부여하는 방법입니다.
예: 회사에서 "개발팀" 사람들만 특정 서버에 접근할 수 있게 하는 것.

### 이 과제의 계정/그룹 구조

```
agent-common 그룹 (공통)
├── agent-admin   ← 운영자, cron 실행, sudo 권한 있음
├── agent-dev     ← 개발자, monitor.sh 소유자
└── agent-test    ← 테스터

agent-core 그룹 (핵심 접근)
├── agent-admin
└── agent-dev
```

agent-test는 agent-core에 없기 때문에 api_keys, monitor.sh, 로그 디렉토리에 접근할 수 없습니다.

### 핵심 명령어

```bash
id agent-admin              # 계정의 uid, gid, 소속 그룹 확인
whoami                      # 현재 로그인한 계정 확인
su - agent-admin            # agent-admin 계정으로 전환 (- 옵션: 환경변수도 같이 전환)
```

### uid / gid 란?

리눅스는 사람 이름 대신 숫자(uid)로 사용자를 관리합니다.

- root는 항상 uid=0
- 일반 사용자는 보통 1000번 이상

`id agent-admin`을 실행하면 이렇게 나옵니다:
```
uid=1001(agent-admin) gid=1002(agent-common) groups=1002(agent-common),1003(agent-core),27(sudo)
```

---

## 3. SSH - 원격 접속

### 핵심 개념

SSH(Secure Shell)는 **네트워크를 통해 다른 컴퓨터에 안전하게 접속**하는 방법입니다.
카카오톡처럼 암호화된 채널로 명령어를 주고받는다고 생각하면 됩니다.

### 왜 포트를 22에서 20022로 바꾸는가?

기본 SSH 포트(22)는 전 세계 해커들이 자동으로 공격을 시도하는 포트입니다.
포트를 20022로 바꾸면 자동화된 공격 대부분을 피할 수 있습니다.
(완벽한 보안은 아니지만 기본적인 노이즈를 줄여줍니다.)

### 왜 Root 원격 로그인을 차단하는가?

root는 리눅스의 "관리자" 계정으로 모든 권한을 가집니다.
root로 직접 SSH 접속을 허용하면 비밀번호 하나만 뚫려도 서버 전체가 위험합니다.
일반 계정으로 접속 후 필요할 때만 `sudo`로 승격하는 것이 안전합니다.

### sshd_config 설정 확인

```bash
grep -E "^Port|^PermitRootLogin" /etc/ssh/sshd_config
# Port 20022          ← 포트 변경 확인
# PermitRootLogin no  ← root 차단 확인
```

---

## 4. 방화벽 (UFW)

### 핵심 개념

방화벽은 서버의 **입구를 통제하는 경비원**입니다.
어떤 포트로 들어오는 요청은 허용하고, 나머지는 모두 막는 역할입니다.

### UFW (Uncomplicated Firewall)

Ubuntu에서 제공하는 방화벽 도구로, 복잡한 iptables 규칙을 쉽게 설정할 수 있습니다.

### 이 과제의 방화벽 정책

```
외부에서 들어오는 요청 → 기본 차단
예외 허용:
  - 20022/tcp (SSH 접속용)
  - 15034/tcp (애플리케이션용)
```

### setup.sh에서 사용한 UFW 명령어

```bash
ufw default deny incoming   # 들어오는 모든 요청 기본 차단
ufw default allow outgoing  # 나가는 요청은 기본 허용
ufw allow 20022/tcp         # SSH 포트만 허용
ufw allow 15034/tcp         # 앱 포트만 허용
ufw --force enable          # 방화벽 활성화 (--force: 확인 프롬프트 생략)
ufw status numbered         # 현재 규칙 목록 확인
```

### UFW가 Dockerfile에서 활성화될 수 없는 이유

UFW는 리눅스 커널의 네트워크 필터(netfilter)를 수정합니다.
Docker 이미지 빌드 중(`RUN` 명령)에는 실제 커널이 없어서 활성화가 불가능합니다.
컨테이너가 실행된 후에만 활성화할 수 있습니다.

---

## 5. 환경변수

### 핵심 개념

환경변수는 프로그램이 실행될 때 참조할 수 있는 **전역 설정값**입니다.
마치 회사 내부 전화번호부처럼, 여러 프로그램이 같은 값을 공유합니다.

### 이 과제에서 사용한 환경변수

| 변수 | 값 | 용도 |
|------|----|------|
| `AGENT_HOME` | `/home/agent-admin/agent-app` | 앱 루트 경로 |
| `AGENT_PORT` | `15034` | 앱 포트 번호 |
| `AGENT_UPLOAD_DIR` | `$AGENT_HOME/upload_files` | 업로드 디렉토리 |
| `AGENT_KEY_PATH` | `$AGENT_HOME/api_keys/t_secret.key` | 키 파일 경로 |
| `AGENT_LOG_DIR` | `/var/log/agent-app` | 로그 디렉토리 |

### /etc/profile.d/ 란?

`/etc/profile.d/` 안의 `.sh` 파일들은 **로그인 시 자동으로 실행**됩니다.
여기에 환경변수를 설정해두면 모든 사용자가 로그인할 때 자동으로 적용됩니다.

```bash
source /etc/profile.d/agent-app.sh   # 수동으로 즉시 로드
echo $AGENT_HOME                     # 환경변수 값 확인
```

### 이 파일은 언제 만들어지는가

`/etc/profile.d/agent-app.sh`는 **컨테이너가 뜰 때 setup.sh가 생성**합니다.
Dockerfile에서 굽지 않는 이유는, 값을 두 군데서 관리하게 되기 때문입니다.

```
Dockerfile ENV          → 기본값
docker-compose environment → 환경별로 덮어쓰는 값
        ↓
   컨테이너 환경변수 (최종 값)
        ↓
   setup.sh가 읽어서 /etc/profile.d/agent-app.sh 생성
        ↓
   cron · ssh 로그인 셸 · monitor.sh 가 전부 같은 값을 봄
```

빌드 시점에 구우면 compose로 값을 바꿔도 profile.d는 옛 값을 그대로 들고 있어서
"컨테이너 환경변수는 A인데 로그인하면 B"인 상황이 생깁니다.

### cron에서 환경변수가 필요한 이유

cron은 로그인 셸이 아니라서 `/etc/profile.d/`를 자동으로 읽지 않습니다.
그래서 monitor.sh 맨 위에 `source /etc/profile.d/agent-app.sh`를 명시적으로 써야 합니다.

---

## 6. 셸 스크립트 기초

### #!/bin/bash (Shebang)

스크립트 첫 줄의 `#!/bin/bash`는 "이 파일을 bash로 실행하라"는 의미입니다.
이게 없으면 어떤 프로그램으로 실행해야 할지 시스템이 모릅니다.

### set -euo pipefail

스크립트의 안전 장치입니다. setup.sh와 monitor.sh 모두 첫 줄에 있습니다.

```bash
set -euo pipefail
```

| 옵션 | 의미 |
|------|------|
| `-e` | 명령이 실패하면 즉시 스크립트 종료 (오류 무시 방지) |
| `-u` | 정의되지 않은 변수 사용 시 오류 (오타 방지) |
| `-o pipefail` | 파이프(`\|`) 중간에 실패해도 오류로 처리 |

### 함수 정의

```bash
함수이름() {
    # 실행할 명령들
}

# 호출
함수이름
```

### if 조건문

```bash
if 조건; then
    # 조건이 참일 때
else
    # 조건이 거짓일 때
fi
```

`!`는 조건을 반전시킵니다:

```bash
if ! check_process; then   # check_process가 실패하면(프로세스 없으면)
    exit 1
fi
```

### 변수

```bash
변수명=값                  # 변수 선언 (= 양쪽 공백 없이)
echo $변수명               # 변수 사용
echo "${변수명}_suffix"    # 중괄호로 구분
```

### >> vs > (파일 쓰기)

```bash
echo "내용" > 파일     # 덮어쓰기 (기존 내용 삭제)
echo "내용" >> 파일    # 이어쓰기 (기존 내용 유지)
```

monitor.sh에서 로그를 `>>`로 쓰는 이유가 여기에 있습니다. 이전 로그를 지우지 않고 누적합니다.

---

## 7. 프로세스와 포트

### 프로세스란?

실행 중인 프로그램의 인스턴스입니다. 프로그램은 디스크에 있는 파일이고, 프로세스는 메모리에 올라가서 실행 중인 상태입니다.

모든 프로세스에는 **PID(Process ID)** 라는 고유 번호가 붙습니다.

### 포트란?

포트는 컴퓨터와 통신하기 위한 **문(door)** 입니다.
컴퓨터는 0~65535번 포트를 가지며, 각 프로그램은 특정 포트를 열어서 요청을 받습니다.

예: 웹서버는 보통 80번(HTTP) 또는 443번(HTTPS) 포트를 사용합니다.

### 프로세스 확인 명령어

```bash
pgrep -f "$AGENT_HOME/agent-app$"
# -f: 프로세스 이름뿐 아니라 실행 명령어 전체에서 검색
# 출력: 일치하는 프로세스의 PID 번호
```

패턴을 전체 경로로 쓰고 끝에 `$`(문자열 끝)를 붙인 이유는 **오탐을 막기 위해서**입니다.
`agent-app`이라고만 쓰면 `/var/log/agent-app` 같은 경로가 명령어에 들어간 다른 프로세스까지
잡혀서, 앱이 죽었는데도 살아있다고 판단할 수 있습니다.

```bash
pgrep -f "agent-app" | head -1
# head -1: 첫 번째 결과만 가져옴 (여러 프로세스 중 대표 PID)
```

### 포트 확인 명령어

```bash
ss -tlunp | grep ":15034"
# ss: 소켓 상태 확인 도구 (netstat의 현대적 대체)
# -t: TCP 표시
# -u: UDP 표시
# -l: LISTEN(대기 중인) 소켓만 표시
# -n: 포트를 숫자로 표시 (서비스 이름 대신)
# -p: 어떤 프로세스가 사용 중인지 표시
```

출력 예시:
```
tcp  LISTEN  0.0.0.0:15034  0.0.0.0:*  users:(("agent-app",pid=358))
```

`0.0.0.0:15034`는 "모든 네트워크 인터페이스의 15034번 포트에서 대기 중"이라는 의미입니다.

### 백그라운드 실행

```bash
nohup ./agent-app >> /var/log/agent-app/agent_app.log 2>&1 &
# nohup: 터미널이 닫혀도 프로세스 유지
# >> 파일: 표준 출력을 파일에 이어쓰기 (재기동해도 이전 로그 보존)
# 2>&1: 에러 출력도 같은 파일로
# &: 백그라운드 실행
```

---

## 8. 시스템 자원 모니터링

### CPU 사용률

CPU는 컴퓨터의 두뇌입니다. 사용률이 높으면 처리할 일이 많다는 신호입니다.

```bash
top -bn1 | grep "%Cpu" | awk '{print $2}' | tr -d '%'
# top: 실시간 시스템 상태 표시 도구
# -b: 배치 모드 (스크립트에서 사용 가능하게)
# -n1: 1번만 출력하고 종료
# grep "%Cpu": CPU 정보 라인만 추출
# awk '{print $2}': 두 번째 컬럼(사용자 CPU%) 출력
# tr -d '%': % 기호 제거
```

### 메모리 사용률

RAM(메모리)은 프로그램이 실행될 때 데이터를 올려두는 공간입니다.

```bash
free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}'
# free: 메모리 사용량 표시
# grep Mem: 물리 메모리 라인만 추출
# awk: $2=전체, $3=사용중 → 사용률(%) 계산
# printf("%.1f", ...): 소수점 1자리로 출력
```

`free` 출력 예시:
```
              total    used    free
Mem:        2048000  512000  1536000
```

### 디스크 사용률

```bash
df / | tail -1 | awk '{print $5}' | tr -d '%'
# df: 디스크 공간 사용량 표시
# /: 루트 파티션 확인
# tail -1: 마지막 줄만 (데이터 행)
# awk '{print $5}': 5번째 컬럼(사용률%) 출력
# tr -d '%': % 기호 제거
```

### 소수점 비교 문제와 bc

셸의 `[ ]`는 정수만 비교할 수 있습니다.
`if [ 25.3 -gt 20 ]`는 에러가 납니다.

그래서 `bc`를 사용합니다:

```bash
if [ "$(echo "$CPU_USAGE > $CPU_THRESHOLD" | bc)" -eq 1 ]; then
    echo "[${TIMESTAMP}] [WARNING] CPU threshold exceeded (${CPU_USAGE}% > ${CPU_THRESHOLD}%)" >> "$LOG_FILE"
fi
```

`bc`는 비교식을 받으면 **참이면 1, 거짓이면 0**을 출력합니다.
그 값을 `-eq 1`로 확인해서 임계값을 넘었을 때만 경고를 남깁니다.

```bash
echo "25.3 > 20" | bc    # → 1 (참)
echo "0.0 > 20" | bc     # → 0 (거짓)
```

> `bc`는 기본 설치가 아닌 배포판이 있어서 Dockerfile의 apt 패키지 목록에 추가해두었습니다.
>
> DISK는 `df`가 정수 %만 주기 때문에 `bc` 없이 `[ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]`로 비교합니다.

---

## 9. cron - 자동 반복 실행

### 핵심 개념

cron은 **정해진 시간에 자동으로 명령을 실행**해주는 스케줄러입니다.
알람 앱처럼, "매일 오전 9시에 이 명령을 실행해"라고 등록해두면 알아서 실행합니다.

등록한 계정별로 crontab이 관리됩니다. agent-admin 에서 등록했다면 root에서는 해당 크론텝이 돌지 않습니다.
다만 이래서 발생할 수 있는 문제가, 같은 작업을 각 계정의 크론스케줄러로 동작시키면 같은 일을 두 번 할 수가 있습니다.
따라서 이런 것을 방지하기 위해 /etc/cron.d/ 와 같은 전역 크론 디렉터리에서 깃으로 관리하는 방식을 사용합니다.

### crontab 문법

```
*  *  *  *  *  실행할_명령어
│  │  │  │  │
│  │  │  │  └── 요일 (0=일요일, 6=토요일)
│  │  │  └───── 월 (1-12)
│  │  └──────── 일 (1-31)
│  └─────────── 시 (0-23)
└────────────── 분 (0-59)
```

`*`는 "모든 값"을 의미합니다.

이 과제에서 등록한 crontab:
```
* * * * * /home/agent-admin/agent-app/bin/monitor.sh
```
→ 매분 0초에 monitor.sh 실행

### crontab 관련 명령어

```bash
crontab -l          # 현재 등록된 작업 목록 확인
crontab -e          # 편집기로 crontab 수정
crontab -r          # 모든 crontab 삭제 (주의!)

# 스크립트에서 비대화형으로 등록하는 방법
echo "* * * * * /경로/명령어" | crontab -
# | crontab -: 파이프로 받은 내용을 crontab에 등록
# 우리 미션은 agent-admin이 등록하도록 해야하니까 파이프에 로그인을 하도록 연결해야한다.
```

### cron이 환경변수를 상속하지 않는 이유

cron은 로그인 없이 백그라운드에서 실행되기 때문에 `.bashrc`, `/etc/profile.d/` 등이 실행되지 않습니다. 그래서 `$AGENT_HOME` 같은 변수를 모릅니다.

해결책 1 - 스크립트 안에서 직접 로드:
```bash
source /etc/profile.d/agent-app.sh
```

해결책 2 - crontab에서 절대경로 사용:
```
* * * * * /home/agent-admin/agent-app/bin/monitor.sh
```
(변수 없이 전체 경로 명시)

### sudoers와 NOPASSWD

cron은 비대화형 환경이라 `sudo` 실행 시 비밀번호 입력창을 띄울 수 없습니다.
그래서 특정 명령에 한해 비밀번호 없이 sudo를 허용합니다.

```bash
# /etc/sudoers.d/agent-monitor 내용:
agent-admin ALL=(ALL) NOPASSWD: /usr/sbin/ufw status
# agent-admin이 'ufw status'를 비밀번호 없이 실행 가능

setup.sh에 crontab에 등록된 monitor.sh를 사용하기 위한 명령어를 정리한다.
agent-admin   ALL   =(ALL)   NOPASSWD:   /usr/sbin/ufw status
────┬─────    ─┬─    ──┬──   ────┬────   ──────────┬─────────
    │          │       │         │                 │
 적용 대상   어느    어떤 사용자   비밀번호를      허용할 명령
  사용자    호스트    자격으로     묻지 않음

echo "$MONITOR_CRON" | su - agent-admin -c 'crontab -'
                       ─┬ ┬  ────┬─────  ─┬  ───────┬
                        │ │      │        │         └── crontab의 인자
                        │ │      │        └── su의 옵션
                        │ │      └── 전환할 대상 사용자
                        │ └── 로그인 셸로 전환
                        └── substitute user
```

`chmod 440`: sudoers 파일은 실수로 수정되면 sudo가 완전히 망가질 수 있어서 쓰기 권한을 제거합니다.

---

## 10. 로그와 로그 로테이션

### 로그란?

서버가 어떤 일을 했는지 **시간 순서대로 기록한 파일**입니다.
장애가 발생했을 때 "언제, 무슨 일이 있었는지" 추적하는 데 필수입니다.

### monitor.log 형식

```
[2026-05-31 07:01:01] PID:358 CPU:5.0% MEM:3.2% DISK_USED:23%
[2026-05-31 07:02:01] [WARNING] CPU threshold exceeded (25.3% > 20%)
[2026-05-31 07:03:01] PID:358 CPU:8.1% MEM:3.4% DISK_USED:23%
```

### 로그 로테이션이 필요한 이유

cron이 매분 실행되면 하루 1440줄, 한 달이면 약 43,000줄이 쌓입니다.
무한정 쌓이면 디스크가 꽉 차서 서버가 다운될 수 있습니다.

**로그 로테이션**: 로그 파일이 일정 크기를 넘으면 파일을 교체하고 오래된 파일은 삭제하는 방법.

```
monitor.log      ← 현재 로그 (최신)
monitor.log.1    ← 이전 로그
monitor.log.2    ← 그 이전 로그
...
monitor.log.10   ← 가장 오래된 로그 (이후 삭제)
```

---

## 11. setup.sh 명령어 해설

### cat > 파일 <<EOF (히어독)

```bash
cat > /etc/profile.d/agent-app.sh <<EOF
export AGENT_HOME=${AGENT_HOME}
export AGENT_PORT=${AGENT_PORT}
EOF
```

여러 줄을 한 번에 파일로 써넣는 문법입니다. `<<EOF` 다음 줄부터 `EOF`가 다시 나올 때까지가 내용이 됩니다.
`${AGENT_HOME}` 같은 변수는 **쓰는 시점의 값으로 치환**되어 파일에 박힙니다.
치환 없이 문자 그대로 남기고 싶으면 `<<'EOF'`처럼 따옴표를 붙입니다.

### pkill과 || true

```bash
pkill -f "$AGENT_HOME/agent-app$" || true
```

`pkill`은 패턴에 맞는 프로세스를 종료합니다. `pgrep`과 옵션이 같습니다.

문제는 **죽일 프로세스가 없으면 exit 1**을 반환한다는 점입니다.
setup.sh 맨 위에 `set -e`가 있어서 그대로 두면 첫 기동(앱이 아직 없는 상태)에
스크립트가 거기서 멈춰버립니다. `|| true`는 "앞이 실패해도 성공으로 친다"는 뜻으로,
앱이 있든 없든 다음 단계로 넘어가게 해줍니다.

### source

```bash
source /etc/profile.d/agent-app.sh
```

셸 스크립트를 **현재 셸 환경에 적용**합니다.
setup.sh가 만들어둔 환경변수 파일을 monitor.sh가 이 명령으로 읽어들입니다.

`bash 파일.sh`는 별도의 자식 셸에서 실행되어 변수가 현재 셸에 남지 않지만,
`source`는 현재 셸에서 직접 실행하므로 변수가 현재 환경에 적용됩니다.

### echo "내용" > 파일

```bash
echo "agent_api_key_test" > "$AGENT_KEY_PATH"
```

파일에 내용을 씁니다. `>`는 파일을 새로 만들거나 기존 내용을 덮어씁니다.

### chmod

```bash
chmod 640 "$AGENT_KEY_PATH"   # 숫자 방식
chmod +x "$AGENT_HOME/agent-app"  # 실행 권한만 추가
```

파일 권한을 변경합니다. 숫자 방식은 세 자리 숫자로 소유자/그룹/기타 권한을 한번에 설정합니다.

### chown

```bash
chown agent-dev:agent-core "$AGENT_KEY_PATH"
```

파일의 소유자와 그룹을 변경합니다. `소유자:그룹` 형식으로 씁니다.

### cp

```bash
cp /home/agent-admin/src/agent-app "$AGENT_HOME/agent-app"
```

파일을 복사합니다. `cp 원본 복사본` 형식입니다.

### echo "..." > /etc/sudoers.d/파일

```bash
echo "agent-admin ALL=(ALL) NOPASSWD: /usr/sbin/ufw status" > /etc/sudoers.d/agent-monitor
```

sudoers 설정 파일을 생성합니다. `/etc/sudoers.d/` 안의 파일들은 sudo 설정에 자동으로 포함됩니다.

### echo "..." | su - 계정 -c 'crontab -'

```bash
echo "$MONITOR_CRON" | su - agent-admin -c 'crontab -'
```

- `echo "$MONITOR_CRON"`: crontab에 등록할 내용을 출력
- `|`: 앞 명령의 출력을 뒤 명령의 입력으로 전달
- `su - agent-admin`: agent-admin 계정으로 전환 (- 옵션: 로그인 환경도 함께)
- `-c 'crontab -'`: 해당 계정으로 `crontab -` 실행 (`-`는 표준입력에서 읽기)

---

## 12. monitor.sh 함수 해설

### check_process()

```bash
check_process() {
    pgrep -f "$AGENT_HOME/agent-app$" > /dev/null
}
```

`pgrep -f`: 실행 명령어 전체에서 패턴에 맞는 프로세스를 찾아 PID를 출력합니다.
`> /dev/null`: 출력 결과를 버립니다 (PID 숫자가 화면에 나오지 않게).
프로세스가 있으면 exit 0(성공/참), 없으면 exit 1(실패/거짓)을 반환합니다.

패턴이 단순히 `agent-app`이 아니라 **전체 경로 + `$`(문자열 끝)** 인 이유는,
`/var/log/agent-app` 같은 문자열이 명령어에 들어간 무관한 프로세스까지 잡히면
앱이 죽었는데도 살아있다고 오판하기 때문입니다.

### check_port()

```bash
check_port() {
    ss -tlunp | grep -q ":${AGENT_PORT}"
}
```

`grep -q`: 결과를 출력하지 않고 찾으면 exit 0, 못 찾으면 exit 1만 반환합니다.
포트 15034가 LISTEN 상태면 참, 아니면 거짓을 반환합니다.

### check_firewall()

```bash
check_firewall() {
    sudo ufw status | grep -q "Status: active"
}
```

UFW 상태 출력에서 "Status: active" 문자열이 있는지 확인합니다.
sudo가 필요한 이유: UFW 상태 확인은 root 권한이 필요하기 때문입니다.

### get_pid()

```bash
get_pid() {
    pgrep -f "agent-app" | head -1
}
```

`head -1`: 여러 줄 중 첫 번째 줄만 가져옵니다.
agent-app 프로세스가 여러 개(부모+자식) 있을 수 있으므로 첫 번째 PID만 사용합니다.

### get_cpu_usage()

```bash
get_cpu_usage() {
    top -bn1 | grep "%Cpu" | awk '{print $2}' | tr -d '%'
}
```

파이프(`|`)로 여러 명령을 연결한 예시입니다:
1. `top -bn1`: 시스템 상태를 한 번 출력
2. `grep "%Cpu"`: CPU 정보가 있는 줄만 필터
3. `awk '{print $2}'`: 두 번째 컬럼(사용자 CPU%) 추출
4. `tr -d '%'`: '%' 문자 제거

### get_memory_usage()

```bash
get_memory_usage() {
    free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}'
}
```

`free` 출력의 Mem 행에서 `$3`(used) ÷ `$2`(total) × 100으로 사용률을 계산합니다.
`printf("%.1f", ...)`: 소수점 1자리로 포맷합니다.

### get_disk_usage()

```bash
get_disk_usage() {
    df / | tail -1 | awk '{print $5}' | tr -d '%'
}
```

`df /`: 루트 파티션 디스크 사용량 출력
`tail -1`: 헤더를 제외한 데이터 행만 가져옴
`awk '{print $5}'`: 5번째 컬럼(사용률%) 추출

### rotate_log()

```bash
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
```

**핵심 부분 설명:**

```bash
[ -f "$LOG_FILE" ] || return 0
# -f: 파일이 존재하는지 확인
# ||: 앞이 거짓이면 뒤를 실행 (파일 없으면 함수 종료)
```

```bash
stat -c%s "$LOG_FILE"
# stat: 파일 상세 정보 표시
# -c%s: 파일 크기(바이트)만 출력
```

```bash
seq $((LOG_MAX_FILES - 1)) -1 1
# seq: 숫자 시퀀스 생성
# 9 -1 1 → 9, 8, 7, ..., 1 (역순)
# 역순으로 밀어야 기존 파일을 덮어쓰지 않음
```

```bash
[ -f "${LOG_FILE}.${i}" ] && mv ...
# &&: 앞이 참이면 뒤를 실행 (파일이 있을 때만 이동)
```

로테이션 동작 흐름 (10MB 초과 시):
```
monitor.log.9  → 삭제
monitor.log.8  → monitor.log.9
...
monitor.log.1  → monitor.log.2
monitor.log    → monitor.log.1  (현재 파일 보관)
(새 monitor.log은 다음 실행 때 새로 생성됨)
```

---

## 정리: 이 과제에서 배운 것

| 영역 | 핵심 내용 |
|------|-----------|
| 보안 | SSH 포트 변경, root 차단, 방화벽으로 필요한 포트만 열기 |
| 권한 관리 | 역할별 계정/그룹 분리, 최소 권한 원칙 (필요한 만큼만 부여) |
| 자동화 | 셸 스크립트로 반복 작업 자동화, cron으로 주기 실행 |
| 모니터링 | 프로세스·포트·자원 상태를 주기적으로 수집하고 로그로 기록 |
| 운영 | 로그 로테이션으로 디스크 관리, 임계값 기반 경고 시스템 |
