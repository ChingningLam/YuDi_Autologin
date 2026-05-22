#!/bin/bash

# ================= 配置区域 =================
USERNAME="1145141919810"      # 你的账号
PASSWORD="114514"           # 你的密码
AUTH_SERVER="172.168.2.100" # 认证服务器 IP
INTERFACE="eth0"            # 使用的网卡名称
NASID="1"                   # 固定的 NASID
MAX_RETRIES=10              # 遇到封禁时的最大重试次数
# ============================================

echo "[*] 开始执行自动登录流程..."

# 安全创建并管理会话文件
SESSION=$(mktemp)
trap 'rm -f "$SESSION"; echo "[*] 临时会话文件已清理。"' EXIT

RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if [ $RETRY_COUNT -gt 0 ]; then
        echo "----------------------------------------"
        echo "[*] 正在进行第 $RETRY_COUNT 次重试..."
    fi

    # 1. 检查网卡是否已经获取到 IP 地址
    echo "[*] 检查网络接口 $INTERFACE 状态..."
    IP_CHECK=$(ip -4 addr show "$INTERFACE" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)

    if [ -z "$IP_CHECK" ]; then
        echo "[-] 警告: $INTERFACE 未检测到有效 IPv4 地址。等待 5 秒后重试检查..."
        sleep 5
        continue # IP没拿到，跳过本次循环，重新检查
    fi
    echo "[+] 当前网卡 IP 地址: $IP_CHECK"

    # 2. 获取 CSRF Token
    echo "[*] 正在连接 $AUTH_SERVER 获取 CSRF Token..."
    CSRF_TOKEN=$(curl -s -c "$SESSION" -b "$SESSION" \
        --connect-timeout 5 -m 10 \
        "http://$AUTH_SERVER/api/csrf-token" | sed -n 's/.*"csrf_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

    if [ -z "$CSRF_TOKEN" ]; then
        echo "[-] 错误: 无法获取 CSRF Token，网关可能无响应，3秒后重试..."
        sleep 3
        continue
    fi
    echo "[+] 成功提取 CSRF Token."

    # 3. 提交表单执行登录
    echo "[*] 正在提交登录凭证..."
    RESPONSE=$(curl -s -X POST "http://$AUTH_SERVER/api/account/login" \
        -c "$SESSION" -b "$SESSION" \
        --connect-timeout 5 -m 15 \
        -H "content-type: application/x-www-form-urlencoded" \
        -H "x-csrf-token: $CSRF_TOKEN" \
        --data "username=$USERNAME&password=$PASSWORD&switchip=&nasId=$NASID&userIpv4=&userMac=&captcha=&captchaId=")

    echo "[*] 认证服务器响应内容:"
    echo "$RESPONSE"

    # 4. 判断是否被封禁
    if echo "$RESPONSE" | grep -q 'E20021\|禁用十分钟\|代理行为'; then
        echo "[-] 警告: 检测到账号/设备被封禁！"
        echo "[*] 正在为你生成并更换随机 MAC 地址..."
        
        # 随机生成首字节为 02 的本地管理 MAC 地址
        NEW_MAC=$(printf '02:%02x:%02x:%02x:%02x:%02x\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
        echo "[+] 新 MAC 地址: $NEW_MAC"

        # 修改网卡 MAC
        ip link set dev "$INTERFACE" down
        ip link set dev "$INTERFACE" address "$NEW_MAC"
        ip link set dev "$INTERFACE" up

        echo "[*] 网卡已重启，等待 11 秒获取新 IP..."
        sleep 11
        
        ((RETRY_COUNT++))
        continue # 回到循环开头重新走流程
    else
        echo "[+] 登录流程执行完毕，未检测到封禁提示。"
        break # 只要没报封禁错误，就跳出循环往下走
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "[-] 达到最大重试次数，脚本退出。"
fi

# 5. 验证网络连通性 (改为 ping 223.6.6.6)
echo "[*] 正在测试外网连通性 (223.6.6.6)..."
if ping -c 1 -W 2 223.6.6.6 > /dev/null 2>&1; then
    echo "[+] 网络已连通！大吉大利。"
else
    echo "[-] 警告: 无法 Ping 通 223.6.6.6。如果刚换完 MAC，可能账号仍在冷却期，或需等待 DHCP 生效。"
fi
