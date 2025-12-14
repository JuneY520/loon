#!/bin/bash
# =========================================================
# suoha 一键脚本（Trojan + WS + TLS + Cloudflare 专用）
# 客户端：Loon（安装完成直接输出可复制节点）
# =========================================================

set -e

WORK_DIR="/opt/suoha"
XRAY_BIN="/usr/local/bin/xray"
CONF_DIR="/usr/local/etc/xray"
CONF_FILE="$CONF_DIR/config.json"
NODE_FILE="$WORK_DIR/loon.txt"

green() { echo -e "\033[32m$1\033[0m"; }
red() { echo -e "\033[31m$1\033[0m"; }

mkdir -p $WORK_DIR $CONF_DIR

menu() {
  clear
  echo "=============================="
  echo " suoha - Trojan WS TLS (CF)"
  echo "=============================="
  echo "1. 安装 Trojan + WS + TLS"
  echo "2. 查看 Loon 节点"
  echo "3. 卸载"
  echo "0. 退出"
  echo "=============================="
  read -p "请选择: " num
  case "$num" in
    1) install ;;
    2) show_node ;;
    3) uninstall ;;
    0) exit 0 ;;
    *) red "输入错误"; sleep 1; menu ;;
  esac
}

install() {
  read -p "请输入你的 CF 域名: " DOMAIN

  UUID=$(cat /proc/sys/kernel/random/uuid)
  WS_PATH="/$(echo $UUID | cut -c1-8)"
  PORT=443

  green "开始安装 Xray..."

  if [ ! -f "$XRAY_BIN" ]; then
    wget -O /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
    unzip /tmp/xray.zip -d /tmp/xray
    install -m 755 /tmp/xray/xray $XRAY_BIN
  fi

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

  cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=$XRAY_BIN -config $CONF_FILE
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable xray
  systemctl restart xray

  cat > $NODE_FILE <<EOF
trojan=$DOMAIN:$PORT,password=$UUID,ws=true,ws-path=$WS_PATH,ws-headers=Host:$DOMAIN,over-tls=true,skip-cert-verify=true,udp=false,tag=Trojan_CF_WS_TLS
EOF

  clear
  green "✅ 安装完成（Trojan + WS + TLS + CF）"
  echo
  echo "===== Loon 可用节点（复制即可） ====="
  cat $NODE_FILE
  echo "======================================"
}

show_node() {
  if [ -f "$NODE_FILE" ]; then
    cat $NODE_FILE
  else
    red "未找到节点信息"
  fi
  read -p "回车返回菜单"
  menu
}

uninstall() {
  systemctl stop xray || true
  systemctl disable xray || true
  rm -rf $WORK_DIR $CONF_DIR /etc/systemd/system/xray.service
  rm -f $XRAY_BIN
  green "已卸载"
}

menu