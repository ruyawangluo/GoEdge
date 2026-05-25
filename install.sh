#!/bin/bash

# ============================================
# 安装脚本 - 多平台选择版
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

# 仓库信息
REPO_OWNER="ruyawangluo"
REPO_NAME="GoEdge"
FILE_PATH="edge-admin-install.sh"
BRANCH="main"

# 平台配置
declare -A PLATFORMS
PLATFORMS[1]="GitHub"
PLATFORMS[2]="Gitea"

declare -A URLS
URLS[1]="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}/${FILE_PATH}"
URLS[2]="https://gitea.ruyawangluo.cn/${REPO_OWNER}/${REPO_NAME}/raw/branch/${BRANCH}/${FILE_PATH}"

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
    echo -e "${BOLD}         GoEdge 安装助手${NC}"
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
    local url=${URLS[$platform_id]}
    local platform_name=${PLATFORMS[$platform_id]}

    print_info "正在检测 ${platform_name} 可用性..."

    # 使用 HEAD 请求检测，超时 5 秒
    if curl -s --head --max-time 5 "$url" | head -1 | grep -q "200\|206"; then
        print_success "${platform_name} 可用"
        return 0
    else
        print_warn "${platform_name} 不可用或访问受限"
        return 1
    fi
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
    local platform_id=$1
    local url=${URLS[$platform_id]}
    local platform_name=${PLATFORMS[$platform_id]}

    print_step "正在从 ${platform_name} 下载 ${FILE_PATH} ..."

    # 使用浏览器 User-Agent，跟随重定向
    if curl -L \
        -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        -o "${FILE_PATH}" \
        --max-time 30 \
        "$url"; then

        # 验证下载内容
        if [ -f "${FILE_PATH}" ] && [ -s "${FILE_PATH}" ]; then
            # 检查是否是 HTML 错误页面
            if head -1 "${FILE_PATH}" | grep -q "<!DOCTYPE\|<html"; then
                print_error "下载到的是 HTML 页面，不是脚本文件"
                rm -f "${FILE_PATH}"
                return 1
            fi

            # 检查是否是 shell 脚本
            if head -1 "${FILE_PATH}" | grep -q "^#!"; then
                print_success "下载成功！"
                return 0
            else
                print_warn "文件内容异常，可能下载失败"
                cat "${FILE_PATH}"
                rm -f "${FILE_PATH}"
                return 1
            fi
        else
            print_error "下载失败：文件为空或不存在"
            return 1
        fi
    else
        print_error "下载失败：网络请求错误"
        return 1
    fi
}

# 执行安装
run_install() {
    print_step "准备执行安装..."
    chmod +x "${FILE_PATH}"

    echo ""
    confirm_action "是否立即执行安装脚本?"

    print_step "开始安装"
    bash "./${FILE_PATH}"
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

    # 下载
    if download_file $selected; then
        run_install
    else
        print_error "从 ${PLATFORMS[$selected]} 下载失败"

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
            if download_file $retry_choice; then
                run_install
            else
                print_error "所有尝试均失败，请手动下载安装"
                exit 1
            fi
        else
            exit 1
        fi
    fi
}

# 运行
main
