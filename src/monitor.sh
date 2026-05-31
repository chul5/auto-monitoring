#!/bin/bash
set -euo pipefail

# cron은 /etc/profile.d를 자동 소싱하지 않으므로 명시적으로 로드
source /etc/profile.d/agent-app.sh

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="${AGENT_LOG_DIR}/monitor.log"

CPU_THRESHOLD=20
MEM_THRESHOLD=10
DISK_THRESHOLD=80

LOG_MAX_SIZE=$((10 * 1024 * 1024))  # 10MB
LOG_MAX_FILES=10

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
    echo "[${TIMESTAMP}] [ERROR] Process agent-app is not running" >> "$LOG_FILE"
    exit 1
fi

if ! check_port; then
    echo "[${TIMESTAMP}] [ERROR] Port ${AGENT_PORT}/tcp is not LISTEN" >> "$LOG_FILE"
    exit 1
fi

# ===== 방화벽 상태 경고 (종료 없음) =====
if ! check_firewall; then
    echo "[${TIMESTAMP}] [WARNING] Firewall is not active" >> "$LOG_FILE"
fi

# ===== 자원 수집 =====
APP_PID=$(get_pid)
CPU_USAGE=$(get_cpu_usage)
MEMORY_USAGE=$(get_memory_usage)
DISK_USAGE=$(get_disk_usage)

# ===== 임계값 경고 =====
if awk "BEGIN{exit !($CPU_USAGE > $CPU_THRESHOLD)}"; then
    echo "[${TIMESTAMP}] [WARNING] CPU threshold exceeded (${CPU_USAGE}% > ${CPU_THRESHOLD}%)" >> "$LOG_FILE"
fi

if awk "BEGIN{exit !($MEMORY_USAGE > $MEM_THRESHOLD)}"; then
    echo "[${TIMESTAMP}] [WARNING] MEM threshold exceeded (${MEMORY_USAGE}% > ${MEM_THRESHOLD}%)" >> "$LOG_FILE"
fi

if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
    echo "[${TIMESTAMP}] [WARNING] DISK threshold exceeded (${DISK_USAGE}% > ${DISK_THRESHOLD}%)" >> "$LOG_FILE"
fi

# ===== 로그 회전 후 기록 =====
rotate_log

echo "[${TIMESTAMP}] PID:${APP_PID} CPU:${CPU_USAGE}% MEM:${MEMORY_USAGE}% DISK_USED:${DISK_USAGE}%" >> "$LOG_FILE"
