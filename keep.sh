#!/bin/bash

# ================= 配置区域 =================
LOGIN_SCRIPT="/root/n.sh"      # 你的自动登录脚本路径
CHECK_INTERVAL=1               # 日常巡检间隔时间（秒）
LOG_FILE="/tmp/keep.log"  # 日志文件路径
# ============================================

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 守护进程启动，开始极速监控真实网络状态..." >> "$LOG_FILE"

# 定义一个专门检测真实网络（防校园网劫持）的函数
check_real_net() {
    # 使用 curl 访问 Cloudflare 的 204 测试接口
    # -s: 静默模式, -o /dev/null: 丢弃网页内容, -w "%{http_code}": 只输出状态码
    # --connect-timeout 2 -m 2: 最大连接和执行时间 2 秒
    local status=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 2 -m 2 http://cp.cloudflare.com/generate_204)
    
    # 只有真正连通外网时，Cloudflare 才会返回准确的 204
    # 如果被校园网拦截，通常会返回 302/301(重定向) 或 200(直接推登录页代码)
    if [ "$status" -eq 204 ]; then
        return 0 # 状态 0 代表成功 (有网)
    else
        return 1 # 状态 1 代表失败 (没网，或被拦截)
    fi
}

while true; do
    # 第一次检测网络
    if check_real_net; then
        # 真正有网，正常休眠
        sleep "$CHECK_INTERVAL"
    else
        # 第一次检测失败，防抖双重确认
        if ! check_real_net; then
            
            # 连续两次失败，确定是被踢下线或断网了！
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 确认外网断开或被网关拦截，立刻触发登录脚本！" >> "$LOG_FILE"
            
            # 触发登录脚本 (此处会同步等待 n.sh 走完它的全部换 MAC、DHCP 流程)
            sh "$LOGIN_SCRIPT" >> "$LOG_FILE" 2>&1
            
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 登录脚本执行完毕，进入新一轮监控。" >> "$LOG_FILE"
            
            # 【已调整】给网络恢复留出 20 秒缓冲时间，包含网关放行和本地 DNS 刷新的时间，彻底防止误判
            sleep 20
        else
            sleep "$CHECK_INTERVAL"
        fi
    fi
done
