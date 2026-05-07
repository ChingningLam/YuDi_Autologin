#!/bin/bash

# 自己改一下username和password  只动-后面的纯数字

USERNAME="${1:-1145141919810}"
PASSWORD="${2:-114514}"

# 获取 WAN 网卡和 MAC 地址
get_wan_info() {
    local wan_nic=$(ip route | grep default | awk '{print $5}' | head -1)
    [ -z "$wan_nic" ] && wan_nic="eth0"
    
    local wan_mac=$(ip addr show "$wan_nic" 2>/dev/null | grep -i "link/ether" | awk '{print tolower($2)}')
    echo "$wan_mac"
}

# 获取 WAN IP
get_wan_ip() {
    local wan_nic=$(ip route | grep default | awk '{print $5}' | head -1)
    [ -z "$wan_nic" ] && wan_nic="eth0"
    
    local wan_ip=$(ip addr show "$wan_nic" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
    echo "$wan_ip"
}

# 获取真实 MAC 地址
REAL_MAC=$(get_wan_info)

echo "net start:$(date +%F-%T)" >>/root/net.log

while true; do
    ping -c1 -W1 119.29.29.29 >/dev/null 2>&1 && { sleep 3; continue; }
    
    wlanacip=$(get_wan_ip)
    [ -z "$wlanacip" ] && { sleep 3; continue; }
    
    SESSION=$(mktemp)
    
    echo "Auth: $(date +%F-%T)" >>/root/net.log
    
    # 获取 CSRF Token
    CSRF=$(curl -s -c "$SESSION" -b "$SESSION" "http://172.168.2.100/api/csrf-token" 2>&1 | sed -n 's/.*"csrf_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    
    if [ -n "$CSRF" ]; then
        # 方式1: CSRF Token 认证
        RESP=$(curl -s -X POST "http://172.168.2.100/api/account/login" \
            -c "$SESSION" -b "$SESSION" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -H "X-CSRF-Token: $CSRF" \
            -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" \
            --data "username=$USERNAME&password=$PASSWORD&nasId=1&userIpv4=$wlanacip&userMac=$REAL_MAC" 2>&1)
        
        if echo "$RESP" | grep -q '"code":0'; then
            echo "Success: $(date +%F-%T)" >>/root/net.log
            rm -f "$SESSION"
            sleep 10
            continue
        fi
    fi
    
    # 方式2: 备选认证  自己改一下认证地址
    curl -fs -c "$SESSION" -b "$SESSION" \
        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
        "http://172.168.2.100/tpl/yourschool/login_account.html?ip=$wlanacip&nasId=1" > /dev/null 2>&1
    
    RESP=$(curl -s -X POST "http://172.168.2.100/account/login?ip=$wlanacip&nasId=1" \
        -c "$SESSION" -b "$SESSION" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" \
        --data "username=$USERNAME&password=$PASSWORD&userMac=$REAL_MAC" 2>&1)
    
    [ -n "$RESP" ] && echo "Response: ${RESP:0:50}" >>/root/net.log
    
    echo "Retry: $(date +%F-%T)" >>/root/net.log
    rm -f "$SESSION"
    sleep 10
    
done
