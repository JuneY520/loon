#!/bin/bash
# ========================================================
# haha.sh - Trojan/VLESS + WS + TLS + 伪装域名（可选 Cloudflare）
# ========================================================

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
    green "下载并安装 Xray core..."
    wget -qO /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
    mkdir -p /tmp/xray
    unzip -oq /tmp/xray.zip -d /tmp/xray
    install -m 755 /tmp/xray/xray $XRAY_BIN
  fi
}

write_config() {
  mkdir -p $CONF_DIR
  cat > $CONF_FILE <<EOF
{
  "inbounds": [
    {
      "port": $PORT,
      "protocol": "trojan",
      "settings": {"clients":[{"password":"$TROJAN_PASS"}]},
      "streamSettings":{"network":"ws","wsSettings":{"path":"$WS_PATH"}}
    },
    {
      "port": $PORT,
      "protocol": "vless",
      "settings":{"clients":[{"id":"$VLESS_UUID"}],"decryption":"none"},
      "streamSettings":{"network":"ws","wsSettings":{"path":"$WS_PATH"}}
    }
  ],
  "outbounds":[{"protocol":"freedom"}]
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

  # 强制使用伪装域名作为 host 和 tls-name
  HOST_DISPLAY="$FAKE_HOST"

  echo "Trojan_WS = trojan,$DIRECT_HOST,$PORT,\"$TROJAN_PASS\",transport=ws,path=$WS_PATH,host=$HOST_DISPLAY,alpn=http1.1,skip-cert-verify=true,tls-name=$HOST_DISPLAY,udp=false" >> $NODE_FILE
  echo "VLESS_WS = VLESS,$DIRECT_HOST,$PORT,\"$VLESS_UUID\",transport=ws,path=$WS_PATH,host=$HOST_DISPLAY,over-tls=true,tls-name=$HOST_DISPLAY,skip-cert-verify=true" >> $NODE_FILE
}

install_all(){
  clear
  echo "是否使用 Cloudflare 套域名？"
  echo "y) 套 CF（需要 Cloudflare 小云朵）"
  echo "n) 不套 CF（直连 + 强制伪装域名）"
  read -p "请选择 (y/n): " USE_CF

  if [ "$USE_CF" == "y" ]; then
    read -p "请输入 Cloudflare 域名 (已开启小云朵代理): " CF_DOMAIN
    DIRECT_HOST="$CF_DOMAIN"
    FAKE_HOST="$CF_DOMAIN"
  else
    read -p "请输入服务器真实域名或 IP: " DIRECT_HOST
    read -p "请输入伪装域名（WS Host & TLS SNI）: " FAKE_HOST
    if [ -z "$FAKE_HOST" ]; then
      red "伪装域名不能为空"
      exit 1
    fi
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
  green "===== 安装完成 ====="
  cat $NODE_FILE
  echo "===================="
  read -p "回车返回菜单"
}

enable_bbr(){
  green "开启 BBR..."
  modprobe tcp_bbr || true
  cat <<EOF >/etc/sysctl.d/99-bbr.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
  sysctl --system >/dev/null 2>&1
  green "BBR 已启用"
  read -p "回车返回菜单"
}

change_host(){
  read -p "请输入新的服务器真实域名/IP: " DIRECT_HOST
  read -p "请输入新的伪装域名（WS Host & TLS SNI）: " FAKE_HOST
  write_node
  systemctl restart xray.service
  green "伪装域名/主机已更新"
  cat $NODE_FILE
  read -p "回车返回菜单"
}

change_port(){
  read -p "请输入新的端口: " NEW_PORT
  PORT="$NEW_PORT"
  write_config
  write_service
  write_node
  green "端口已更新"
  cat $NODE_FILE
  read -p "回车返回菜单"
}

show_node(){
  cat $NODE_FILE
  read -p "回车返回菜单"
}

uninstall(){
  systemctl stop xray.service || true
  systemctl disable xray.service || true
  rm -rf $CONF_DIR $WORK_DIR $SERVICE_FILE $XRAY_BIN
  green "已卸载"
  read -p "回车退出"
}

menu(){
  clear
  echo "=============================="
  echo " haha.sh 管理菜单（带伪装域名）"
  echo "=============================="
  echo "1) 安装节点"
  echo "2) 开启 BBR"
  echo "3) 修改 主机/伪装域名"
  echo "4) 修改 端口"
  echo "5) 查看 Loon 节点"
  echo "6) 卸载服务"
  echo "0) 退出"
  echo "=============================="
  read -p "请选择: " c
  case $c in
    1) install_all ;;
    2) enable_bbr ;;
    3) change_host ;;
    4) change_port ;;
    5) show_node ;;
    6) uninstall ;;
    0) exit ;;
    *) red "输入错误" ;;
  esac
}

while true; do menu; done