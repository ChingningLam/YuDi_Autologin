# 雨滴自动登录+被检测封禁mac地址后自动更改mac地址后重新认证
适用于 雨滴web portal的自动登陆脚本

被封会自己更改mac地址后重试

# 使用方法
# 首先修改n.sh里面的username和password为自己的账号密码

默认web登陆界面是http://172.168.2.100/account/login?ip=$wlanacip&nasId=1

需要根据自己的web登录认证界面按需修改

# 手动运行
/root/n.sh &

会优先获取CSRF Token的方式来进行自动登录

# 文件目录
修改完成之后的n.sh直接丢到/root/里面


# 自启动的话
在路由器后台的  启动项-本地启动脚本  添加如下内容

(sleep 30 && /root/keep.sh) & 设置为开机自启动


log文件会在/tmp/keep.log


我的设备运行immortalwrt 搭配 UA3F的proxy模式和不一定必要的openclash使用


# 查看实时日志
tail -f /tmp/keep.sh

# 停止脚本
killall n.sh
kaillall keep.sh

