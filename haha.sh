#!/bin/bash
# =========================================================
# haha.sh - Trojan + WS + TLS + Cloudflare（Loon 专用）
# 支持动态修改 CF 域名
# =========================================================

set -e

WORK_DIR="/opt/haha"
XRAY_BIN="/usr/local/bin/xray"
CONF_DIR="/usr/local/etc/xray"
CONF_FILE="$CONF_DIR/config.json"
NODE_FILE="$WORK_DIR/loon.txt"
SERVICE_FILE="/etc/systemd/system/xray.service"

green() { echo -e "\033[32m$1\033[0m"; }
red() { echo -e "\033[31m$1\033[0m"; }

mkdir -p $WORK_DIR $CONF_DIR

install_xray() {
  if [ ! -f "$XRAY_BIN" ]; then
    green "下载和安装 Xray..."
    wget -qO /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
    rm -rf /tmp/xray
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
      "port": 10000,
      "protocol": "trojan",
      "settings": {
        "clients": [
          { "password": "$UUID" }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "$WS_PATH"
        }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom" }
  ]
}
EOF
}

write_service() {
  cat > $SERVICE_FILE <<EOF
[Unit]
Description=Xray Trojan Service
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
  cat > $NODE_FILE <<EOF
trojan=$CF_DOMAIN:443,password=$UUID,ws=true,ws-path=$WS_PATH,ws-headers=Host:$CF_DOMAIN,over-tls=true,skip-cert-verify=true,udp=false,tag=Trojan_CF_WS_TLS
EOF
}

install_trojan() {
  read -p "请输入 CF 域名: " CF_DOMAIN

  UUID=$(cat /proc/sys/kernel/random/uuid)
  WS_PATH="/$(echo $UUID | cut -c1-8)"

  install_xray
  write_config
  write_service
  write_node

  clear
  green "✅ Trojan + WS + TLS + CF 安装完成"
  echo
  echo "===== Loon 可用节点（直接复制即可） ====="
  cat $NODE_FILE
  echo "========================================"
  echo ""
  read -p "回车返回菜单"
}

enable_bbr() {
  green "开启 BBR 加速..."
  modprobe tcp_bbr || true
  echo "tcp_bbr" > /etc/modules-load.d/bbr.conf
  cat <<EOF >/etc/sysctl.d/99-bbr.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
  sysctl --system >/dev/null 2>&1
  green "BBR 已启用（会话生效，无需重启）。"
  read -p "回车返回菜单"
}

change_domain() {
  if [ ! -f "$NODE_FILE" ] || [ ! -f "$CONF_FILE" ]; then
    red "错误：当前未安装服务或找不到配置"
    read -p "回车返回菜单"
    return
  fi

  read -p "请输入新的 CF 域名: " NEW_DOMAIN
  if [ -z "$NEW_DOMAIN" ]; then
    red "域名不能为空！"
    read -p "回车返回菜单"
    return
  fi

  CF_DOMAIN="$NEW_DOMAIN"
  write_node

  green "CF 域名已更新!"
  echo ""
  echo "===== 新的 Loon 节点 ====="
  cat $NODE_FILE
  echo "==========================="
  read -p "回车返回菜单"
}

show_node() {
  if [ -f "$NODE_FILE" ]; then
    cat $NODE_FILE
  else
    red "未找到节点，请先安装服务。"
  fi
  echo ""
  read -p "回车返回菜单"
}

uninstall() {
  systemctl stop xray.service || true
  systemctl disable xray.service || true
  rm -f $SERVICE_FILE
  rm -rf $WORK_DIR $CONF_DIR $XRAY_BIN
  green "已卸载 Trojan 服务与节点配置"
  read -p "回车退出"
  exit 0
}

menu() {
  clear
  echo "====================================="
  echo " haha.sh 管理菜单 (Trojan + WS + TLS + CF)"
  echo "====================================="
  echo "1) 安装 Trojan + WS + TLS + CF"
  echo "2) 开启 BBR 加速"
  echo "3) 修改 CF 域名并生成新节点"
  echo "4) 查看 Loon 节点"
  echo "5) 卸载 Trojan"
  echo "0) 退出"
  echo "====================================="
  read -p "请选择: " choice
  case "$choice" in
    1) install_trojan ;;
    2) enable_bbr ;;
    3) change_domain ;;
    4) show_node ;;
    5) uninstall ;;
    0) exit 0 ;;
    *) red "输入错误，请重新选择"; sleep 1 ;;
  esac
}

while true; do
  menu
done