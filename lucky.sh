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
SCRIPT_URL="https://raw.githubusercontent.com/broykren666/mylucky/refs/heads/main/lucky.sh"
SHORTCUT="/usr/bin/lucky"

# 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
    printf "${RED}错误：必须使用 root 用户运行此脚本！${PLAIN}\n"
    exit 1
fi

# 创建快捷启动命令
create_shortcut() {
    if [ ! -f "$SHORTCUT" ] || [ "$(readlink -f "$SHORTCUT" 2>/dev/null)" != "$(readlink -f "$0" 2>/dev/null)" ]; then
        cp "$0" "$SHORTCUT" >/dev/null 2>&1
        chmod +x "$SHORTCUT"
    fi
}

# 获取本机 IP (缓存结果避免延迟)
PUBLIC_IP=""
get_ip() {
    if [ -z "$PUBLIC_IP" ]; then
        if command -v curl >/dev/null 2>&1; then
            PUBLIC_IP=$(curl -sS --connect-timeout 5 https://api.ipify.org 2>/dev/null || curl -sS --connect-timeout 5 https://ifconfig.me 2>/dev/null)
        elif command -v wget >/dev/null 2>&1; then
            PUBLIC_IP=$(wget -qO- --timeout=5 https://api.ipify.org 2>/dev/null || wget -qO- --timeout=5 https://ifconfig.me 2>/dev/null)
        fi
        [ -z "$PUBLIC_IP" ] && PUBLIC_IP="无法获取"
    fi
    printf "%s" "$PUBLIC_IP"
}

# 获取 Lucky 状态
get_status() {
    if [ -f "$INIT_FILE" ] && rc-service lucky status >/dev/null 2>&1; then
        printf "${GREEN}正在运行${PLAIN}"
    else
        printf "${RED}未运行${PLAIN}"
    fi
}

# 安装 Lucky
install_lucky() {
    printf "${YELLOW}正在安装/更新依赖 (tar, wget, curl, ca-certificates)...${PLAIN}\n"
    apk update >/dev/null 2>&1
    apk add tar wget curl ca-certificates >/dev/null 2>&1

    mkdir -p "$LUCKY_DIR"
    printf "${YELLOW}正在获取最新版 Lucky...${PLAIN}\n"

    # 自动识别架构
    local arch=$(uname -m)
    case "$arch" in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        armv7*) arch="arm7" ;;
        armv6*) arch="arm6" ;;
        i386|i686) arch="386" ;;
        *) printf "${RED}不支持的架构: $arch${PLAIN}\n"; exit 1 ;;
    esac

    wget -O /tmp/lucky.tar.gz "https://github.com/gkd-is/lucky/releases/latest/download/lucky_linux_${arch}.tar.gz"
    if [ $? -ne 0 ]; then
        printf "${RED}下载失败，请检查网络连接！${PLAIN}\n"
        return 1
    fi

    tar -zxvf /tmp/lucky.tar.gz -C "$LUCKY_DIR"
    chmod +x "$LUCKY_BIN"
    rm -f /tmp/lucky.tar.gz

    # 创建 OpenRC 服务脚本
    cat > "$INIT_FILE" <<EOF
#!/sbin/openrc-run
description="Lucky Service"
command="$LUCKY_BIN"
command_args="-c $LUCKY_CONF"
command_background="yes"
pidfile="/run/\${RC_SVCNAME}.pid"
start_stop_daemon_args="--make-pidfile"

depend() {
    need net
}
EOF
    chmod +x "$INIT_FILE"
    rc-update add lucky default >/dev/null 2>&1
    rc-service lucky restart >/dev/null 2>&1

    # 创建快捷命令
    create_shortcut

    printf "${GREEN}Lucky 安装/更新完成并已启动！${PLAIN}\n"
    printf "${BLUE}快捷启动命令：lucky${PLAIN}\n"
    printf "${BLUE}默认管理地址：http://$(get_ip):16601 (请确保映射了内网 16601 端口)${PLAIN}\n"
    printf "${BLUE}默认账号：666 / 密码：666${PLAIN}\n"
    printf "${YELLOW}按回车键继续...${PLAIN}"; read -r tmp
}

# 卸载 Lucky
uninstall_lucky() {
    printf "${YELLOW}正在卸载 Lucky...${PLAIN}\n"
    rc-service lucky stop >/dev/null 2>&1
    rc-update del lucky default >/dev/null 2>&1
    rm -rf "$LUCKY_DIR"
    rm -f "$INIT_FILE"
    rm -f "$SHORTCUT"
    printf "${GREEN}卸载成功！${PLAIN}\n"
    printf "${YELLOW}按回车键继续...${PLAIN}"; read -r tmp
}

# 更新管理脚本本身
update_self() {
    printf "${YELLOW}正在从 GitHub 获取最新管理脚本...${PLAIN}\n"
    wget -O /tmp/lucky_new.sh "$SCRIPT_URL"
    if [ $? -eq 0 ]; then
        mv /tmp/lucky_new.sh "$0"
        chmod +x "$0"
        # 同时更新快捷方式
        cp "$0" "$SHORTCUT" >/dev/null 2>&1
        chmod +x "$SHORTCUT"
        printf "${GREEN}脚本更新成功！请重新运行脚本。${PLAIN}\n"
        exit 0
    else
        printf "${RED}脚本更新失败，请检查网络连接！${PLAIN}\n"
        sleep 2
    fi
}

# 主菜单
show_menu() {
    create_shortcut
    while true; do
        clear
        printf "--- ${BLUE}Lucky 管理脚本 (Alpine NAT 专用)${PLAIN} ---\n"
        printf "${YELLOW}本机公网 IP:${PLAIN} %s\n" "$(get_ip)"
        printf "${YELLOW}Lucky 状态: ${PLAIN} %s\n" "$(get_status)"
        printf "----------------------------------------\n"
        printf "1. 安装/更新 Lucky (主程序)\n"
        printf "2. 卸载 Lucky\n"
        printf "3. 启动 Lucky\n"
        printf "4. 停止 Lucky\n"
        printf "5. 重启 Lucky\n"
        printf "6. 更新管理脚本\n"
        printf "0. 退出\n"
        printf "----------------------------------------\n"
        printf "请输入数字 [0-6]: "
        read -r num

        case "$num" in
            1) install_lucky ;;
            2) uninstall_lucky ;;
            3) rc-service lucky start ;;
            4) rc-service lucky stop ;;
            5) rc-service lucky restart ;;
            6) update_self ;;
            0) exit 0 ;;
            *) printf "${RED}请输入正确的数字${PLAIN}\n"; sleep 2 ;;
        esac
    done
}

show_menu
