#!/bin/sh

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PLAIN='\033[0m'

# 路径定义
LUCKY_DIR="/opt/lucky"
LUCKY_BIN="${LUCKY_DIR}/lucky"
LUCKY_CONF="${LUCKY_DIR}/lucky.conf"
INIT_FILE="/etc/init.d/lucky"

# 检查 root 权限
[[ $EUID -ne 0 ]] && echo -e "${RED}错误：必须使用 root 用户运行此脚本！${PLAIN}" && exit 1

# 获取本机 IP (优先显示公网 IP)
get_ip() {
    local ip=$(curl -sS --connect-timeout 5 https://api.ipify.org || curl -sS --connect-timeout 5 https://ifconfig.me)
    [ -z "$ip" ] && ip="无法获取"
    echo "$ip"
}

# 获取 Lucky 状态
get_status() {
    if [ -f "$INIT_FILE" ] && rc-service lucky status >/dev/null 2>&1; then
        echo -e "${GREEN}正在运行${PLAIN}"
    else
        echo -e "${RED}未运行${PLAIN}"
    fi
}

# 安装 Lucky
install_lucky() {
    echo -e "${YELLOW}正在安装依赖 (tar, wget, curl)...${PLAIN}"
    apk add tar wget curl >/dev/null 2>&1

    mkdir -p $LUCKY_DIR
    echo -e "${YELLOW}正在获取最新版 Lucky...${PLAIN}"
    
    # 自动识别架构
    local arch=$(uname -m)
    case "$arch" in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        *) echo -e "${RED}不支持的架构: $arch${PLAIN}"; exit 1 ;;
    esac

    wget -O /tmp/lucky.tar.gz "https://github.com/gkd-is/lucky/releases/latest/download/lucky_linux_${arch}.tar.gz"
    tar -zxvf /tmp/lucky.tar.gz -C $LUCKY_DIR
    chmod +x $LUCKY_BIN
    rm -f /tmp/lucky.tar.gz

    # 创建 OpenRC 服务脚本
    cat > $INIT_FILE <<EOF
#!/sbin/openrc-run
command="$LUCKY_BIN"
command_args="-c $LUCKY_CONF"
command_background="yes"
pidfile="/run/\${RC_SVCNAME}.pid"
EOF
    chmod +x $INIT_FILE
    rc-update add lucky default
    rc-service lucky start

    echo -e "${GREEN}Lucky 安装完成并已启动！${PLAIN}"
    echo -e "${BLUE}默认管理地址：http://$(get_ip):16601 (请确保映射了内网 16601 端口)${PLAIN}"
    echo -e "${BLUE}默认账号：666 / 密码：666${PLAIN}"
}

# 卸载 Lucky
uninstall_lucky() {
    echo -e "${YELLOW}正在卸载 Lucky...${PLAIN}"
    rc-service lucky stop >/dev/null 2>&1
    rc-update del lucky default >/dev/null 2>&1
    rm -rf $LUCKY_DIR
    rm -f $INIT_FILE
    echo -e "${GREEN}卸载成功！${PLAIN}"
}

# 更新 Lucky
update_lucky() {
    echo -e "${YELLOW}正在检查并更新 Lucky...${PLAIN}"
    rc-service lucky stop
    install_lucky
}

# 主菜单
show_menu() {
    clear
    echo -e "--- ${BLUE}Lucky 管理脚本 (Alpine NAT 专用)${PLAIN} ---"
    echo -e "${YELLOW}本机公网 IP:${PLAIN} $(get_ip)"
    echo -e "${YELLOW}Lucky 状态: ${PLAIN} $(get_status)"
    echo -e "----------------------------------------"
    echo -e "1. 安装 Lucky"
    echo -e "2. 卸载 Lucky"
    echo -e "3. 更新 Lucky (保留配置)"
    echo -e "4. 启动 Lucky"
    echo -e "5. 停止 Lucky"
    echo -e "6. 重启 Lucky"
    echo -e "0. 退出"
    echo -e "----------------------------------------"
    read -p "请输入数字 [0-6]: " num

    case "$num" in
        1) install_lucky ;;
        2) uninstall_lucky ;;
        3) update_lucky ;;
        4) rc-service lucky start ;;
        5) rc-service lucky stop ;;
        6) rc-service lucky restart ;;
        0) exit 0 ;;
        *) echo -e "${RED}请输入正确的数字${PLAIN}"; sleep 2; show_menu ;;
    esac
}

show_menu