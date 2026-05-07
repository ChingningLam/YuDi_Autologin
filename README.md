# yudi_autologin
雨滴web自动登陆脚本

使用方法
首先修改net.sh里面的username和password为自己的账号密码

会优先获取CSRF Token的方式来进行自动登录
如果CSRF Token登陆失败则用默认的web curl来登录

修改完成之后的net.sh直接丢到/root/里面
自启动的话net.service放置在/etc/init.d目录下 设置为开机自启动

我的设备运行immortalwrt 搭配 UA3F的proxy模式和不一定必要的openclash使用

感谢
https://github.com/JiangTx/zax_autologin/tree/main

https://github.com/zhxycn/WHUT-WLAN

https://owo.cab/posts/tinker/openwrt-campus-network-bypass
还有github自带的copilot里面的claude大模型
