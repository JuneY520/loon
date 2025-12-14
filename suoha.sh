#!/bin/bash
# =========================================================
# suoha 一键脚本（完整版）
# 协议：SS2022 / VLESS / TROJAN
# 传输：WS + TLS
# 中转：Cloudflare Argo Tunnel
# 加速：BBR
# =========================================================

set -e

# ---------------- 基础检测 ----------------
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 用户运行"
  exit 1
fi

OS=$(cat /etc/os-release | grep ^ID= | cut -d= -f2 | tr -d '"')
ARCH=$(uname -m)

# ---------------- BBR ----------------
enable_bbr() {
  echo ">> 启用 BBR 加速"
  cat >/etc/sysctl.d/99-bbr.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
  sysctl --system >/dev/null 2>&1 || true
}

# ---------------- 依赖 ----------------
install_base() {
  case "$OS" in
    ubuntu|debian)
      apt update
      apt install -y curl wget unzip openssl socat
      ;;
    centos|fedora|rocky|almalinux)
      yum install -y curl wget unzip openssl socat
      ;;
    alpine)
      apk add curl wget unzip openssl socat
      ;;
    *)
      echo "不支持的系统"
      exit 1
      ;;
  esac
}

# ---------------- 架构 ----------------
case "$ARCH" in
  x86_64|amd64)
    XRAY_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
    CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
    ;;
  aarch64|arm64)
    XRAY_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm64-v8a.zip"
    CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
    ;;
  armv7l)
    XRAY_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm32-v7a.zip"
    CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm"
    ;;
  *)
    echo "不支持的架构"
    exit 1
    ;;
esac

# ---------------- QuickTunnel ----------------
quicktunnel() {
  mkdir -p /tmp/suoha && cd /tmp/suoha
  wget -O xray.zip $XRAY_URL
  unzip -o xray.zip
  chmod +x xray

  wget -O cloudflared $CLOUDFLARED_URL
  chmod +x cloudflared

  port=$((RANDOM+20000))
  uuid=$(cat /proc/sys/kernel/random/uuid)
  path=$(echo $uuid | cut -d- -f1)
  passwd=$(openssl rand -base64 16)

  echo "选择协议：1.ss2022 2.vless 3.trojan"
  read -p "请输入: " protocol

  if [ "$protocol" == "1" ]; then
cat >config.json <<EOF
{
 "inbounds":[{
   "port":$port,
   "protocol":"shadowsocks",
   "settings":{
     "method":"2022-blake3-aes-128-gcm",
     "password":"$passwd"
   }
 }],
 "outbounds":[{"protocol":"freedom"}]
}
EOF
  fi

  if [ "$protocol" == "2" ]; then
cat >config.json <<EOF
{
 "inbounds":[{
   "port":$port,
   "protocol":"vless",
   "settings":{
     "clients":[{"id":"$uuid"}],
     "decryption":"none"
   },
   "streamSettings":{
     "network":"ws",
     "security":"tls",
     "wsSettings":{"path":"/$path"}
   }
 }],
 "outbounds":[{"protocol":"freedom"}]
}
EOF
  fi

  if [ "$protocol" == "3" ]; then
cat >config.json <<EOF
{
 "inbounds":[{
   "port":$port,
   "listen":"127.0.0.1",
   "protocol":"trojan",
   "settings":{
     "clients":[{"password":"$passwd"}]
   },
   "streamSettings":{
     "network":"ws",
     "security":"tls",
     "wsSettings":{"path":"/$path"}
   }
 }],
 "outbounds":[{"protocol":"freedom"}]
}
EOF
  fi

  ./xray run -config config.json &
  ./cloudflared tunnel --url http://127.0.0.1:$port --no-autoupdate >argo.log 2>&1 &

  sleep 5
  argo=$(grep trycloudflare argo.log | head -n1 | awk '{print $NF}')

  echo "=============================="
  echo "端口: $port"
  echo "路径: /$path"
  echo "UUID/密码: $uuid $passwd"
  echo "Argo 域名: $argo"
}

# ---------------- InstallTunnel ----------------
installtunnel() {
  enable_bbr
  install_base

  mkdir -p /opt/suoha && cd /opt/suoha
  wget -O xray.zip $XRAY_URL
  unzip -o xray.zip
  chmod +x xray

  wget -O cloudflared $CLOUDFLARED_URL
  chmod +x cloudflared

  read -p "请输入你的 CF 域名: " domain
  read -p "选择协议：1.ss2022 2.vless 3.trojan: " protocol

  port=$((RANDOM+20000))
  uuid=$(cat /proc/sys/kernel/random/uuid)
  path=$(echo $uuid | cut -d- -f1)
  passwd=$(openssl rand -base64 16)

  if [ "$protocol" == "2" ]; then
cat >config.json <<EOF
{
 "inbounds":[{
   "port":$port,
   "listen":"127.0.0.1",
   "protocol":"vless",
   "settings":{
     "clients":[{"id":"$uuid"}],
     "decryption":"none"
   },
   "streamSettings":{
     "network":"ws",
     "security":"tls",
     "wsSettings":{"path":"/$path"}
   }
 }],
 "outbounds":[{"protocol":"freedom"}]
}
EOF
  fi

  if [ "$protocol" == "3" ]; then
cat >config.json <<EOF
{
 "inbounds":[{
   "port":$port,
   "listen":"127.0.0.1",
   "protocol":"trojan",
   "settings":{
     "clients":[{"password":"$passwd"}]
   },
   "streamSettings":{
     "network":"ws",
     "security":"tls",
     "wsSettings":{"path":"/$path"}
   }
 }],
 "outbounds":[{"protocol":"freedom"}]
}
EOF
  fi

  nohup ./xray run -config config.json >/opt/suoha/xray.log 2>&1 &
  nohup ./cloudflared tunnel --url http://127.0.0.1:$port --hostname $domain --no-autoupdate >/opt/suoha/argo.log 2>&1 &

  cat >/opt/suoha/v2ray.txt <<EOF
域名: $domain
端口: 443
路径: /$path
UUID/密码: $uuid $passwd
EOF

  echo "安装完成，节点信息在 /opt/suoha/v2ray.txt"
}

# ---------------- 菜单 ----------------
clear
echo "============================"
echo "1. QuickTunnel 梭哈"
echo "2. InstallTunnel 服务模式"
echo "0. 退出"
read -p "请选择: " menu

case "$menu" in
  1) quicktunnel ;;
  2) installtunnel ;;
  *) exit 0 ;;
esac