#!/bin/bash

# 定义全局路径变量
WORK_DIR="/opt/haha"
CONF_DIR="/usr/local/etc/xray"
CONF_FILE="$CONF_DIR/config.json"
NODE_FILE="$WORK_DIR/loon.txt"
SERVICE_FILE="/etc/systemd/system/xray.service"
XRAY_BIN="/usr/local/bin/xray"

green() { echo -e "\033[32m$1\033[0m"; }
red()   { echo -e "\033[31m$1\033[0m"; }

# 必要依赖检查函数
check_dependencies() {
  for cmd in wget unzip systemctl openssl; do
    if ! command -v "$cmd" >/dev/null; then
      red "依赖工具 $cmd 未安装，请先配置后重试！"
      exit 1
    fi
  done
}

# 创建所需目录
setup_directories() {
  mkdir -p "$WORK_DIR" "$CONF_DIR"
  green "目录创建完成：$WORK_DIR"
}

# 下载并安装 Xray 框架
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

# 写入配置文件函数
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
  green "配置文件生成成功: $CONF_FILE"
}

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
  green "Xray 系统服务创建成功！"
}

start_service() {
  green "启动 Xray 服务..."
  systemctl restart xray.service
  if systemctl is-active --quiet xray.service; then
    green "Xray 服务已成功启动！"
  else
    red "Xray 未能成功启动，请手动检查日志。"
  fi
}

# 生成节点文件逻辑
generate_nodes() {
  green "生成节点文件..."
  cat > "$NODE_FILE" <<EOF
Trojan_WS = trojan,$DIRECT_HOST,$PORT,"$TROJAN_PASS",transport=ws,path=$WS_PATH,host=$FAKE_HOST,alpn=http1.1,skip-cert-verify=true,sni=$FAKE_HOST,udp=false
VLESS_WS = VLESS,$DIRECT_HOST,$PORT,"$VLESS_UUID",transport=ws,path=$WS_PATH,host=$FAKE_HOST,over-tls=true,sni=$FAKE_HOST,skip-cert-verify=true
EOF
  green "节点文件生成成功: $NODE_FILE"
}

# 安装节点完整逻辑
install_all() {
  clear
  green "即将开始安装 Loon 节点..."
  echo "请选择节点配置："
  echo "1) 使用 Cloudflare 的域名"
  echo "2) 自定义服务器域名和伪装域名"
  read -p "输入选择 (1/2): " USE_CF
  
  if [ "$USE_CF" == "1" ]; then
    read -p "输入 Cloudflare 域名: " DIRECT_HOST
    FAKE_HOST="$DIRECT_HOST"
  else
    read -p "输入服务器真实 IP/域名: " DIRECT_HOST
    read -p "输入伪装域名或 SNI 域名: " FAKE_HOST
  fi

  read -p "设置端口 (默认 443): " PORT
  PORT=${PORT:-443} # 设置默认值

  setup_directories
  check_dependencies
  install_xray
  generate_credentials
  write_config
  create_service
  generate_nodes
  start_service
  
  green "安装完成！请查看生成的节点配置文件：$NODE_FILE"
}

# 脚本入口函数
menu() {
  while true; do
    clear
    echo "=============================="
    echo " Loon 节点管理菜单"
    echo "=============================="
    echo "1) 安装 Loon 节点"
    echo "2) 查看节点配置"
    echo "3) 卸载服务"
    echo "0) 退出程序"
    echo "=============================="
    read -p "请输入选择 (1/2/3/0): " choice

    case "$choice" in
      1) install_all ;;
      2)
        if [ -f "$NODE_FILE" ]; then
          cat "$NODE_FILE"
        else
          red "节点文件未找到，请先安装节点！"
        fi
        ;;
      3)
        systemctl stop xray.service
        systemctl disable xray.service
        rm -rf "$WORK_DIR" "$CONF_DIR" "$SERVICE_FILE" "$XRAY_BIN"
        green "服务已卸载！"
        ;;
      0) exit 0 ;;
      *) red "无效的选择，请重试。" ;;
    esac
    read -p "按任意键返回菜单..."
  done
}

# 执行脚本
menu