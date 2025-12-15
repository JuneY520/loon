#!/bin/bash

# 定义全局目录和文件路径
WORK_DIR="/opt/haha"
CONF_DIR="/usr/local/etc/xray"
CONF_FILE="$CONF_DIR/config.json"
NODE_FILE="$WORK_DIR/loon.txt"
SERVICE_FILE="/etc/systemd/system/xray.service"
XRAY_BIN="/usr/local/bin/xray"

# 输出格式化
green() { echo -e "\033[32m$1\033[0m"; }
red()   { echo -e "\033[31m$1\033[0m"; }

# 必要依赖检查
check_dependencies() {
  for cmd in wget unzip systemctl openssl; do
    if ! command -v "$cmd" >/dev/null; then
      red "依赖工具 $cmd 未安装，请配置后重试！"
      exit 1
    fi
  done
}

# 创建工作和配置目录
setup_directories() {
  mkdir -p "$WORK_DIR" "$CONF_DIR"
}

# 安装 Xray
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

# 生成配置凭据
generate_credentials() {
  TROJAN_PASS=$(openssl rand -hex 16)
  VLESS_UUID=$(cat /proc/sys/kernel/random/uuid)
  WS_PATH="/$(cat /proc/sys/kernel/random/uuid | cut -d- -f1)"
}

# 写入 Xray 配置文件
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

# 创建系统服务
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

# 启动服务
start_service() {
  green "启动 Xray 服务..."
  systemctl restart xray.service
  if systemctl is-active --quiet xray.service; then
    green "Xray 服务已成功启动！"
  else
    red "Xray 未能成功启动，请检查日志。"
  fi
}

# 生成节点文件
generate_nodes() {
  green "生成节点文件..."
  cat > "$NODE_FILE" <<EOF
Trojan_WS = trojan,$DIRECT_HOST,$PORT,"$TROJAN_PASS",transport=ws,path=$WS_PATH,host=$FAKE_HOST,alpn=http1.1,skip-cert-verify=true,sni=$FAKE_HOST,udp=false
VLESS_WS = VLESS,$DIRECT_HOST,$PORT,"$VLESS_UUID",transport=ws,path=$WS_PATH,host=$FAKE_HOST,over-tls=true,sni=$FAKE_HOST,skip-cert-verify=true
EOF
  green "节点文件生成成功: $NODE_FILE"
}

# 开启 BBR 加速
enable_bbr() {
  green "正在开启 BBR TCP 加速..."
  modprobe tcp_bbr >/dev/null 2>&1
  echo "net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr" > /etc/sysctl.d/99-bbr.conf
  sysctl --system >/dev/null 2>&1
  green "BBR 加速已启用！"
}

# 安装节点功能
install_all() {
  clear
  echo "请选择节点配置："
  echo "1) 使用 Cloudflare 的域名"
  echo "2) 自定义服务器域名和伪装域名"
  read -p "输入选择 (1/2): " USE_CF
  if [ "$USE_CF" == "1" ]; then
    read -p "输入 Cloudflare 域名: " DIRECT_HOST
    FAKE_HOST="$DIRECT_HOST"
  else
    read -p "输入服务器真实 IP/域名: " DIRECT_HOST
    read -p "输入伪装域名 (WS Host & SNI): " FAKE_HOST
  fi
  read -p "设置端口 (默认 443): " PORT
  PORT=${PORT:-443}

  generate_credentials
  install_xray
  setup_directories
  write_config
  create_service
  generate_nodes
  start_service
  
  green "安装完成！以下是节点信息："
  cat "$NODE_FILE"
}

# 主菜单
main_menu() {
  setup_directories
  check_dependencies
  while true; do
    echo "======= 主菜单 ======="
    echo "1) 安装节点"
    echo "2) 查看节点"
    echo "3) BBR 加速"
    echo "0) 退出程序"
    echo "======================"
    read -p "选择操作: " choice
    case "$choice" in
      1) install_all ;;
      2) cat "$NODE_FILE" ;;
      3) enable_bbr ;;
      0) exit 0 ;;
      *) red "无效选择，请重新输入！" ;;
    esac
  done
}

main_menu