#!/bin/bash
export LANG=en_US.UTF-8

red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
blue(){
    echo -e "\033[36m\033[01m$1\033[0m"
}

[[ $EUID -ne 0 ]] && red "请使用 root 用户运行脚本" && exit 1

ISP=$(curl -s https://ipinfo.io/org | sed 's/AS.* //')

install_base(){
    apt update -y
    apt install -y curl wget unzip jq
}

install_xray(){
    bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh) install
}

install_cloudflared(){
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i cloudflared-linux-amd64.deb
}

argo_generate(){
    cloudflared tunnel --url http://localhost:8080 --no-autoupdate > argo.log 2>&1 &
    sleep 5
    argo=$(grep -o 'https://.*trycloudflare.com' argo.log | head -n1 | sed 's#https://##')
}

uuid=$(cat /proc/sys/kernel/random/uuid)
urlpath=$(echo $uuid | cut -c1-8)

write_xray_config(){
cat > /usr/local/etc/xray/config.json <<EOF
{
  "inbounds": [
    {
      "port": 8080,
      "protocol": "$xray_protocol",
      "settings": {
        "clients": [
          {
            "id": "$uuid",
            "password": "$uuid"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/$urlpath"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF
}

start_services(){
    systemctl restart xray
}

generate_node(){
    > v2ray.txt
    if [ $protocol == 1 ]; then
        echo -e ss2022节点已经生成, cloudflare.182682.xyz 可替换为CF优选IP'\n' >> v2ray.txt
        echo "ss://$(echo -n aes-256-gcm:$uuid | base64 -w0)@cloudflare.182682.xyz:443?encryption=none&type=ws&host=$argo&path=/$urlpath#${ISP}_tls" >> v2ray.txt
    fi

    if [ $protocol == 2 ]; then
        echo -e vless节点已经生成, cloudflare.182682.xyz 可替换为CF优选IP'\n' >> v2ray.txt
        echo "vless://$uuid@cloudflare.182682.xyz:443?encryption=none&security=tls&type=ws&host=$argo&path=/$urlpath#${ISP}_tls" >> v2ray.txt
    fi

    if [ $protocol == 3 ]; then
        echo -e trojan节点已经生成, cloudflare.182682.xyz 可替换为CF优选IP'\n' >> v2ray.txt
        echo "trojan://$uuid@cloudflare.182682.xyz:443?security=tls&type=ws&host=$argo&path=/$urlpath#${ISP}_tls" >> v2ray.txt
    fi

    echo >> v2ray.txt
    cat v2ray.txt
    green "信息已经保存在当前目录 v2ray.txt"
}

install_all(){
    install_base
    install_xray
    install_cloudflared

    read -p "请选择xray协议(默认1.ss2022,2.vless,3.trojan): " protocol
    [ -z "$protocol" ] && protocol=1
    if [[ $protocol != 1 && $protocol != 2 && $protocol != 3 ]]; then
        red "请输入正确的协议"
        exit 1
    fi

    if [ $protocol == 1 ]; then xray_protocol="shadowsocks"; fi
    if [ $protocol == 2 ]; then xray_protocol="vless"; fi
    if [ $protocol == 3 ]; then xray_protocol="trojan"; fi

    argo_generate
    write_xray_config
    start_services
    generate_node
}

uninstall_all(){
    systemctl stop xray
    rm -rf /usr/local/etc/xray
    rm -f /usr/local/bin/xray
    rm -f /usr/bin/cloudflared
    rm -f argo.log v2ray.txt
    green "卸载完成"
}

menu(){
clear
green "Fly.sh 一键部署脚本（已支持 Trojan）"
echo
echo "1. 梭哈模式（无需域名，重启失效）"
echo "2. 卸载服务"
echo "0. 退出"
read -p "请输入选项: " num
case "$num" in
1)
install_all
;;
2)
uninstall_all
;;
0)
exit 0
;;
*)
red "请输入正确的选项"
;;
esac
}

menu