#!/bin/bash

# 定义全局路径变量
WORK_DIR="/opt/haha"
CONF_DIR="/usr/local/etc/xray"
CONF_FILE="$CONF_DIR/config.json"
NODE_FILE="$WORK_DIR/loon.txt"
SERVICE_FILE="/etc/systemd/system/xray.service"
XRAY_BIN="/usr/local/bin/xray"

# 输出格式化
green() { echo -e "\033[32m$1\033[0m"; }
red()   { echo -e "\033[31m$1\033[0m"; }

# 必需依赖检查
check_dependencies() {
  for cmd in wget unzip systemctl openssl; do
    if ! command -v "$cmd" >/dev/null; then
      red "依赖工具 $cmd 未安装，请安装后再运行脚本！"
      exit 1
    fi
  done
}

# 创建工作和配置目录
setup_directories() {
  mkdir -p "$WORK_DIR" "$CONF_DIR"
}

# 下载并安装 Xray
install_xray() {
  green "开始安装 Xray..."
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
  green "生成 Xray 配置信息..."
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
  green "配置文件已成功写入：$CONF_FILE"
}

# 创建 Xray 服务
create_service() {
  green "创建 Xray 系统服务..."
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
  green "Xray 服务已创建并启用！"
}

# 启动 Xray 服务
start_service() {
  green "启动 Xray 服务..."
  systemctl restart xray.service
  if systemctl is-active --quiet xray.service; then
    green "Xray 服务启动成功！"
  else
    red "Xray 服务启动失败，请检查日志。"
  fi
}

# 生成节点文件
generate_nodes() {
  green "生成节点配置文件..."
  cat > "$NODE_FILE" <<EOF
Trojan_WS = trojan,$DIRECT_HOST,$PORT,"$TROJAN_PASS",transport=ws,path=$WS_PATH,host=$FAKE_HOST,alpn=http1.1,skip-cert-verify=true,sni=$FAKE_HOST,udp=false
VLESS_WS = VLESS,$DIRECT_HOST,$PORT,"$VLESS_UUID",transport=ws,path=$WS_PATH,host=$FAKE_HOST,over-tls=true,sni=$FAKE_HOST,skip-cert-verify=true
EOF
  green "节点文件已生成：$NODE_FILE"
}

# 启用 BBR 加速
enable_bbr() {
  green "开启 BBR TCP 加速..."
  modprobe tcp_bbr >/dev/null 2>&1
  echo "net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr" > /etc/sysctl.d/99-bbr.conf
  sysctl --system >/dev/null 2>&1
  green "BBR 加速已启用！"
}

# 安装所有服务及配置
install_all() {
  clear
  echo "请选择节点设置方式："
  echo "1) 配置 Cloudflare 域名"
  echo "2) 自定义 IP/域名 和伪装域名"
  read -p "输入 1 或 2: " USE_CF
  if [ "$USE_CF" == "1" ]; then
    read -p "请输入 Cloudflare 域名: " DIRECT_HOST
    FAKE_HOST="$DIRECT_HOST"
  else
    read -p "请输入服务器真实 IP/域名: " DIRECT_HOST
    read -p "请输入伪装域名 (Host & SNI): " FAKE_HOST
  fi
  read -p "设置服务端口 (默认 443): " PORT
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
    echo "=========== 管理菜单 ==========="
    echo "1) 安装节点"
    echo "2) 查看节点信息"
    echo "3) 启用 BBR 加速"
    echo "0) 退出菜单"
    echo "================================"
    read -p "请输入选项: " choice
    case "$choice" in
      1) install_all ;;
      2) cat "$NODE_FILE" || red "节点文件不存在！" ;;
      3) enable_bbr ;;
      0) exit 0 ;;
      *) red "无效的选项，请重新输入！" ;;
    esac
    read -p "按任意键返回菜单..."
  done
}

# 启动主菜单
main_menu