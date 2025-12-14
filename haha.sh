---

## ✅ 更新后的脚本逻辑要求（本次实现）

1. 安装服务：Trojan + VLESS  
2. WebSocket + TLS  
3. 输出 **CF 优选 IP 或域名**  
4. 输出 **Loon 标准格式节点**
5. 可修改域名 / 端口 / BBR
6. **删除 SS 协议**
7. 脚本自动打印节点，不再需要查询文件

---

## 📌 下面是为你改好的【完整脚本源码】

请全部复制以下内容，到你的仓库覆盖原 `haha.sh`：

```bash
#!/bin/bash
# ===============================================================
# haha.sh - Trojan/VLESS + WS + TLS + CF 优选 IP + Loon 格式
# ===============================================================

set -e

WORK_DIR="/opt/haha"
CONF_DIR="/usr/local/etc/xray"
CONF_FILE="$CONF_DIR/config.json"
NODE_FILE="$WORK_DIR/loon.txt"
SERVICE_FILE="/etc/systemd/system/xray.service"

XRAY_BIN="/usr/local/bin/xray"
CF_IP_CANDIDATES=(
  "104.16.0.0"
  "104.17.0.0"
  "104.18.0.0"
  "104.19.0.0"
  "104.20.0.0"
)

green() { echo -e "\033[32m$1\033[0m"; }
red()   { echo -e "\033[31m$1\033[0m"; }

mkdir -p $WORK_DIR $CONF_DIR

install_xray() {
  if [ ! -f "$XRAY_BIN" ]; then
    green "下载并安装 Xray..."
    wget -qO /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
    mkdir -p /tmp/xray
    unzip -oq /tmp/xray.zip -d /tmp/xray
    install -m 755 /tmp/xray/xray $XRAY_BIN
  fi
}

choose_cf_ip(){
  green "测试 CF 优选 IP..."
  BEST_IP=""
  BEST_LAT=999999
  for ip in "${CF_IP_CANDIDATES[@]}"; do
    ping_time=$(ping -c 2 -W 1 $ip 2>/dev/null | grep avg | awk -F'/' '{print $5}')
    if [[ -n "$ping_time" ]] && (( $(echo "$ping_time < $BEST_LAT" | bc -l) )); then
      BEST_LAT=$ping_time
      BEST_IP=$ip
    fi
  done
  [ -z "$BEST_IP" ] && BEST_IP="$CF_DOMAIN"
  green "优选 IP: $BEST_IP (延迟: $BEST_LAT ms)"
}

write_config() {
  mkdir -p $CONF_DIR
  cat > $CONF_FILE <<EOF
{
  "inbounds": [
    {
      "port": $PORT,
      "protocol": "trojan",
      "settings": {
        "clients": [{
          "password": "$TROJAN_PASS"
        }]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "$WS_PATH"
        }
      }
    },
    {
      "port": $PORT,
      "protocol": "vless",
      "settings": {
        "clients": [{
          "id": "$VLESS_UUID"
        }],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
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
  echo "Trojan_CF_WS = trojan,$BEST_IP,$PORT,\"$TROJAN_PASS\",transport=ws,path=$WS_PATH,host=$CF_DOMAIN,alpn=http1.1,skip-cert-verify=true,tls-name=$CF_DOMAIN,udp=false" >> $NODE_FILE
  echo "VLESS_CF_WS = VLESS,$BEST_IP,$PORT,\"$VLESS_UUID\",transport=ws,path=$WS_PATH,host=$CF_DOMAIN,over-tls=true,tls-name=$CF_DOMAIN,skip-cert-verify=true" >> $NODE_FILE
}

install_all(){
  read -p "请输入 CF 域名: " CF_DOMAIN
  read -p "请输入端口 (默认443): " PORT
  [ -z "$PORT" ] && PORT=443

  WS_PATH="/$(cat /proc/sys/kernel/random/uuid | cut -d- -f1)"

  install_xray
  choose_cf_ip

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

enable_bbr() {
  green "开启 BBR 加速..."
  modprobe tcp_bbr || true
  cat <<EOF >/etc/sysctl.d/99-bbr.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
  sysctl --system >/dev/null 2>&1
  green "BBR 已启用"
  read -p "回车返回菜单"
}

change_domain() {
  read -p "请输入新的 CF 域名: " NEW_DOMAIN
  CF_DOMAIN="$NEW_DOMAIN"
  choose_cf_ip
  write_node
  systemctl restart xray.service

  green "域名已更新"
  cat $NODE_FILE
  read -p "回车返回菜单"
}

change_port() {
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
  read -p "回车返回菜单"
}

menu(){
  clear
  echo "=============================="
  echo " haha.sh 管理菜单 (Trojan/VLESS + WS + TLS + CF 优选)"
  echo "=============================="
  echo "1) 安装节点"
  echo "2) 开启 BBR"
  echo "3) 修改 CF 域名"
  echo "4) 修改端口"
  echo "5) 查看节点"
  echo "6) 卸载服务"
  echo "0) 退出"
  echo "=============================="
  read -p "请选择: " c
  case $c in
    1) install_all ;;
    2) enable_bbr ;;
    3) change_domain ;;
    4) change_port ;;
    5) show_node ;;
    6) uninstall ;;
    0) exit 0 ;;
    *) red "输入错误" ;;
  esac
}

while true; do menu; done