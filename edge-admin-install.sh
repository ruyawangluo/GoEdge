#!/bin/bash

# ============================================
# Edge Admin 安装脚本 - 多平台选择版
# 支持: GitHub | Gitea
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 版本号
VERSION="v1.3.9"

# Gitea 认证信息
GITEA_AUTH_TYPE=""   # "password" 或 "token"
GITEA_USERNAME=""
GITEA_PASSWORD=""
GITEA_TOKEN=""

# 平台配置
declare -A PLATFORMS
PLATFORMS[1]="GitHub"
PLATFORMS[2]="Gitea"

# 基础URL配置
declare -A BASE_URLS
BASE_URLS[1]="https://github.com/ruyawangluo/GoEdge/releases/download/${VERSION}"
BASE_URLS[2]="https://gitea.ruyawangluo.cn/ruyawangluo/GoEdge/releases/download/${VERSION}"

# ============================================
# 打印函数（统一风格）
# ============================================
print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_step() {
    echo -e "${CYAN}[步骤]${NC} $1"
}

print_separator() {
    echo -e "${CYAN}==========================================${NC}"
}

# ============================================
# 交互确认
# ============================================
confirm_action() {
    local prompt="${1:-是否继续?}"
    read -p "$(echo -e "${YELLOW}[确认]${NC} ${prompt} (y/n): ")" answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        print_warn "用户取消操作"
        exit 0
    fi
}

# 显示欢迎信息
show_welcome() {
    print_separator
    echo -e "${BOLD}       GoEdge Edge Admin 安装助手${NC}"
    print_separator
    echo ""
    echo "  请选择下载源平台："
    echo ""
    echo "    1) GitHub (国际访问)"
    echo "    2) Gitea  (私有部署)"
    echo "    0) 自动检测最快源"
    echo ""
    print_separator
}

# 检测平台可用性
check_platform() {
    local platform_id=$1
    local base_url=${BASE_URLS[$platform_id]}
    local platform_name=${PLATFORMS[$platform_id]}

    # 构建测试URL（使用amd64包测试）
    local test_url="${base_url}/edge-admin-linux-amd64-plus-${VERSION}.zip"

    print_info "正在检测 ${platform_name} 可用性..."

    # 构建 curl 认证参数
    local auth_args=()
    if [ "$platform_id" -eq 2 ] && [ -n "$GITEA_AUTH_TYPE" ]; then
        if [ "$GITEA_AUTH_TYPE" = "password" ]; then
            auth_args+=(-u "${GITEA_USERNAME}:${GITEA_PASSWORD}")
        elif [ "$GITEA_AUTH_TYPE" = "token" ]; then
            auth_args+=(-H "Authorization: token ${GITEA_TOKEN}")
        fi
    fi

    # 使用 HEAD 请求检测，超时 5 秒
    if curl -s --head --max-time 5 ${auth_args[@]} "$test_url" | head -1 | grep -q "200\|206\|302\|301"; then
        print_success "${platform_name} 可用"
        return 0
    else
        print_warn "${platform_name} 不可用或访问受限"
        return 1
    fi
}

# ============================================
# Gitea 登录认证
# ============================================
gitea_login() {
    echo ""
    print_separator
    echo -e "${BOLD}         Gitea 账户登录${NC}"
    print_separator
    echo ""
    echo "  该仓库为私有仓库，需要登录认证才能访问。"
    echo "  请选择认证方式："
    echo ""
    echo "    1) 用户名 + 密码"
    echo "    2) Personal Access Token (令牌)"
    echo "    0) 跳过登录（仅公开仓库可用）"
    echo ""
    print_separator

    read -p "请输入选项 (0-2): " auth_choice

    case $auth_choice in
        1)
            echo ""
            read -p "请输入 Gitea 用户名: " GITEA_USERNAME
            read -s -p "请输入 Gitea 密码: " GITEA_PASSWORD
            echo ""
            GITEA_AUTH_TYPE="password"
            print_success "密码认证设置完成"
            ;;
        2)
            echo ""
            echo -e "${YELLOW}提示：Token 可在 Gitea 网页端「设置 > 应用 > 管理 Access Token」中生成${NC}"
            echo ""
            read -p "请输入 Personal Access Token: " GITEA_TOKEN
            GITEA_AUTH_TYPE="token"
            print_success "Token 认证设置完成"
            ;;
        0)
            print_warn "已跳过登录，将尝试匿名访问"
            GITEA_AUTH_TYPE=""
            ;;
        *)
            print_error "无效选项，默认跳过登录"
            GITEA_AUTH_TYPE=""
            ;;
    esac
    echo ""
}

# 自动检测最快源
auto_select() {
    print_info "正在自动检测可用下载源..."

    for i in 1 2; do
        if check_platform $i; then
            return $i
        fi
    done

    return 0
}

# 下载文件
download_file() {
    local url=$1
    local output=$2
    local description=$3

    print_step "正在下载 ${description} ..."

    # 构建 curl 认证参数
    local auth_args=()
    if [ -n "$GITEA_AUTH_TYPE" ] && [[ "$url" == *"gitea"* ]]; then
        if [ "$GITEA_AUTH_TYPE" = "password" ]; then
            auth_args+=(-u "${GITEA_USERNAME}:${GITEA_PASSWORD}")
        elif [ "$GITEA_AUTH_TYPE" = "token" ]; then
            auth_args+=(-H "Authorization: token ${GITEA_TOKEN}")
        fi
    fi

    if curl -L \
        ${auth_args[@]} \
        -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        -o "$output" \
        --max-time 60 \
        "$url"; then

        if [ -f "$output" ] && [ -s "$output" ]; then
            print_success "${description} 下载成功"
            return 0
        else
            print_error "${description} 下载失败：文件为空"
            return 1
        fi
    else
        print_error "${description} 下载失败：网络请求错误"
        return 1
    fi
}

# 主安装流程
main_install() {
    local platform_id=$1
    local base_url=${BASE_URLS[$platform_id]}
    local platform_name=${PLATFORMS[$platform_id]}

    print_info "使用下载源: ${platform_name}"

    # ------------------------------------------
    # 第1步：检测系统信息
    # ------------------------------------------
    print_step "第1步：检测系统信息"
    cpu_arch=$(uname -m)
    os_version=$(cat /etc/os-release | grep PRETTY_NAME | cut -d '"' -f 2)
    print_info "本机处理器架构：${cpu_arch}"
    print_info "本机操作系统版本：${os_version}"

    # ------------------------------------------
    # 第2步：更新软件包列表
    # ------------------------------------------
    print_step "第2步：更新系统软件包列表"
    confirm_action "是否更新系统软件包列表?"

    if [[ "$os_version" == *"Ubuntu"* || "$os_version" == *"Debian"* ]]; then
        print_info "检测到 Debian/Ubuntu 系统，执行 apt update ..."
        sudo apt update
    elif [[ "$os_version" == *"CentOS"* || "$os_version" == *"Red Hat"* || "$os_version" == *"Fedora"* ]]; then
        print_info "检测到 CentOS/Red Hat/Fedora 系统，执行 yum update ..."
        sudo yum update -y
    else
        print_error "无法识别的操作系统类型"
        exit 1
    fi
    print_success "软件包列表更新完成"

    # ------------------------------------------
    # 第3步：检查并安装 unzip
    # ------------------------------------------
    print_step "第3步：检查并安装 unzip 工具"
    if ! command -v unzip &> /dev/null; then
        print_info "unzip 未安装，准备安装..."
        confirm_action "是否安装 unzip?"

        if [[ "$os_version" == *"Ubuntu"* || "$os_version" == *"Debian"* ]]; then
            sudo apt install unzip -y
        elif [[ "$os_version" == *"CentOS"* || "$os_version" == *"Red Hat"* || "$os_version" == *"Fedora"* ]]; then
            sudo yum install unzip -y
        fi
        print_success "unzip 安装完成"
    else
        print_info "unzip 已安装，跳过"
    fi

    # ------------------------------------------
    # 第4步：检查安装目录
    # ------------------------------------------
    print_step "第4步：检查安装目录 /usr/local/goedge"
    if [ ! -d "/usr/local/goedge" ]; then
        print_info "安装目录不存在，准备创建"
        confirm_action "是否创建安装目录 /usr/local/goedge?"
        sudo mkdir -p /usr/local/goedge
        print_success "安装目录创建成功"
    else
        print_warn "检测到 /usr/local/goedge 已存在"
        print_warn "您可能已经安装过管理面板，无需重复安装"
        confirm_action "是否仍要继续安装（将覆盖已有数据）?"
    fi

    # ------------------------------------------
    # 第5步：修改 hosts 屏蔽官方域名
    # ------------------------------------------
    print_step "第5步：修改 hosts 屏蔽官方域名"
    print_warn "此操作将向 /etc/hosts 添加以下条目以屏蔽官方域名通信："
    echo "    127.0.0.1 goedge.cn"
    echo "    127.0.0.1 goedge.cloud"
    echo "    127.0.0.1 dl.goedge.cloud"
    echo "    127.0.0.1 dl.goedge.cn"
    echo "    127.0.0.1 global.dl.goedge.cloud"
    echo "    127.0.0.1 global.dl.goedge.cn"
    confirm_action "是否修改 hosts 文件?"

    hosts_entries=(
        "127.0.0.1 goedge.cn"
        "127.0.0.1 goedge.cloud"
        "127.0.0.1 dl.goedge.cloud"
        "127.0.0.1 dl.goedge.cn"
        "127.0.0.1 global.dl.goedge.cloud"
        "127.0.0.1 global.dl.goedge.cn"
    )

    for entry in "${hosts_entries[@]}"; do
        if ! grep -q "$entry" /etc/hosts; then
            echo "$entry" | sudo tee -a /etc/hosts > /dev/null
        fi
    done
    print_success "hosts 文件修改完成，已屏蔽官方域名通信"

    # ------------------------------------------
    # 第6步：下载主程序包
    # ------------------------------------------
    print_step "第6步：下载 Edge Admin 主程序包"
    cd /usr/local/goedge

    if [[ "$cpu_arch" == "x86_64" ]]; then
        admin_pkg="edge-admin-linux-amd64-plus-${VERSION}.zip"
        print_info "检测到 X86_64 架构，将下载: ${admin_pkg}"
    elif [[ "$cpu_arch" == "aarch64" ]]; then
        admin_pkg="edge-admin-linux-arm64-plus-${VERSION}.zip"
        print_info "检测到 ARM64 架构，将下载: ${admin_pkg}"
    else
        print_error "不支持的CPU架构: ${cpu_arch}"
        exit 1
    fi

    confirm_action "是否开始下载主程序包?"

    admin_url="${base_url}/${admin_pkg}"
    if ! download_file "$admin_url" "$admin_pkg" "Edge Admin 主程序"; then
        print_error "主程序包下载失败"
        return 1
    fi

    # ------------------------------------------
    # 第7步：解压主程序包
    # ------------------------------------------
    print_step "第7步：解压主程序包"
    confirm_action "是否解压主程序包?"

    unzip -o "$admin_pkg"
    print_success "主程序包解压完成"

    # ------------------------------------------
    # 第8步：启动 Edge Admin
    # ------------------------------------------
    print_step "第8步：启动 Edge Admin 主程序"
    cd edge-admin
    confirm_action "是否启动 Edge Admin?"

    bin/edge-admin start
    print_success "Edge Admin 已启动"

    # ------------------------------------------
    # 第9步：安装系统服务
    # ------------------------------------------
    print_step "第9步：安装系统服务（开机自启）"
    confirm_action "是否安装为系统服务?"

    bin/edge-admin service
    print_success "系统服务安装完成"

    # ------------------------------------------
    # 第10步：清理并下载组件包
    # ------------------------------------------
    print_step "第10步：清理自带程序包并下载组件包"
    cd edge-api/deploy
    rm -rf *.zip
    print_info "已清理自带程序包"

    print_info "准备下载以下组件包："
    components=(
        "edge-node-linux-amd64-plus-${VERSION}.zip"
        "edge-node-linux-arm64-plus-${VERSION}.zip"
        "edge-dns-linux-amd64-${VERSION}.zip"
        "edge-dns-linux-arm64-${VERSION}.zip"
        "edge-user-linux-amd64-${VERSION}.zip"
        "edge-user-linux-arm64-${VERSION}.zip"
    )
    for component in "${components[@]}"; do
        echo "    - ${component}"
    done
    confirm_action "是否开始下载所有组件包?"

    for component in "${components[@]}"; do
        component_url="${base_url}/${component}"
        if ! download_file "$component_url" "$component" "$component"; then
            print_warn "${component} 下载失败，继续下载其他组件..."
        fi
    done
    print_success "组件包下载流程结束"

    # ------------------------------------------
    # 完成
    # ------------------------------------------
    clear
    ipv4_address=$(curl -s ipv4.ip.sb)
    print_separator
    echo -e "${BOLD}              安装完成！${NC}"
    print_separator
    echo ""
    echo -e "${GREEN}  请通过浏览器访问：${NC}"
    echo -e "${BOLD}  http://${ipv4_address}:7788/${NC}"
    echo ""
    echo -e "${YELLOW}  进入管理平台，并依据页面提示完成最后的安装流程！${NC}"
    echo -e "${YELLOW}  如果无法访问，请检查是否已在防火墙/安全组中开放对应端口！${NC}"
    echo ""
    print_separator
    echo -e "${CYAN}  如需激活旗舰版，请于安装完成后，在管理平台依次点击：${NC}"
    echo -e "${CYAN}  「系统设置」>「商业版本」>「激活」${NC}"
    echo -e "${CYAN}  粘贴下方提供的注册码即可完成离线永久授权：${NC}"
    echo ""
    echo -e "${BOLD}  F4BuVYEKSDWV+I13ISd5NUyBcWOlH0af4/ow9obzYBS3XvYC9IsK86k5UDyyBv9vqJWN2/FQTDbPyuAO0zxYlkLDC0c8rrShs+7PAkqM0O8wBIGknzForgidDZahky5Lo/ZWaPZ1dVFUxmV29ykb0I0b4tv7Q3OtnTylOuzf//MYrlvyw6VJQMGnsttmeHzsNL/r0yDONOEXZoGoLZsuBKnkfXt+qt6bZF+kM1ncbh+sY42BrPTWQ12sXqJS3qHlzU0FFl9lTNzLGYYhq5vi/4sJuPVE50/uLCtslTJdb9zOGR915hnM+jHYsR+jUk0QxOqtreaHpsvNuLkexXbkmA==${NC}"
    print_separator
}

# 主程序
main() {
    show_welcome

    read -p "请输入选项 (0-2): " choice

    case $choice in
        0)
            auto_select
            selected=$?
            if [ $selected -eq 0 ]; then
                print_error "所有平台都不可用，请检查网络连接"
                exit 1
            fi
            ;;
        1|2)
            selected=$choice
            # 如果选择 Gitea，提示是否需要登录
            if [ "$selected" -eq 2 ]; then
                echo ""
                read -p "$(echo -e "${YELLOW}[确认]${NC} 是否需要登录 Gitea 账户? (y/n): ")" need_login
                if [[ "$need_login" =~ ^[Yy]$ ]]; then
                    gitea_login
                fi
            fi
            if ! check_platform $selected; then
                print_error "您选择的平台不可用"
                confirm_action "是否尝试自动检测其他平台?" || exit 0
                auto_select
                selected=$?
                if [ $selected -eq 0 ]; then
                    print_error "没有可用平台"
                    exit 1
                fi
            fi
            ;;
        *)
            print_error "无效选项"
            exit 1
            ;;
    esac

    # 执行安装
    if ! main_install $selected; then
        print_error "从 ${PLATFORMS[$selected]} 安装失败"

        # 询问是否尝试其他平台
        echo ""
        print_info "是否尝试其他平台?"
        for i in 1 2; do
            if [ $i -ne $selected ]; then
                echo "    $i) ${PLATFORMS[$i]}"
            fi
        done
        echo "    0) 退出"

        read -p "请选择: " retry_choice

        if [[ "$retry_choice" =~ ^[12]$ ]] && [ "$retry_choice" -ne "$selected" ]; then
            if check_platform $retry_choice; then
                main_install $retry_choice
            else
                print_error "该平台不可用"
                exit 1
            fi
        else
            exit 1
        fi
    fi
}

# 运行
main
