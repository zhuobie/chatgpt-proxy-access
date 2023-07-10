# 简介

用户可以自行购买VPS，使用此脚本部署代理服务器，使得某些地区可以正常访问chat.openai.com。

# 系统需求

VPS的操作系统需要为Debian 12。

# 快速开始

```
chmod +x chatgpt_proxy_access.sh
./chatgpt_proxy_access.sh install
```

使用Softether VPN Client连接到Softether VPN Server，IP地址为VPS公网地址，端口号9000，虚拟HUB名VPN，用户名user，密码user_password。本机分配虚拟网卡地址为192.168.30.100。

在浏览器的代理设置中，设置代理地址为192.168.30.30，端口为8888。

192.168.30.30:8888也可作为其他软件（如git）的代理服务器地址。

# 使用方法

```
./chatgpt_proxy_access.sh status|install|uninstall|enable|disable
```

用户可以更改脚本头部的参数，如暴露端口、用户名、密码、VPS虚拟网卡IP地址等。

