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

# 환경 변수 설정
RUN mkdir -p /home/agent-admin/agent-app/bin \
    && mkdir -p /home/agent-admin/agent-app/upload_files \
    && mkdir -p /home/agent-admin/agent-app/api_keys
ENV AGENT_HOME=/home/agent-admin/agent-app
ENV AGENT_PORT=15034
ENV AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
ENV AGENT_KEY_PATH=$AGENT_HOME/api_keys/t_secret.key
ENV AGENT_LOG_DIR=/var/log/agent-app

RUN echo "export AGENT_HOME=${AGENT_HOME}\nexport AGENT_PORT=${AGENT_PORT}\nexport AGENT_UPLOAD_DIR=${AGENT_UPLOAD_DIR}\nexport AGENT_KEY_PATH=${AGENT_KEY_PATH}\nexport AGENT_LOG_DIR=${AGENT_LOG_DIR}" > /etc/profile.d/agent-app.sh

# 디렉토리 권한 설정
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

# SSH 포트 노출
EXPOSE 20022 15034

# SSH 서버 시작
CMD ["/usr/sbin/sshd", "-D", "-e"]