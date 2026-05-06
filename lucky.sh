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
IPV4=""
IPV6=""
get_ips() {
    # 获取 IPv4
    if [ -z "$IPV4" ]; then
        if command -v curl >/dev/null 2>&1; then
            IPV4=$(curl -4 -sS --connect-timeout 5 https://api64.ipify.org 2>/dev/null)
        elif command -v wget >/dev/null 2>&1; then
            IPV4=$(wget -4 -qO- --timeout=5 https://api64.ipify.org 2>/dev/null)
        fi
        [ -z "$IPV4" ] && IPV4="未获取到"
    fi
    # 获取 IPv6
    if [ -z "$IPV6" ]; then
        if command -v curl >/dev/null 2>&1; then
            IPV6=$(curl -6 -sS --connect-timeout 5 https://api64.ipify.org 2>/dev/null)
        elif command -v wget >/dev/null 2>&1; then
            IPV6=$(wget -6 -qO- --timeout=5 https://api64.ipify.org 2>/dev/null)
        fi
        [ -z "$IPV6" ] && IPV6="未获取到"
    fi
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
    apk update
    apk add tar wget curl ca-certificates

    mkdir -p "$LUCKY_DIR"
    
    printf "${YELLOW}正在获取最新版本号...${PLAIN}\n"
    # 获取最新版本号 (去 v 前缀)
    local tag=$(curl -s https://api.github.com/repos/gdy666/lucky/releases/latest | grep "tag_name" | cut -d '"' -f 4)
    if [ -z "$tag" ]; then
        printf "${RED}无法获取最新版本号，请检查网络！${PLAIN}\n"
        pause_exit
        return 1
    fi
    local version=$(echo "$tag" | sed 's/v//')
    printf "${GREEN}最新版本: ${tag}${PLAIN}\n"

    # 自动识别架构
    local arch=$(uname -m)
    case "$arch" in
        x86_64) arch="x86_64" ;;
        aarch64|arm64) arch="arm64" ;;
        armv7*) arch="armv7" ;;
        armv6*) arch="armv6" ;;
        i386|i686) arch="i386" ;;
        *) printf "${RED}不支持的架构: $arch${PLAIN}\n"; pause_exit; return 1 ;;
    esac

    # 构造下载地址
    # 示例: https://github.com/gdy666/lucky/releases/download/v2.27.2/lucky_2.27.2_Linux_x86_64.tar.gz
    local download_url="https://github.com/gdy666/lucky/releases/download/${tag}/lucky_${version}_Linux_${arch}.tar.gz"
    printf "${YELLOW}下载地址: ${download_url}${PLAIN}\n"
    
    wget -O /tmp/lucky.tar.gz "$download_url"
    if [ $? -ne 0 ]; then
        printf "${RED}下载失败，请检查网络连接或 GitHub 访问！${PLAIN}\n"
        pause_exit
        return 1
    fi

    printf "${YELLOW}正在解压文件...${PLAIN}\n"
    tar -zxvf /tmp/lucky.tar.gz -C "$LUCKY_DIR"
    if [ $? -ne 0 ]; then
        printf "${RED}解压失败！${PLAIN}\n"
        pause_exit
        return 1
    fi
    
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
    get_ips
    printf "${BLUE}默认管理地址：http://$IPV4:16601 (请确保映射了内网 16601 端口)${PLAIN}\n"
    printf "${BLUE}默认账号：666 / 密码：666${PLAIN}\n"
    pause_exit
}

# 辅助函数：暂停并返回
pause_exit() {
    printf "${YELLOW}按回车键继续...${PLAIN}"
    read -r tmp
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
    pause_exit
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
        printf "${GREEN}脚本更新成功！正在重新启动...${PLAIN}\n"
        sleep 1
        exec "$0"
    else
        printf "${RED}脚本更新失败，请检查网络连接！${PLAIN}\n"
        sleep 2
    fi
}

# 主菜单
show_menu() {
    create_shortcut
    while true; do
        get_ips
        clear
        printf "--- ${BLUE}Lucky 管理脚本 (Alpine NAT 专用)${PLAIN} ---\n"
        printf "${YELLOW}IPv4 地址:${PLAIN} %s\n" "$IPV4"
        printf "${YELLOW}IPv6 地址:${PLAIN} %s\n" "$IPV6"
        printf "${YELLOW}Lucky 状态:${PLAIN} %s\n" "$(get_status)"
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
