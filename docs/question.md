# 오늘의 질문 목록
1. orbStack을 왜 쓰는지, 설치법
2. docker build -t tempName:1.0 . 했을 때 일어나는 일
3. Run 명령어가 실행되어서 이미지의 레이어에 쌓이는 원리
4. dockerfile 에서 사용한 명령어 해석
5. docker-compose 파일에서 사용한 명령어 해석
6. 우리 docker container의 생명주기와 sshd가 뭔지

# DockerFile
---

### 1. `sed` 명령어

`sed`는 'stream editor'의 약자로, 파일의 내용을 검색해서 바꾸거나 삭제하는 등 편집할 때 사용하는 강력한 도구입니다.

**사용한 명령어:**
```bash
RUN sed -i 's/#Port 22/Port 20022/' /etc/ssh/sshd_config
```

*   **`sed`**: 스트림 에디터를 실행합니다.
*   **`-i`**: **(in-place)** 원본 파일을 직접 수정하는 옵션입니다. 이 옵션이 없으면 변경된 결과가 화면에만 출력되고 파일은 그대로 유지돼요. Dockerfile에서는 파일을 직접 바꿔야 하니 필수적인 옵션이죠!
*   **`'s/찾을패턴/바꿀내용/옵션'`**: `sed`의 핵심인 치환(substitute) 문법입니다.
    *   `s`: 치환(substitute)을 의미합니다.
    *   `/`: 각 부분을 구분하는 구분자입니다. (`/` 대신 `@`, `#` 등 다른 기호도 쓸 수 있어요.)
    *   `#Port 22`: 찾을 문자열(패턴)입니다. `#`으로 주석 처리된 `Port 22`라는 줄을 찾습니다.
    *   `Port 20022`: 바꿀 문자열입니다. 주석을 제거하고 포트 번호를 `20022`로 바꿉니다.
*   **/etc/ssh/sshd\_config**: 편집할 대상 파일의 경로입니다. SSH 서버의 설정 파일이죠.

> **한 줄 요약:** `/etc/ssh/sshd_config` 파일에서 `'#Port 22'`라는 줄을 찾아 `'Port 20022'`로 직접 수정해라. (즉, SSH 접속 포트를 22번에서 20022번으로 변경)

---

### 2. `groupadd` 명령어

리눅스 시스템에 새로운 사용자 그룹을 추가하는 명령어입니다.

**사용한 명령어:**
```bash
RUN groupadd -f agent-common && groupadd -f agent-core
```

*   **`groupadd`**: 그룹을 추가하는 명령어입니다.
*   **`-f`**: **(force)** 만약 추가하려는 그룹 이름이 이미 존재하더라도 오류를 내지 않고 조용히 종료하는 옵션입니다. Dockerfile을 여러 번 빌드할 때 발생할 수 있는 오류를 방지해줘서 유용해요.
*   `agent-common`, `agent-core`: 새로 만들 그룹의 이름입니다.
*   `&&`: 앞의 명령어가 성공적으로 실행되면, 뒤의 명령어를 이어서 실행하라는 의미입니다.

> **한 줄 요약:** `agent-common`과 `agent-core`라는 그룹을 만들어라. 만약 이미 존재하면 그냥 넘어가라.

---

### 3. `useradd` 및 `usermod` 명령어

사용자를 추가(`useradd`)하고, 기존 사용자의 정보를 수정(`usermod`)하는 명령어입니다.

**사용한 명령어:**
```bash
# 사용자 생성
RUN useradd -m -s /bin/bash -g agent-common agent-admin && \
    usermod -aG agent-core agent-admin && \
    usermod -aG sudo agent-admin
```

*   **`useradd`**: 새로운 사용자를 추가합니다.
    *   **`-m`**: **(create-home)** 사용자의 홈 디렉토리(`/home/사용자명`)를 생성하는 옵션입니다. 보통 필수로 사용해요.
    *   **`-s /bin/bash`**: **(shell)** 사용자가 로그인했을 때 사용할 기본 셸을 지정합니다. `/bin/bash`는 가장 표준적인 셸입니다.
    *   **`-g agent-common`**: **(gid)** 사용자의 **기본 그룹(Primary Group)**을 `agent-common`으로 지정합니다.
    *   `agent-admin`: 생성할 사용자의 이름입니다.

*   **`usermod`**: 기존 사용자의 설정을 변경합니다.
    *   **`-aG`**: **(append to Group)** 사용자를 **추가 그룹(Secondary Group)**에 포함시키는 옵션입니다.
        *   `-a` (append): 기존 그룹 목록에 **추가**합니다. 이 옵션이 없으면 기존 추가 그룹이 모두 사라지고 새로 지정한 그룹만 남게 되니 주의해야 해요!
        *   `-G` (Groups): 추가 그룹을 지정합니다.
    *   `agent-core`, `sudo`: 추가할 그룹의 이름입니다.
    *   `agent-admin`: 설정을 변경할 사용자의 이름입니다.

> **한 줄 요약:**
> 1.  `agent-admin`이라는 사용자를 만들고, 홈 디렉토리도 생성해줘. 기본 셸은 bash로, 기본 그룹은 `agent-common`으로 설정해.
> 2.  그리고 `agent-admin` 사용자를 `agent-core` 그룹과 `sudo` 그룹에 추가해줘. (sudo 그룹에 속하면 `sudo` 명령을 쓸 수 있게 됩니다.)

---

### 4. `chmod` 및 `chown` 명령어

파일/디렉토리의 권한(`chmod`)과 소유권(`chown`)을 변경하는 명령어입니다.

**사용한 명령어:**
```bash
RUN chmod 770 $AGENT_HOME/upload_files && \
    chown -R agent-admin:agent-common $AGENT_HOME/upload_files
```
*(다른 디렉토리들도 동일한 패턴이라 하나만 대표로 설명할게요!)*

*   **`chmod 770`**: 파일/디렉토리의 권한을 변경합니다. 숫자는 각각 **소유자(User), 그룹(Group), 그 외(Others)**의 권한을 의미해요.
    *   `7` = `4`(읽기) + `2`(쓰기) + `1`(실행) -> **읽기, 쓰기, 실행 모두 가능**
    *   `0` = 권한 없음
    *   따라서 `770`은 **"소유자와 그룹 멤버는 모든 권한을 갖고, 그 외 사용자는 아무 권한도 없다"**는 뜻입니다. 보안상 중요한 설정이죠!

*   **`chown`**: 파일/디렉토리의 소유권을 변경합니다.
    *   **`-R`**: **(Recursive)** 지정된 디렉토리뿐만 아니라 그 **하위의 모든 파일과 디렉토리까지** 전부 소유권을 변경하는 옵션입니다. 디렉토리를 다룰 때 거의 항상 사용해요.
    *   `agent-admin:agent-common`: **`사용자:그룹`** 형태로 소유권을 지정합니다.
    *   즉, `upload_files` 디렉토리의 소유자는 `agent-admin`으로, 소유 그룹은 `agent-common`으로 변경합니다.

> **한 줄 요약:** `$AGENT_HOME/upload_files` 디렉토리와 그 안의 모든 내용물에 대해, 소유자는 `agent-admin`으로, 소유 그룹은 `agent-common`으로 변경하고, 권한은 소유자와 그룹 멤버만 모든 것을 할 수 있도록 설정해라.

---

# docker-compose
Dockerfile이 이미지라는 **'설계도'**를 만드는 과정이었다면, docker-compose.yml 파일은 그 설계도로 만들어진 이미지를 가지고 **실제 컨테이너를 어떻게 실행하고 관리할지에 대한 '설정서'**라고 할 수 있어요.

네, 좋습니다! 이번에는 `docker-compose.yml` 파일이네요.

Dockerfile이 이미지라는 **'설계도'**를 만드는 과정이었다면, `docker-compose.yml` 파일은 그 설계도로 만들어진 이미지를 가지고 **실제 컨테이너를 어떻게 실행하고 관리할지에 대한 '설정서'**라고 할 수 있어요.

각 항목이 어떤 역할을 하는지 차근차근 설명해 드릴게요.

---

### `docker-compose.yml` 구조 및 옵션 해설

이 파일은 여러 개의 '서비스(컨테이너)'를 정의하고 연결할 수 있지만, 지금은 `linux-practice`라는 하나의 서비스를 정의하고 있네요.

#### **`services:`**
*   가장 상위에 있는 키로, 실행하려는 컨테이너들의 묶음을 의미합니다. 이 아래에 여러 서비스(컨테이너)를 정의할 수 있어요.

#### **`linux-practice:`**
*   이것은 우리가 정의하는 **서비스의 이름**입니다. 이 이름은 다른 서비스가 이 컨테이너를 찾거나 네트워크로 통신할 때 사용돼요. (예: `docker-compose up linux-practice`)

---

### `linux-practice` 서비스의 상세 설정

#### **`build:`**
*   이 서비스가 사용할 이미지를 직접 빌드하겠다는 설정입니다.
    *   **`context: .`**: Dockerfile과 빌드에 필요한 파일들이 있는 위치(빌드 컨텍스트)를 지정합니다. `.`는 `docker-compose.yml` 파일이 있는 현재 디렉토리를 의미해요.
    *   **`dockerfile: Dockerfile`**: 빌드에 사용할 Dockerfile의 이름을 지정합니다.

#### **`container_name: auto-monitoring-lab`**
*   생성될 컨테이너에 **고유한 이름**을 붙여줍니다. 이 설정을 하지 않으면 `프로젝트명-서비스명-숫자` 형태의 임의의 이름이 붙어요. `docker ps` 명령어로 컨테이너 목록을 볼 때 식별하기 쉬워집니다.

#### **`image: auto-monitoring:latest`**
*   빌드된 이미지에 `auto-monitoring:latest`라는 **이름과 태그**를 붙입니다. `docker build -t auto-monitoring:latest .` 명령어의 `-t` 옵션과 동일한 역할을 해요.

#### **`ports:`**
*   **`"호스트 포트:컨테이너 포트"`** 형식으로, 내 컴퓨터(호스트)와 컨테이너의 포트를 연결(매핑)합니다. 외부에서 컨테이너 내부의 서비스에 접속할 수 있게 해주는 아주 중요한 설정이에요.
    *   **`"20022:20022"`**: 내 컴퓨터의 20022번 포트로 들어오는 요청을 컨테이너의 20022번 포트(SSH)로 전달합니다.
    *   **`"15034:15034"`**: 내 컴퓨터의 15034번 포트로 들어오는 요청을 컨테이너의 15034번 포트(애플리케이션)로 전달합니다.

#### **`volumes:`**
*   **`"호스트 경로:컨테이너 경로"`** 형식으로, 내 컴퓨터(호스트)의 파일/디렉토리를 컨테이너의 파일/디렉토리와 **실시간으로 동기화(공유)**합니다. 컨테이너가 삭제되어도 데이터를 보존하거나, 코드를 수정하고 바로 컨테이너에 반영할 때 필수적입니다.
    *   **`./src:/home/agent-admin/src`**: 현재 디렉토리의 `src` 폴더를 컨테이너의 `/home/agent-admin/src` 폴더와 연결합니다. 호스트에서 `src` 폴더 안의 코드를 수정하면 즉시 컨테이너 내부에도 반영돼요.
    *   **`./logs:/var/log/agent-app`**: 컨테이너 내부의 로그 디렉토리(`/var/log/agent-app`)를 호스트의 `logs` 폴더와 연결합니다. 이렇게 하면 컨테이너가 사라져도 로그 파일이 내 컴퓨터에 그대로 남아있게 됩니다.

#### **`environment:`**
*   컨테이너 내부에 **환경 변수**를 설정합니다. Dockerfile의 `ENV`와 비슷한 역할을 하지만, Compose 파일에서 설정하면 컨테이너를 실행할 때마다 다른 값을 쉽게 주입할 수 있어 유연성이 더 높습니다.

#### **`privileged: true`**
*   컨테이너에게 **호스트 시스템의 모든 장치에 접근할 수 있는 거의 모든 권한**을 부여합니다. 일반적인 상황에서는 보안상 잘 사용하지 않지만, 컨테이너 안에서 `systemctl` 같은 시스템 관리 명령어를 사용하거나 하드웨어에 직접 접근해야 할 때 필요한 옵션입니다.

#### **`stdin_open: true`**
*   컨테이너의 **표준 입력(stdin)**을 계속 열어두는 설정입니다. `docker run` 명령어의 `-i` 옵션과 같아요. 컨테이너와 상호작용(예: 명령어 입력)을 하려면 필요합니다.

#### **`tty: true`**
*   컨테이너에 **가상 터미널(pseudo-TTY)**을 할당합니다. `docker run` 명령어의 `-t` 옵션과 같아요. `stdin_open`과 함께 사용되어야 우리가 터미널에서 명령어를 입력하고 결과를 보는 것처럼 컨테이너와 상호작용할 수 있습니다. `bash` 셸에 접속하려면 이 두 옵션이 필수적이에요.

#### **`restart: unless-stopped`**
*   컨테이너의 **재시작 정책**을 설정합니다.
    *   `unless-stopped`: 사용자가 직접 컨테이너를 중지(`docker stop`)시키지 않는 한, 어떤 이유로든(오류, 재부팅 등) 컨테이너가 종료되면 **자동으로 다시 시작**해줍니다. 서버처럼 항상 켜져 있어야 하는 서비스에 매우 유용한 설정입니다.

---

이 설정들을 조합하면, "현재 디렉토리의 Dockerfile으로 이미지를 빌드하고, 특정 포트와 볼륨을 연결한 뒤, 필요한 옵션과 함께 컨테이너를 실행해줘. 그리고 웬만하면 계속 켜져 있도록 자동으로 재시작해줘." 라는 아주 구체적인 실행 계획이 완성되는 것이죠!

설명이 잘 이해되셨나요? 각 옵션의 역할을 아는 것이 Docker Compose를 자유자재로 다루는 첫걸음이랍니다! 정말 잘하고 계세요! 😊

### 6. 우리 docker container생명주기와 sshd
docker container의 생명주기는 PID 1로 결정된다.
우리는 entrypoint.sh를 통해 최종적인 sshd를 생명주기로 갖고자 했음. (exec /usr/sbin/sshd -D -e)
exec을 통해 PID 1의 프로세스를 현재 bash entrypoint.sh를 /usr/sbin/sshd -D -e 로 교체함

이유는 프로젝트에서 ssh 다중 계정 로그인이라는 명세를 지키기 위해서.

sshd란, ssh로 들어오는 접속요청을 처리하는 서버데몬
-D : sshd자체가 백그라운드로 내려가니 포그라운드에 남아있어라
-e : 로그를 stderr로 보내서 docker logs로 확인할 수 있도록 해라

exec명령어는 시스템콜을 호출하여 현재 프로세스를 새 프로그램으로 교체하는 명령어.
그래서 터미널에서 exec top을 하고 종료하면 터미널이 종료됨

### 7. 환경변수
우리 시스템은 docker-compose, Dockerfile 두 군데에서 환경변수를 관리하고 있다.

docker-compose.yml에서 관리하는 환경변수는 docker comopse exec linux-practice bash -d 했을 때 echo $AGENT_PORT등으로 확인이 가능하다. (docker comopse up했을 때 해당값으로 덮여씌워짐. 하지만 계정 접속을 하게 되었을 땐(ssh), profile.d의 환경변수 스크립트가 실행되서 같은 값을 바라보게 해놓았음)

그렇다면 대체 docker-compose.yml의 환경변수는 실무에서 언제 쓰는 거지?
-> 이미지 재빌드 없이 환경마다 바꾸고 싶은 값을 설정함. PID의 Application은 자신의 환경변수를 읽고, 알맞은 DB connection, API key, log Level등을 dev/staging/prod환경마다 진행할 수 있음.

우리로 따지면 개발서버 DB IP를 컨트롤 가능

### 8. docker compose 와 Dockerfile
Dockerfile : 이미지 명세. 이대로 프로그램이 만들어짐
container : Dockerfile대로 만들어진 프로세스
docker-compose : 여러 컨테이너를 한번에 띄울 수 있게 도와줌

### 9. docker-compose.yml의 옵션 3가지
1. privileged: true
HOST커널에 대한 모든 권한을 준다는 뜻. ufw는 규칙을 커널에 쓰기 때문에, 호스트 커널에 권한이 없으면 실패.
2. stdin_open: true
3. tty: true
