trojan2 = trojan,example.com,443,"password",transport=ws,path=/,host=host.com,alpn=http1.1,skip-cert-verify=true,sni=example.com,udp=true
VLESS4 = VLESS,example.com,10086,"uuid",transport=ws,path=/,host=v3-dy-y.ixigua.com,over-tls=true,sni=example.com,skip-cert-verify=true
```[oai_citation_attribution:1‡GitHub](https://raw.githubusercontent.com/Loon0x00/LoonExampleConfig/master/Nodes/ExampleNodes.list?utm_source=chatgpt.com)

你之前用的 `tls-name=` 是 **不被 Loon 正式识别的字段**，必须改成 `sni=` 才能正确握手。  

---

## 📌 下面是 **修正版、无注释、可直接运行** 的完整脚本

> ⚠️ 注意：  
> ✔ 不要在脚本里插入说明性文本或 Emoji 图标  
> ✔ 必须从 `#!/bin/bash` 开始到最后一个 `done` 结束之间全部复制  
> ✔ 上传到 GitHub 后直接运行

```bash
#!/bin/bash

set -e

WORK_DIR="/opt/haha"
CONF_DIR="/usr/local/etc/xray"
CONF_FILE="$CONF_DIR/config.json"
NODE_FILE="$WORK_DIR/loon.txt"
SERVICE_FILE="/etc/systemd/system/xray.service"
XRAY_BIN="/usr/local/bin/xray"

green() { echo -e "\033[32m$1\033[0m"; }
red()   { echo -e "\033[31m$1\033[0m"; }

mkdir -p $WORK_DIR $CONF_DIR

install_xray() {
  if [ ! -f "$XRAY_BIN" ]; then
    wget -qO /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
    mkdir -p /tmp/xray
    unzip -oq /tmp/xray.zip -d /tmp/xray
    install -m 755 /tmp/xray/xray $XRAY_BIN
  fi
}

write_config() {
  cat > $CONF_FILE <<EOF
{
  "inbounds": [
    {
      "port": $PORT,
      "protocol": "trojan",
      "settings": {"clients":[{"password":"$TROJAN_PASS"}]},
      "streamSettings": {"network":"ws","wsSettings":{"path":"$WS_PATH"}}
    },
    {
      "port": $PORT,
      "protocol": "vless",
      "settings": {"clients":[{"id":"$VLESS_UUID"}],"decryption":"none"},
      "streamSettings": {"network":"ws","wsSettings":{"path":"$WS_PATH"}}
    }
  ],
  "outbounds": [
    {"protocol":"freedom"}
  ]
}
EOF
}

write_service() {
  cat > $SERVICE_FILE <<EOF
[Unit]
Description=Xray Trojan/VLESS Service
After=network.target

[Service]
ExecStart=$XRAY_BIN -config $CONF_FILE
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable xray.service
  systemctl restart xray.service
}

write_node() {
  echo > $NODE_FILE
  echo "Trojan_WS = trojan,$DIRECT_HOST,$PORT,\"$TROJAN_PASS\",transport=ws,path=$WS_PATH,host=$FAKE_HOST,alpn=http1.1,skip-cert-verify=true,sni=$FAKE_HOST,udp=false" >> $NODE_FILE
  echo "VLESS_WS = VLESS,$DIRECT_HOST,$PORT,\"$VLESS_UUID\",transport=ws,path=$WS_PATH,host=$FAKE_HOST,over-tls=true,sni=$FAKE_HOST,skip-cert-verify=true" >> $NODE_FILE
}

install_all(){
  echo "是否使用 Cloudflare 套域名？"
  echo "y) 套 CF"
  echo "n) 不套 CF + 强制伪装域名"
  read -p "请选择 (y/n): " USE_CF

  if [ "$USE_CF" == "y" ]; then
    read -p "请输入已启用小云朵的 CF 域名: " CF_DOMAIN
    DIRECT_HOST="$CF_DOMAIN"
    FAKE_HOST="$CF_DOMAIN"
  else
    read -p "请输入服务器真实域名或 IP (可留空自动检测): " DIRECT_HOST
    if [ -z "$DIRECT_HOST" ]; then
      DIRECT_HOST=$(hostname -f 2>/dev/null || hostname 2>/dev/null || curl -4 -s https://ip.sb || true)
    fi
    while true; do
      read -p "请输入伪装域名 (用于 WS Host & SNI): " FAKE_HOST
      [ -n "$FAKE_HOST" ] && break
      red "伪装域名不能为空！"
    done
  fi

  read -p "请输入端口 (默认443): " PORT
  [ -z "$PORT" ] && PORT=443

  WS_PATH="/$(cat /proc/sys/kernel/random/uuid | cut -d- -f1)"

  install_xray

  TROJAN_PASS=$(openssl rand -base64 16)
  VLESS_UUID=$(cat /proc/sys/kernel/random/uuid)

  write_config
  write_service
  write_node

  clear
  green "安装完成，Loon 节点如下："
  cat $NODE_FILE
  read -p "按回车返回主菜单"
}

enable_bbr(){
  modprobe tcp_bbr || true
  cat <<EOF >/etc/sysctl.d/99-bbr.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
  sysctl --system >/dev/null 2>&1
  green "BBR 已启用"
  read -p "按回车返回主菜单"
}

change_host(){
  read -p "请输入新的服务器真实域名/IP: " DIRECT_HOST
  while [ -z "$DIRECT_HOST" ]; do
    red "主机/IP 不能为空"
    read -p "请重新输入: " DIRECT_HOST
  done
  while true; do
    read -p "请输入新的伪装域名 (WS Host & SNI): " FAKE_HOST
    [ -n "$FAKE_HOST" ] && break
    red "伪装域名不能为空"
  done
  write_node
  systemctl restart xray.service
  green "已更新"
  read -p "按回车返回主菜单"
}

change_port(){
  read -p "请输入新的端口: " NEW_PORT
  PORT="$NEW_PORT"
  write_config
  write_service
  write_node
  green "端口已更新"
  read -p "按回车返回主菜单"
}

show_node(){
  cat $NODE_FILE
  read -p "按回车返回主菜单"
}

uninstall(){
  systemctl stop xray.service || true
  systemctl disable xray.service || true
  rm -rf $CONF_DIR $WORK_DIR $SERVICE_FILE $XRAY_BIN
  green "卸载完成"
  read -p "按回车退出"
}

menu(){
  clear
  echo "1) 安装节点"
  echo "2) 开启 BBR"
  echo "3) 修改 主机/伪装域名"
  echo "4) 修改 端口"
  echo "5) 查看 Loon 节点"
  echo "6) 卸载服务"
  echo "0) 退出"
  read -p "请选择: " c
  case $c in
    1) install_all ;;
    2) enable_bbr ;;
    3) change_host ;;
    4) change_port ;;
    5) show_node ;;
    6) uninstall ;;
    0) exit ;;
    *) ;;
  esac
}

while true; do menu; done