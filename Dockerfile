FROM ubuntu:24.04

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
    cron \
    acl \
    bc \
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

# 계정 비밀번호 설정
RUN echo "agent-admin:qwe123" | chpasswd && \
    echo "agent-dev:qwe123" | chpasswd && \
    echo "agent-test:qwe123" | chpasswd

# 디렉토리 구조 생성
RUN mkdir -p /home/agent-admin/agent-app/bin \
    && mkdir -p /home/agent-admin/agent-app/upload_files \
    && mkdir -p /home/agent-admin/agent-app/api_keys

# 환경 변수 기본값. docker-compose.yml의 environment로 덮어쓸 수 있다.
# 이 값을 /etc/profile.d로 내보내는 일은 setup.sh가 런타임에 한다.
# (빌드 시점에 구우면 compose로 덮어쓴 값과 어긋나 진실이 두 개가 된다)
ENV AGENT_HOME=/home/agent-admin/agent-app
ENV AGENT_PORT=15034
ENV AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
ENV AGENT_KEY_PATH=$AGENT_HOME/api_keys/t_secret.key
ENV AGENT_LOG_DIR=/var/log/agent-app

# 디렉토리 권한은 setup.sh가 런타임에 적용한다.
# (바인드 마운트가 이미지의 권한을 덮어쓰므로 빌드 시점에 설정해도 무의미)

# SSH 포트 노출
EXPOSE 20022 15034

# 컨테이너 시작 시 setup.sh로 런타임 설정을 마친 뒤, sshd로 프로세스를 교체해 PID 1을 넘긴다.
# setup.sh는 ./src 볼륨 마운트로 들어오므로 이미지에 COPY하지 않는다 (수정 시 재빌드 불필요).
# 마운트된 파일은 호스트 권한(644)을 그대로 쓰므로 실행 권한에 의존하지 않도록 bash로 호출한다.
CMD ["/bin/bash", "-c", "bash /home/agent-admin/src/setup.sh && exec /usr/sbin/sshd -D -e"]