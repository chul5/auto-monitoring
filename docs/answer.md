# 평가문항 대응 문서 (answer.md)

이 문서는 evaluation 폼(codyssey 평가문항 5개 항목)에 대해 현재 시스템(`auto-monitoring-lab` 컨테이너, 실행 중)이 실제로 요구사항을 충족하는지 **실측 검증**하고, 평가 시 그대로 말할 수 있는 **답변 스크립트**를 정리한 것이다.

> 검증 시점: 컨테이너 `auto-monitoring-lab` (재빌드 후 Up, setup.sh 완료 상태)에서 직접 명령 실행하여 확인함.

## 종합 결과

| 항목 | 내용 | 상태 |
|---|---|---|
| 항목1 | 필수 증거 체크리스트 (8개) | ✅ 전부 충족 |
| 항목2 | 구현 방식 설명 (4개) | ✅ 전부 설명 가능 |
| 항목3 | 보안/운영 원리 설명 (4개) | ✅ 전부 설명 가능 (단, 1개는 환경적 예외사항 인지 필요) |
| 항목4 | 응용 시나리오 설명 (3개) | ✅ 전부 설명 가능 |
| 항목5 | 보너스 (report.sh, 로그 보존 정책) | ❌ 미구현 (선택 과제이므로 감점 아님, 크레딧 미해당) |

남은 환경적 예외 하나는 **OrbStack 바인드 마운트에서 `chown`이 무시되는 현상**이다. 상세는 항목3의 2번을 참고.

---

## 구현 위치 요약 (어디에 무슨 명령으로 구현했는가)

MISSION 요구사항별로 "어느 파일 몇 번째 줄에, 어떤 명령으로" 구현했는지 한눈에 보는 표.
평가 중 "그거 어디에 있어요?"라는 질문에 바로 짚을 수 있도록 정리했다.

### 역할 분담 원칙

| 파일 | 담당 | 판단 기준 |
|---|---|---|
| `Dockerfile` | 패키지, 계정/그룹, SSH 설정, 디렉토리 **구조**, 환경변수 **기본값**, 생명주기 선언 | 재빌드해야 바뀌는 것 |
| `src/setup.sh` | 환경변수 배포, **권한 정책 전체**, 방화벽, 파일 배치, sudoers, cron, 앱 기동 | 컨테이너가 뜰 때마다 보장돼야 하는 것 |
| `docker-compose.yml` | 환경변수 실제값, 포트 매핑, 볼륨 마운트 | 환경마다 달라지는 것 |
| `src/monitor.sh` | 상태 점검, 자원 수집, 임계값 경고, 로그 기록/회전 | cron이 매분 실행 |

### MISSION §4-1 기본 보안 및 네트워크

| 요구사항 | 위치 | 명령 |
|---|---|---|
| SSH 포트 20022 | [Dockerfile:29](../Dockerfile#L29) | `sed -i 's/#Port 22/Port 20022/' /etc/ssh/sshd_config` |
| Root 원격 로그인 차단 | [Dockerfile:30](../Dockerfile#L30) | `echo 'PermitRootLogin no' >> /etc/ssh/sshd_config` |
| 기본 인바운드 차단 | [setup.sh:39-40](../src/setup.sh#L39-L40) | `ufw default deny incoming` / `ufw default allow outgoing` |
| 20022·15034만 허용 | [setup.sh:41-42](../src/setup.sh#L41-L42) | `ufw allow 20022/tcp` / `ufw allow "${AGENT_PORT}/tcp"` |
| 방화벽 활성화 | [setup.sh:43](../src/setup.sh#L43) | `ufw --force enable` |

> 앱 포트는 하드코딩하지 않고 `${AGENT_PORT}`를 쓴다. 환경변수로 관리한다고 선언한 값이므로 방화벽도 같은 출처를 봐야 어긋나지 않는다. SSH 20022는 `sshd_config`에 박힌 값이라 고정.

### MISSION §4-2 계정/그룹/권한

| 요구사항 | 위치 | 명령 |
|---|---|---|
| 그룹 2개 생성 | [Dockerfile:33](../Dockerfile#L33) | `groupadd -f agent-common && groupadd -f agent-core` |
| agent-admin (common+core+sudo) | [Dockerfile:36-38](../Dockerfile#L36-L38) | `useradd -m -s /bin/bash -g agent-common` + `usermod -aG` |
| agent-dev (common+core) | [Dockerfile:40-41](../Dockerfile#L40-L41) | 동일 |
| agent-test (common만) | [Dockerfile:43](../Dockerfile#L43) | `useradd -m -s /bin/bash -g agent-common agent-test` |
| 디렉토리 구조 생성 | [Dockerfile:51-53](../Dockerfile#L51-L53) | `mkdir -p` (bin, upload_files, api_keys) |
| `$AGENT_HOME` 755 | [setup.sh:23-24](../src/setup.sh#L23-L24) | `chown agent-admin:agent-common` + `chmod 755` |
| `bin/` 750 dev:core | [setup.sh:26-27](../src/setup.sh#L26-L27) | `chown agent-dev:agent-core` + `chmod 750` |
| `upload_files/` 770 common | [setup.sh:29-30](../src/setup.sh#L29-L30) | `chown -R agent-admin:agent-common` + `chmod 770` |
| `api_keys/` 770 core | [setup.sh:32-33](../src/setup.sh#L32-L33) | `chown -R agent-dev:agent-core` + `chmod 770` |
| `/var/log/agent-app` 770 core | [setup.sh:35-36](../src/setup.sh#L35-L36) | `chown -R agent-admin:agent-core` + `chmod 770` |

> 권한이 Dockerfile이 아니라 setup.sh에 있는 이유는 **바인드 마운트**다. `/var/log/agent-app`는 호스트 `./logs`가 덮어쓰므로, 빌드 시점 설정은 컨테이너가 뜨는 순간 사라진다. 마운트가 끝난 런타임에 걸어야 유효하다. 나머지도 정책을 한 파일에서 읽히도록 같이 모았다.

### MISSION §4-3 애플리케이션 실행 환경

| 요구사항 | 위치 | 명령 |
|---|---|---|
| 환경변수 기본값 선언 | [Dockerfile:58-62](../Dockerfile#L58-L62) | `ENV AGENT_HOME=...` 등 5개 |
| 환경변수 실제값(환경별) | [docker-compose.yml:21-24](../docker-compose.yml#L21-L24) | `environment:` (Dockerfile ENV를 덮어씀) |
| 계정 로그인 시 적용 | [setup.sh:11-18](../src/setup.sh#L11-L18) | `cat > /etc/profile.d/agent-app.sh <<EOF` |
| API 키 파일 생성 | [setup.sh:46](../src/setup.sh#L46) | `echo "agent_api_key_test" > "$AGENT_KEY_PATH"` |
| 키 파일 권한 640 dev:core | [setup.sh:47-48](../src/setup.sh#L47-L48) | `chmod 640` + `chown agent-dev:agent-core` |
| 앱 바이너리 배치 | [setup.sh:57-59](../src/setup.sh#L57-L59) | `cp` + `chmod +x` + `chown agent-admin:agent-common` |
| **루트 실행 금지** | [setup.sh:76](../src/setup.sh#L76) | `su - agent-admin -c "nohup $AGENT_HOME/agent-app >> ... &"` |

> `su -`의 `-`가 핵심이다. 로그인 셸로 전환하면서 `/etc/profile.d/agent-app.sh`를 자동으로 읽어 앱이 올바른 환경변수를 갖고 뜬다. 그리고 root가 아닌 `agent-admin`으로 실행되므로 "루트 실행 금지" 요건도 만족한다.
>
> profile.d를 빌드 시점에 굽지 않고 setup.sh가 만드는 이유: compose로 값을 덮어써도 로그인 셸이 옛 값을 보는 불일치를 막기 위해서다.

### MISSION §4-4 monitor.sh

| 요구사항 | 위치 | 명령 |
|---|---|---|
| 배치 위치 `$AGENT_HOME/bin/` | [setup.sh:62](../src/setup.sh#L62) | `cp /home/agent-admin/src/monitor.sh "$AGENT_HOME/bin/monitor.sh"` |
| 소유 dev:core / 권한 750 | [setup.sh:63-64](../src/setup.sh#L63-L64) | `chmod 750` + `chown agent-dev:agent-core` |
| 프로세스 점검 | [monitor.sh:17-19](../src/monitor.sh#L17-L19) | `pgrep -f "$AGENT_HOME/agent-app$"` |
| 포트 점검 | [monitor.sh:21-23](../src/monitor.sh#L21-L23) | `ss -tlunp \| grep -q ":${AGENT_PORT}"` |
| 비정상 시 exit 1 | [monitor.sh:60-68](../src/monitor.sh#L60-L68) | `if ! check_process; then ... exit 1; fi` |
| 방화벽 점검(경고만) | [monitor.sh:25-27](../src/monitor.sh#L25-L27), [71-73](../src/monitor.sh#L71-L73) | `sudo ufw status \| grep -q "Status: active"` |
| cron용 무암호 sudo | [setup.sh:67-68](../src/setup.sh#L67-L68) | `echo "agent-admin ALL=(ALL) NOPASSWD: /usr/sbin/ufw status" > /etc/sudoers.d/agent-monitor` + `chmod 440` |
| CPU 수집 | [monitor.sh:33-35](../src/monitor.sh#L33-L35) | `top -bn1 \| grep "%Cpu" \| awk '{print $2}' \| tr -d '%'` |
| MEM 수집 | [monitor.sh:37-39](../src/monitor.sh#L37-L39) | `free \| grep Mem \| awk '{printf("%.1f", $3/$2*100.0)}'` |
| DISK 수집 | [monitor.sh:41-43](../src/monitor.sh#L41-L43) | `df / \| tail -1 \| awk '{print $5}' \| tr -d '%'` |
| CPU/MEM 임계값 비교 | [monitor.sh:82](../src/monitor.sh#L82), [86](../src/monitor.sh#L86) | `[ "$(echo "$CPU_USAGE > $CPU_THRESHOLD" \| bc)" -eq 1 ]` |
| DISK 임계값 비교 | [monitor.sh:90](../src/monitor.sh#L90) | `[ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]` (정수라 bc 불필요) |
| 로그 기록 | [monitor.sh:97](../src/monitor.sh#L97) | `echo "[...] PID:... CPU:..%" >> "$LOG_FILE"` |
| 용량 관리 10MB/10개 | [monitor.sh:14-15](../src/monitor.sh#L14-L15), [45-57](../src/monitor.sh#L45-L57) | `stat -c%s` + `seq ... -1 1` 역순 `mv` |
| cron 데몬 기동 | [setup.sh:71](../src/setup.sh#L71) | `service cron start` |
| 매분 실행 등록 | [setup.sh:72-73](../src/setup.sh#L72-L73) | `echo "* * * * * $AGENT_HOME/bin/monitor.sh" \| su - agent-admin -c 'crontab -'` |

> `bc`는 기본 설치가 아니라서 [Dockerfile:18](../Dockerfile#L18)의 apt 패키지 목록에 추가했다.
>
> cron은 비대화형이라 `sudo` 비밀번호 프롬프트를 띄울 수 없다. 그래서 `ufw status` **한 개 명령에만** NOPASSWD를 부여했다(최소 권한).

### 컨테이너 생명주기

| 요구사항 | 위치 | 명령 |
|---|---|---|
| setup 후 sshd로 교체 | [Dockerfile:73](../Dockerfile#L73) | `CMD ["/bin/bash", "-c", "bash /home/agent-admin/src/setup.sh && exec /usr/sbin/sshd -D -e"]` |

> `exec`으로 bash를 sshd로 교체해 sshd가 PID 1이 된다(컨테이너 생명주기 = PID 1). setup.sh 안에 `exec`을 두지 않은 이유는 "설정"과 "생명주기 결정"이 다른 책임이기 때문이다. `&&`라서 setup.sh가 실패하면 sshd가 뜨지 않고 컨테이너가 죽는다(fail fast).
>
> setup.sh는 이미지에 `COPY`하지 않고 마운트된 `./src`에서 직접 실행한다. 이미지 사본과 소스가 어긋나 **옛 스크립트가 조용히 실행되는 사고**를 겪은 뒤 사본을 하나로 줄였다.

---

## 항목1. 필수 증거 체크리스트

### 1) SSH 포트가 20022로 변경되었고, Root 원격 접속이 차단되었는가?

**상태: ✅ 충족**

```bash
$ docker exec auto-monitoring-lab grep -E "^Port|^PermitRootLogin" /etc/ssh/sshd_config
Port 20022
PermitRootLogin no
```

`Dockerfile:29-30`에서 `sed`로 `#Port 22` → `Port 20022`, `PermitRootLogin no`를 추가함. `ss -tlnp`로도 20022 LISTEN 확인됨.

### 2) 방화벽이 활성화되어 있고, 20022/tcp와 15034/tcp만 허용되는가?

**상태: ✅ 충족**

```bash
$ docker exec auto-monitoring-lab ufw status
Status: active
20022/tcp   ALLOW   Anywhere
15034/tcp   ALLOW   Anywhere
20022/tcp (v6)  ALLOW   Anywhere (v6)
15034/tcp (v6)  ALLOW   Anywhere (v6)
```

`setup.sh:39-43`에서 `ufw default deny incoming` → 두 포트만 `allow` → `--force enable` 순서로 설정.

### 3) agent-admin/dev/test 계정과 agent-common/core 그룹이 요구사항대로 구성되어 있는가?

**상태: ✅ 충족**

```bash
$ docker exec auto-monitoring-lab id agent-admin
uid=1001(agent-admin) gid=1001(agent-common) groups=agent-common,sudo,agent-core
$ docker exec auto-monitoring-lab id agent-dev
uid=1002(agent-dev) gid=1001(agent-common) groups=agent-common,agent-core
$ docker exec auto-monitoring-lab id agent-test
uid=1003(agent-test) gid=1001(agent-common) groups=agent-common
```

요구사항 그대로 `agent-common`(admin/dev/test 전체) / `agent-core`(admin/dev만)로 구성됨. `agent-test`는 `agent-core`에 속하지 않아 `api_keys`, `monitor.sh`, 로그 디렉토리에 접근 불가.

### 4) 앱이 Boot Sequence 5단계 [OK]를 통과하고 "Agent READY"가 출력되는가?

**상태: ✅ 충족**

```
>>> Starting Agent Boot Sequence...
[1/5] Checking User Account               [OK]
[2/5] Verifying Environment Variables     [OK]
[3/5] Checking Required Files             [OK]
[4/5] Checking Port Availability          [OK]
[5/5] Verifying Log Permission            [OK]
------------------------------------------------------------
All Boot Checks Passed!
Agent READY
```
(`logs/agent_app.log.1` 실측, 2026-08-01 09:34:49 실행분)

### 5) monitor.sh가 프로세스/포트 상태를 점검하고, 비정상 상태에서 exit 1로 종료되는가?

**상태: ✅ 충족**

`monitor.sh:60-68`
```bash
if ! check_process; then
    echo "[...] [ERROR] Process agent-app is not running" >> "$LOG_FILE"
    exit 1
fi
if ! check_port; then
    echo "[...] [ERROR] Port ${AGENT_PORT}/tcp is not LISTEN" >> "$LOG_FILE"
    exit 1
fi
```
`check_process`는 `pgrep -f`, `check_port`는 `ss -tlunp | grep`으로 구현. 둘 중 하나라도 실패하면 즉시 `exit 1`.

### 6) `/var/log/agent-app/monitor.log`가 지정 포맷으로 누적 기록되는가?

**상태: ✅ 충족**

```
$ tail -3 logs/monitor.log
[2026-08-01 10:10:02] PID:192 CPU:0.0% MEM:4.1% DISK_USED:1%
[2026-08-01 10:11:01] PID:192 CPU:0.0% MEM:4.0% DISK_USED:1%
[2026-08-01 10:12:01] PID:192 CPU:0.0% MEM:5.3% DISK_USED:1%
```
`[YYYY-MM-DD HH:MM:SS] PID:.. CPU:..% MEM:..% DISK_USED:..%` 포맷 그대로 일치. 현재까지 3,464줄 누적, `>>`로 이어쓰기 확인됨.

### 7) crontab 매분 실행으로 monitor.log가 자동 증가하는가?

**상태: ✅ 충족**

```bash
$ docker exec -u agent-admin auto-monitoring-lab crontab -l
* * * * * /home/agent-admin/agent-app/bin/monitor.sh
```
위 6번의 로그가 실제로 1분 간격(09:53, 09:54, ... 10:12)으로 계속 누적되고 있음을 타임스탬프로 확인함 — 별도 대기 없이 기존 로그만으로 자동 증가가 증빙됨.

### 8) monitor.log 용량 관리(10MB/10개)가 설정되어 있고 동작을 설명할 수 있는가?

**상태: ✅ 충족 (스크립트 로직 방식)**

`monitor.sh:10-15, 45-57` — `LOG_MAX_SIZE=10MB`, `LOG_MAX_FILES=10`. `rotate_log()`가 매 실행마다 `stat -c%s`로 현재 파일 크기를 확인하고, 10MB 이상이면 `monitor.log.9→10 (삭제)`, `...`, `monitor.log→monitor.log.1` 순서로 회전.

### (보충) 디렉토리 구조 및 권한 — MISSION 체크리스트 4번

**상태: ✅ 충족** (평가 폼 항목1에는 없지만 수행 내역서 필수 증거이므로 함께 정리)

```bash
$ docker exec auto-monitoring-lab ls -ld $AGENT_HOME $AGENT_HOME/bin $AGENT_HOME/upload_files $AGENT_HOME/api_keys /var/log/agent-app
drwxr-xr-x agent-admin agent-common  /home/agent-admin/agent-app
drwxr-x--- agent-dev   agent-core    /home/agent-admin/agent-app/bin
drwxrwx--- agent-admin agent-common  /home/agent-admin/agent-app/upload_files
drwxrwx--- agent-dev   agent-core    /home/agent-admin/agent-app/api_keys
drwxrwx--- root        root          /var/log/agent-app     ← 아래 참고
```

권한 정책은 전부 [setup.sh:23-36](../src/setup.sh#L23-L36)에 모여 있다. Dockerfile이 아니라 setup.sh에 둔 이유는, `/var/log/agent-app`가 호스트 `./logs`의 바인드 마운트라 **빌드 시점에 설정한 권한이 컨테이너 시작 시 마운트로 덮이기 때문**이다. 마운트가 끝난 런타임(setup.sh)에 적용해야 유효하다.

⚠️ **환경적 예외**: 위 출력에서 `/var/log/agent-app`만 `root root`로 보인다. OrbStack(macOS)의 바인드 마운트는 **`chmod`는 반영하지만 `chown`은 exit 0을 반환하면서 무시**하기 때문이다(실측 확인). 순수 Linux 호스트에서는 `agent-admin:agent-core 770`으로 정상 적용된다. 코드는 올바르고, 환경 제약이라고 설명하면 된다.

---

## 항목2. 구현 방식 설명

### 1) monitor.sh에서 프로세스 식별(pgrep/ps 등)과 포트 확인(ss/netstat 등)에 사용한 명령과 선택 이유

- **프로세스**: `pgrep -f "$AGENT_HOME/agent-app$"` (health check), `pgrep -f "agent-app" | head -1` (PID 조회용).
  - `pgrep`을 고른 이유: `ps aux | grep`은 **grep 프로세스 자신이 결과에 잡히는** 고질적 오탐이 있고(그래서 `grep -v grep`을 덧붙이게 된다), `pgrep`은 PID만 깔끔히 반환해 스크립트에서 다루기 쉽다.
  - `-f`는 프로세스 이름이 아니라 **실행 명령행 전체**에서 매칭한다. 앱이 PyInstaller 바이너리라 이름만으로는 식별이 불안정해서 필요하다.
  - 패턴을 `agent-app`이 아니라 **전체 경로 + `$`(문자열 끝)** 로 쓴 이유: 그냥 `agent-app`이면 `/var/log/agent-app` 같은 경로가 명령행에 들어간 무관한 프로세스까지 잡힌다. 실제로 앱이 죽었는데도 살아있다고 오판할 수 있어서 앵커를 걸었다.
- **포트**: `ss -tlunp | grep ":${AGENT_PORT}"`. `netstat`은 최신 배포판(iproute2 계열)에서 deprecated 되어 `ss`가 표준 대체 도구이고, `-t`(TCP)/`-u`(UDP)/`-l`(LISTEN)/`-n`(숫자 포트)/`-p`(프로세스 정보)로 필요한 정보만 정확히 뽑아낼 수 있어 선택했다.

### 2) CPU/MEM/DISK 값을 어떤 방식으로 추출/파싱했고, 로그 포맷을 왜 그 형태로 고정했는지

- **CPU**: `top -bn1 | grep "%Cpu" | awk '{print $2}' | tr -d '%'` — `-b`(배치모드)로 비대화형 실행, `-n1`로 1회 스냅샷만 얻고 종료. `%Cpu` 라인의 2번째 필드(사용률)를 뽑아 `%` 기호 제거.
- **MEM**: `free | grep Mem | awk '{printf("%.1f", $3/$2*100.0)}'` — `free`의 Mem 행에서 `used($3)/total($2)*100`으로 직접 계산해 소수 1자리로 통일.
- **DISK**: `df / | tail -1 | awk '{print $5}' | tr -d '%'` — 루트 파티션의 `Use%` 컬럼만 추출.
- **임계값 비교에 `bc`를 쓴 이유**: 셸의 `[ ]`는 정수만 비교해서 `[ 25.3 -gt 20 ]`은 에러가 난다. CPU/MEM은 소수점 값이므로 `echo "25.3 > 20" | bc`로 비교하고, `bc`가 돌려주는 **참 1 / 거짓 0**을 `-eq 1`로 판정한다. DISK는 `df`가 정수 %만 주기 때문에 `bc` 없이 `[ -gt ]`로 처리한다.
- **로그 포맷 고정 이유**: `[YYYY-MM-DD HH:MM:SS] PID:.. CPU:..% MEM:..% DISK_USED:..%` 한 줄로 고정한 것은 (1) 시간순 정렬이 자연스럽고, (2) 나중에 `grep`/`awk`로 통계(평균/최대/최소, 보너스 report.sh)를 뽑기 쉽고, (3) 사람이 눈으로 읽어도 즉시 상태 파악이 가능하기 때문이다.

### 3) 소유자(agent-dev)와 실행자(agent-admin, cron) 권한 정책을 어떻게 만족시켰는지(소유/그룹/권한)

`setup.sh:62-64`에서 `monitor.sh`를 `chown agent-dev:agent-core`, `chmod 750`으로 설정. 즉:
- 소유자 `agent-dev` (rwx): 개발/수정 담당이므로 전체 권한.
- 그룹 `agent-core` (r-x): `agent-admin`도 `agent-core` 소속이므로 **읽기+실행**만으로 cron 실행이 가능. 굳이 그룹에 쓰기 권한을 주지 않아 최소 권한 원칙을 지켰다.
- 기타(`agent-test` 등) 권한 없음(`---`)으로 완전 차단.

cron은 `agent-admin`의 crontab에 등록되고, `agent-admin`이 `agent-core` 그룹에 속해 있기 때문에 그룹 실행 권한(`r-x`)만으로 정상 실행된다.

### 4) 용량 기반 로그 관리(10MB/10개)를 어떤 방식(logrotate/스크립트)으로 구현했는지

`logrotate`가 아니라 **스크립트 로직**(`monitor.sh`의 `rotate_log()`)으로 구현했다. 이유: `logrotate`는 별도 cron/systemd timer 및 설정 파일 관리가 추가로 필요하고, 이 과제 규모에서는 `monitor.sh` 실행 직전에 크기만 검사해 순차적으로 파일명을 밀어주는 것이 더 단순하고 의존성이 없다. 매 실행 시 `stat -c%s`로 크기 확인 → 10MB 이상이면 `.9→.10(삭제)` ~ `현재파일→.1` 순서로 역순 회전.

---

## 항목3. 보안/운영 원리 설명

### 1) SSH 포트 변경과 Root 접속 차단이 왜 보안에 효과적인지 (위협 모델 관점)

인터넷에 노출된 SSH의 가장 흔한 공격은 **봇넷의 22번 포트 자동 스캔 + 무차별 대입(brute-force)**이다. 포트를 20022로 바꾸면 이런 자동화된 대량 스캔 트래픽의 상당수를 걸러낼 수 있다(완전한 보안책은 아니고 "노이즈 감소" 성격 — security by obscurity). Root 로그인 차단은 위협 모델을 다르게 접근한다: root는 시스템 전체 권한을 가진 단일 계정이라 이 계정 하나만 뚫리면 전체가 함락되는 **단일 실패점(SPOF)**이 된다. 일반 계정 로그인 후 `sudo`로 승격하도록 강제하면, 공격자는 (1) 계정 정보를 얻고 (2) sudo 권한까지 별도로 획득해야 하므로 공격 단계가 늘어나고, 로그인 시도 자체가 계정명(`root` 고정이 아님)까지 맞춰야 해서 추측 난이도도 올라간다.

### 2) api_keys와 로그 디렉토리를 agent-core로 제한한 이유를 "최소 권한 원칙"으로

**최소 권한 원칙(Principle of Least Privilege)**: 각 주체는 자신의 역할 수행에 필요한 최소한의 권한만 가져야 한다. `api_keys`(비밀 키), `/var/log/agent-app`(운영 로그, 시스템 상태·PID 등 민감 정보 포함)는 QA 계정인 `agent-test`가 볼 필요가 없는 자원이다. 따라서 "운영/개발"을 담당하는 `agent-admin`/`agent-dev`만 묶은 `agent-core` 그룹에만 R/W를 주고, `agent-test`는 `agent-common`에만 속하게 해 원천적으로 접근을 차단했다. 이렇게 하면 `agent-test` 계정이 탈취되거나 실수로 잘못된 명령을 실행해도 키/로그 유출 위험이 없다.

> ⚠️ 꼬리질문 대비: **현재 개발 환경(OrbStack)에서는 `/var/log/agent-app`의 그룹이 `agent-core`가 아니라 `root`로 보인다.** 이건 정책을 안 걸어서가 아니라, OrbStack의 바인드 마운트가 `chmod`는 반영하면서 `chown`은 조용히 무시하기 때문이다(exit 0을 반환해서 스크립트는 성공한 것처럼 보인다). 순수 Linux 호스트에서는 정상 적용된다. 여기까지 설명하면 "왜 마운트된 경로는 권한 설정이 다르게 동작하는가"를 이해하고 있다는 걸 보여줄 수 있다.

### 3) "경고는 출력하되 종료하지 않는 항목"(방화벽 비활성/임계치 초과)을 분리한 운영상의 이유

Health Check(프로세스/포트)는 **앱이 실질적으로 서비스 불가능한 상태**이므로 더 이상 모니터링을 진행할 의미가 없어 `exit 1`로 즉시 종료한다. 반면 방화벽 비활성이나 CPU/MEM/DISK 임계치 초과는 **"위험 신호"이지만 서비스는 여전히 살아있는 상태**다. 이런 경우까지 스크립트를 종료시키면 (1) 정작 필요한 리소스 로그 기록 자체가 누락되고, (2) cron이 반복 실행되므로 매분 같은 경고가 계속 쌓여 운영자가 문제를 놓치지 않는다. 즉 "치명적 장애(종료)"와 "주의가 필요한 상태(경고만)"를 분리해서, 운영자가 로그만 보고도 심각도를 구분할 수 있게 설계한 것이다.

### 4) 리다이렉션 기호 `>`와 `>>`의 차이, 로그 누적에 `>>`가 필요한 이유

`>`는 파일을 **덮어쓰기**(파일이 없으면 생성, 있으면 기존 내용을 삭제하고 새로 씀)한다. `>>`는 **이어쓰기**(파일이 없으면 생성, 있으면 기존 내용 끝에 추가)한다. `monitor.log`는 cron이 매분 실행되며 "이력"을 남기는 것이 목적이므로, 매 실행 시 `>`를 쓰면 이전 1분 전의 기록이 통째로 사라져 시계열 데이터 자체가 존재할 수 없다. 따라서 `>>`로 계속 이어붙여야 장애 발생 시점의 CPU/MEM/DISK 추이를 시간순으로 추적할 수 있다.

---

## 항목4. 응용 시나리오 설명

### 1) 모니터링 대상이 웹 서버(Nginx 등)로 바뀐다면, monitor.sh에서 바꿔야 할 핵심 포인트

- **프로세스**: `check_process`의 `pgrep -f` 패턴을 `agent-app` → `nginx: master process` 등 실제 프로세스명/커맨드라인으로 교체.
- **포트**: `AGENT_PORT`(15034)를 80/443 등 Nginx가 실제로 바인딩하는 포트로 교체. `check_port`의 `ss -tlunp | grep ":${PORT}"` 로직 자체는 그대로 재사용 가능.
- **로그**: Nginx는 자체 access/error 로그(`/var/log/nginx/`)를 가지고 있으므로, monitor.sh는 그 로그를 직접 파싱하기보다 "Nginx 프로세스/포트/리소스 상태"만 자체 `monitor.log`에 남기는 역할로 유지하거나, 필요하면 Nginx 로그의 최근 오류 라인 수를 집계하는 로직을 추가.
- **임계값**: 웹서버는 트래픽에 따라 CPU/MEM 프로파일이 다르므로(동접 늘어날 때 CPU 급증 패턴 등), 20%/10%/80% 같은 임계값을 서비스 특성에 맞게 재산정해야 한다.

### 2) "프로세스는 살아있는데 포트가 안 열리는 상황"을 발견했다면, 원인 후보와 확인 순서

원인 후보(가능성 순):
1. **바인딩 주소/포트 설정 오류**: 앱이 실제로는 `127.0.0.1`에만 바인딩되어 `0.0.0.0`이 아닌 경우, 또는 설정 파일의 포트 값이 잘못된 경우.
2. **부팅/초기화 지연**: 프로세스는 떴지만 아직 리스닝 소켓을 열기 전 단계(초기화 중).
3. **권한 문제**: 1024 이하의 well-known 포트를 non-root로 열려다 실패(바인드 실패 후 죽지 않고 좀비처럼 남는 경우).
4. **포트 충돌**: 이미 다른 프로세스가 같은 포트를 점유해 바인드 실패.
5. **방화벽/네트워크 네임스페이스**: iptables/ufw 규칙이 로컬 바인딩 자체를 막는 경우는 드물지만, 컨테이너 네트워크 설정 문제일 수도 있음.

확인 순서: ① `ss -tlnp | grep <PID>`로 해당 PID가 실제로 어떤 포트를 열고 있는지 확인 → ② 없다면 앱 로그(stdout/stderr, 여기선 `agent_app.log`)에서 바인드 에러/예외 확인 → ③ 앱 설정 파일의 포트/주소 값 확인 → ④ `netstat`/`ss`로 포트 충돌 여부(다른 PID가 이미 점유했는지) 확인 → ⑤ 필요 시 프로세스를 재시작해 초기화 지연 여부 배제.

### 3) 로그가 급증해 디스크가 가득 찰 위험이 있다면, 운영자가 취할 대응(단기/중기)

- **단기(즉시)**: 오래된 로그부터 압축/삭제해 디스크 공간 즉시 확보(`monitor.sh`의 `rotate_log()`가 10MB/10개 기준으로 이미 자동 수행). 급한 경우 수동으로 `df -h`로 공간 확인 후 가장 오래된 `.log.N` 파일부터 정리.
- **중기(재발 방지)**: (보너스 과제와 동일한 방향) 시간 기반 보존 정책 도입 — 7일 경과 로그는 압축, 30일 경과 압축본은 삭제하는 배치를 cron에 추가. 또한 근본적으로 로그가 급증한 원인(예: 비정상 반복 에러로 ERROR 라인이 폭증)을 찾아 애플리케이션/스크립트 단의 원인을 고쳐야 하고, 필요하다면 로그 디렉토리를 별도 파티션/볼륨으로 분리해 루트 파티션 자체가 가득 차는 것을 방지한다.

---

## 항목5. 보너스 (선택)

**상태: ❌ 미구현**

- `report.sh`(monitor.log 통계 요약): 미작성. 구현한다면 `awk`로 `CPU:`, `MEM:` 값을 파싱해 평균/최대/최소, 샘플 수 산출.
- 시간 기반 로그 보존 정책(7일 압축 → 아카이브 이동 → 30일 삭제): 미작성. `find /var/log/agent-app -name "*.log" -mtime +7 -exec gzip {} \;` 류의 로직을 별도 스크립트(예: `retention.sh`)로 만들고 cron에 매일 1회 등록하면 된다.

선택 과제이므로 미구현 자체는 기본 점수에 영향이 없으나, 크레딧(100)을 받으려면 위 두 스크립트 중 하나 이상을 구현해야 한다.
