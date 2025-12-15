#!/bin/bash

# 必备环境变量
WORK_DIR="/opt/haha"
CONF_DIR="/usr/local/etc/xray"
CONF_FILE="$CONF_DIR/config.json"
NODE_FILE="$WORK_DIR/loon.txt"
SERVICE_FILE="/etc/systemd/system/xray.service"
XRAY_BIN="/usr/local/bin/xray"

# 添加输出
green() { echo -e "\033[32m$1\033[0m"; }
red()   { echo -e "\033[31m$1\033[0m"; }

check_dependencies() {
  for cmd in wget unzip systemctl openssl; do
    if ! command -v "$cmd" >/dev/null; then
      red "依赖工具 $cmd 未安装，请先安装后重试！"
      exit 1
    fi
  done
}

setup_directories() {
  mkdir -p "$WORK_DIR" "$CONF_DIR"
}

install_xray() {
  green "正在安装 Xray..."
  if [ ! -f "$XRAY_BIN" ]; then
    wget -qO /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
    mkdir -p /tmp/xray
    unzip -oq /tmp/xray.zip -d /tmp/xray
    install -m 755 /tmp/xray/xray "$XRAY_BIN"
    green "Xray 安装完成！"
  else
    green "Xray 已安装，跳过..."
  fi
}

generate_credentials() {
  TROJAN_PASS=$(openssl rand -hex 16)
  VLESS_UUID=$(cat /proc/sys/kernel/random/uuid)
  WS_PATH="/$(cat /proc/sys/kernel/random/uuid | cut -d- -f1)"
}

write_config() {
  green "写入配置信息..."
  cat > "$CONF_FILE" <<EOF
{
  "inbounds": [
    {
      "port": $PORT,
      "protocol": "trojan",
      "settings": {
        "clients": [{"password": "$TROJAN_PASS"}]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {"path": "$WS_PATH"}
      }
    },
    {
      "port": $PORT,
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "$VLESS_UUID"}],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {"path": "$WS_PATH"}
      }
    }
  ],
  "outbounds": [{"protocol": "freedom"}]
}
EOF
}

create_service() {
  green "创建系统服务..."
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=$XRAY_BIN -config "$CONF_FILE"
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable xray.service
}

generate_nodes() {
  green "创建节点文件..."
  cat > "$NODE_FILE" <<EOF
Trojan_WS = trojan,$DIRECT_HOST,$PORT,"$TROJAN_PASS",transport=ws,path=$WS_PATH,host=$FAKE_HOST,alpn=http1.1,skip-cert-verify=true,sni=$FAKE_HOST,udp=false
VLESS_WS = VLESS,$DIRECT_HOST,$PORT,"$VLESS_UUID",transport=ws,path=$WS_PATH,host=$FAKE_HOST,over-tls=true,sni=$FAKE_HOST,skip-cert-verify=true
EOF
}

install_all() {
  clear
  echo "请选择节点配置："
  echo "1) Cloudflare 域名"
  echo "2) 自定义主机/伪装域名"
  read -p "输入选择 (1/2): " USE_CF

  if [ "$USE_CF" == "1" ]; then
    read -p "输入 Cloudflare 域名: " DIRECT_HOST
  else
    read -p "输入服务器真实 IP/域名: " DIRECT_HOST
    read -p "输入伪装域名或 SNI 域名: " FAKE_HOST
  fi

  read -p "设置端口 (默认 443): " PORT
  PORT=${PORT:-443} # 设置默认值

  generate_credentials

  # 开始安装配置
  install_xray
  write_config
  create_service
  generate_nodes
  
  systemctl restart xray.service

  green "安装完成！节点信息存储在 $NODE_FILE"
  cat "$NODE_FILE"
}

uninstall_all() {
  read -p "确认卸载所有组件？(y/n): " confirm
  if [ "$confirm" == "y" ]; then
    systemctl stop xray.service
    systemctl disable xray.service
    rm -rf "$WORK_DIR" "$CONF_DIR" "$SERVICE_FILE" "$XRAY_BIN"
    green "卸载完成！"
  else
    green "操作已取消。"
  fi
}

main_menu() {
  setup_directories
  check_dependencies
  while true; do
    clear
    echo "======= 管理工具菜单 ======="
    echo "1) 安装 Loon 节点"
    echo "2) 查看节点配置"
    echo "3) 卸载服务"
    echo "0) 退出"
    echo "==========================="
    read -p "输入你的选择: " choice
    case $choice in
      1) install_all ;;
      2) cat "$NODE_FILE" ;;
      3) uninstall_all ;;
      0) exit ;;
      *) red "无效选择，请重新输入！" ;;
    esac
  done
}

main_menu