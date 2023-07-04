#!/bin/bash
set -euo pipefail

command_arg="status"

if [ $# -lt 1 ]; then 
    echo "extra parameters will be ommited"
fi

if [ $# -eq 0 ]; then 
    command_arg="status"
else 
    command_arg=$1
fi

url_vpnserver="https://www.softether-download.com/files/softether/v4.41-9787-rtm-2023.03.14-tree/Linux/SoftEther_VPN_Server/64bit_-_Intel_x64_or_AMD64/softether-vpnserver-v4.41-9787-rtm-2023.03.14-linux-x64-64bit.tar.gz"
url_vpnclient="https://www.softether-download.com/files/softether/v4.41-9787-rtm-2023.03.14-tree/Linux/SoftEther_VPN_Client/64bit_-_Intel_x64_or_AMD64/softether-vpnclient-v4.41-9787-rtm-2023.03.14-linux-x64-64bit.tar.gz"
ip_server="192.168.30.30"
server_password="server_password"
hub_password="hub_password"
user_name="user"
user_password="user_password"
secure_nat="secure_nat_no"
shared_key="vpn"
vpn_server_port="9000"
tinyproxy_port="8888"

if [[ $url_vpnserver =~ /([^/]+)$ ]]; then 
    file_vpnserver=${BASH_REMATCH[1]}
fi
if [[ $url_vpnclient =~ /([^/]+)$ ]]; then 
    file_vpnclient=${BASH_REMATCH[1]}
fi

uninstall() {
    if [[ -f "/etc/systemd/system/vpnserver.service" ]]; then 
        systemctl stop vpnserver
        systemctl disable vpnserver
    fi
    if [[ -f "/etc/systemd/system/vpnclient.service" ]]; then
        systemctl stop vpnclient
        systemctl disable vpnclient
    fi

    rm -rf /etc/systemd/system/vpnserver.service
    rm -rf /etc/systemd/system/vpnclient.service
    systemctl daemon-reload
    rm -rf /opt/vpnserver
    rm -rf /opt/vpnclient

    rm -rf /opt/$file_vpnserver
    rm -rf /opt/$file_vpnclient

    if [[ -f "/etc/network/interfaces.d/softether_vpn" ]]; then
        rm -rf /etc/network/interfaces.d/softether_vpn
        systemctl restart networking
    fi

    rm -rf /root/.local/share/warp
    mkdir -p /root/.local/share/warp
    echo -n "yes" > /root/.local/share/warp/accepted-tos.txt

    if command -v warp-cli &> /dev/null; then
        warp-cli disconnect
        warp-cli delete
    fi
    if dpkg-query -W -f='${Status}' cloudflare-warp | grep -q "installed"; then
        systemctl stop warp-svc
        apt purge -y cloudflare-warp
    fi
    rm -rf /etc/apt/sources.list.d/cloudflare-client.list
    rm -rf /root/.local/share/warp
    
    if dpkg-query -W -f='${Status}' tinyproxy | grep -q "installed"; then
        systemctl stop tinyproxy
        apt purge -y tinyproxy
    fi
    
    apt autoremove -y

    if ufw status | grep -q "$vpn_server_port"; then
        ufw delete allow $vpn_server_port/tcp
    fi
    if ufw status | grep -q "$tinyproxy_port"; then
        ufw delete allow $tinyproxy_port/tcp
    fi
    ufw reload > /dev/null 2>&1
}

install() {
    uninstall
    apt update
    apt install -y gcc g++ make curl net-tools ufw
    cd /opt
    curl -O $url_vpnserver
    curl -O $url_vpnclient
    tar xzvf $file_vpnserver
    tar xzvf $file_vpnclient
    cd vpnserver
    make 
    cd ..
    cd vpnclient
    make 

    echo '[Unit]
    Description=SoftEther VPN Server
    After=network.target

    [Service]
    Type=forking
    ExecStart=/opt/vpnserver/vpnserver start
    ExecStop=/opt/vpnserver/vpnserver stop
    KillMode=process
    Restart=on-failure

    [Install]
    WantedBy=multi-user.target' | tee /etc/systemd/system/vpnserver.service

    echo '[Unit]
    Description=SoftEther VPN Client
    After=network.target

    [Service]
    Type=forking
    ExecStart=/opt/vpnclient/vpnclient start
    ExecStop=/opt/vpnclient/vpnclient stop
    KillMode=process
    Restart=on-failure

    [Install]
    WantedBy=multi-user.target' | tee /etc/systemd/system/vpnclient.service

    systemctl daemon-reload
    systemctl enable vpnserver
    systemctl enable vpnclient
    systemctl start vpnserver
    sleep 3
    systemctl start vpnclient
    sleep 3

    /opt/vpnserver/vpncmd localhost /SERVER /CMD HubCreate VPN /PASSWORD:$hub_password
    /opt/vpnserver/vpncmd localhost /SERVER /CMD HubDelete DEFAULT
    /opt/vpnserver/vpncmd localhost /SERVER /HUB:VPN /PASSWORD:$hub_password /CMD UserCreate $user_name /GROUP:none /REALNAME:none /NOTE:none
    /opt/vpnserver/vpncmd localhost /SERVER /HUB:VPN /PASSWORD:$hub_password /CMD UserPasswordSet $user_name /PASSWORD:$user_password
    /opt/vpnserver/vpncmd localhost /SERVER /CMD ListenerCreate $vpn_server_port
    /opt/vpnserver/vpncmd localhost /SERVER /CMD IPsecEnable /L2TP:yes /L2TPRAW:yes /ETHERIP:yes /PSK:$shared_key /DEFAULTHUB:VPN
    if [[ "$secure_nat" = "secure_nat_yes" ]]; then
        /opt/vpnserver/vpncmd localhost /SERVER /HUB:VPN /PASSWORD:hub_password /CMD SecureNatEnable 
    else 
        /opt/vpnclient/vpncmd localhost /CLIENT /CMD NicCreate vpn
        echo "# The softether vpn client interface" >> /etc/network/interfaces.d/softether_vpn
        echo "auto vpn_vpn" >> /etc/network/interfaces.d/softether_vpn
        echo "iface vpn_vpn inet static" >> /etc/network/interfaces.d/softether_vpn
        echo "address $ip_server" >> /etc/network/interfaces.d/softether_vpn
        echo "netmask 255.255.255.0" >> /etc/network/interfaces.d/softether_vpn
        systemctl restart networking
        /opt/vpnclient/vpncmd localhost /CLIENT /CMD AccountCreate local /SERVER:localhost:$vpn_server_port /HUB:VPN /USERNAME:$user_name /NICNAME:vpn_vpn
        /opt/vpnclient/vpncmd localhost /CLIENT /CMD AccountPasswordSet local /PASSWORD:$user_password /TYPE:standard
        /opt/vpnclient/vpncmd localhost /CLIENT /CMD AccountConnect local
        /opt/vpnclient/vpncmd localhost /CLIENT /CMD AccountStartupSet local
    fi
    /opt/vpnserver/vpncmd localhost /SERVER /CMD ServerPasswordSet $server_password

    curl https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
    sudo apt-get update && sudo apt-get install -y cloudflare-warp
    systemctl start warp-svc
    mkdir -p /root/.local/share/warp
    echo -n "yes" > /root/.local/share/warp/accepted-tos.txt
    warp-cli register
    warp-cli set-mode proxy
    warp-cli connect

    apt install -y tinyproxy && chown -R tinyproxy:tinyproxy /var/log/tinyproxy && systemctl restart tinyproxy
    line_number=$(grep -n "Upstream http some.remote.proxy:port" "/etc/tinyproxy/tinyproxy.conf" | cut -d ':' -f 1)
    if [[ -n "$line_number" ]]; then 
        sed -i "$((line_number+1))i upstream http 127.0.0.1:40000" "/etc/tinyproxy/tinyproxy.conf"
    else 
        exit 1
    fi
    sed -i '/192\.168\.0\.0\/16/s/^#//' /etc/tinyproxy/tinyproxy.conf
    sed -i '/ViaProxyName "tinyproxy"/ s/^/#/' /etc/tinyproxy/tinyproxy.conf
    sed -i 's/Port 8888/Port '$tinyproxy_port'/g' /etc/tinyproxy/tinyproxy.conf
    systemctl restart tinyproxy

    ufw allow $vpn_server_port/tcp
    ufw allow $tinyproxy_port/tcp
    ufw reload 
}

enable() {
    if [[ -f "/etc/systemd/system/vpnserver.service" ]]; then 
        systemctl start vpnserver
    else
        echo "vpn service may not have started"
        exit 0
    fi
    if [[ -f "/etc/systemd/system/vpnclient.service" ]]; then
        systemctl start vpnclient
    fi
    if [[ ! -f "/root/.local/share/warp/accepted-tos.txt" ]]; then
        mkdir -p /root/.local/share/warp
        echo -n "yes" > /root/.local/share/warp/accepted-tos.txt
    fi
    if command -v warp-cli &> /dev/null; then
        systemctl start warp-svc
        sleep 1
        warp-cli connect
    fi
    if dpkg-query -W -f='${Status}' tinyproxy | grep -q "installed"; then
        systemctl start tinyproxy
    fi
}

disable() {
    if [[ -f "/etc/systemd/system/vpnserver.service" ]]; then 
        systemctl stop vpnserver
    fi
    if [[ -f "/etc/systemd/system/vpnclient.service" ]]; then
        systemctl stop vpnclient
    fi
    if [[ ! -f "/root/.local/share/warp/accepted-tos.txt" ]]; then
        mkdir -p /root/.local/share/warp
        echo -n "yes" > /root/.local/share/warp/accepted-tos.txt
    fi
    if command -v warp-cli &> /dev/null; then
        warp-cli disconnect
        systemctl stop warp-svc
    fi
    if dpkg-query -W -f='${Status}' tinyproxy | grep -q "installed"; then
        systemctl stop tinyproxy
    fi
}

echo_status() {
    left=$1
    right=$2
    total_width=30
    mid_width=$((total_width - ${#left} - ${#right}))
    mid=$(printf '%*s' $mid_width | tr ' ' '.')
    printf "%s%s%s\n" "$left" "$mid" "$right"
}

status() {
    echo "=============================="
    if nc -z -w5 localhost $vpn_server_port; then
        echo_status "vpn server port" "YES"
    else 
        echo_status "vpn server port" "NO"
    fi
    if ps aux | grep -q "[v]pnserver"; then
        echo_status "vpn server process" "YES"
    else 
        echo_status "vpn server process" "NO"
    fi
    if ps aux | grep -q "[v]pnclient"; then
        echo_status "vpn client process" "YES"
    else 
        echo_status "vpn client process" "NO"
    fi
    if systemctl is-active -q warp-svc; then
        echo_status "warp-svc service" "YES"
    else 
        echo_status "warp-svc service" "NO"
    fi
    if nc -z -w5 localhost 40000; then
        echo_status "cloudflare warp port" "YES"
    else 
        echo_status "cloudflare warp port" "NO"
    fi
    if systemctl is-active -q tinyproxy; then
        echo_status "tinyproxy service" "YES"
    else 
        echo_status "tinyproxy service" "NO"
    fi
    if nc -z -w5 localhost $tinyproxy_port; then
        echo_status "tinyproxy port" "YES"
    else 
        echo_status "tinyproxy port" "NO"
    fi
    if ufw status | grep -qE "($vpn_server_port/tcp                   ALLOW       Anywhere)|(Status: inactive)"; then 
        echo_status "firewall for vpn server" "YES"
    else 
        echo_status "firewall for vpn server" "NO"
    fi
    if ufw status | grep -qE "($tinyproxy_port/tcp                   ALLOW       Anywhere)|(Status: inactive)"; then 
        echo_status "firewall for tinyproxy" "YES"
    else 
        echo_status "firewall for tinyproxy" "NO"
    fi
    echo "=============================="
}

if [[ "$command_arg" == "install" ]]; then
    install
elif [[ "$command_arg" == "uninstall" ]]; then
    uninstall
elif [[ "$command_arg" == "status" ]]; then 
    status
elif [[ "$command_arg" == "enable" ]]; then
    enable
elif [[ "$command_arg" == "disable" ]]; then
    disable
else 
    echo "Usage: $0 install|uninstall|status|enable|disable"
    exit 0
fi
