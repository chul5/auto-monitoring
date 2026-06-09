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