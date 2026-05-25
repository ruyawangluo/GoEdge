#!/bin/bash

# ============================================
# Edge Admin 安装脚本 - 多平台选择版
# 支持: GitHub | Gitee | Gitea
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 版本号
VERSION="v1.3.9"

# 平台配置
declare -A PLATFORMS
PLATFORMS[1]="GitHub"
PLATFORMS[2]="Gitee"
PLATFORMS[3]="Gitea"

# 基础URL配置
declare -A BASE_URLS
BASE_URLS[1]="https://github.com/ruyawangluo/GoEdge/releases/download/${VERSION}"
BASE_URLS[2]="https://gitee.com/ruyawangluo/GoEdge/releases/download/${VERSION}"
BASE_URLS[3]="https://gitea.ruyawangluo.cn/ruyawangluo/GoEdge/releases/download/${VERSION}"

# 打印带颜色的信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 显示欢迎信息
show_welcome() {
    echo "=========================================="
    echo "    Edge安装助手"
    echo "=========================================="
    echo "请选择下载源平台："
    echo ""
    echo "  1) GitHub (国际访问快)"
    echo "  2) Gitee  (国内访问快)"
    echo "  3) Gitea  (私有部署)"
    echo "  0) 自动检测最快源"
    echo ""
    echo "=========================================="
}

# 检测平台可用性
check_platform() {
    local platform_id=$1
    local base_url=${BASE_URLS[$platform_id]}
    local platform_name=${PLATFORMS[$platform_id]}
    
    # 构建测试URL（使用amd64包测试）
    local test_url="${base_url}/edge-admin-linux-amd64-plus-${VERSION}.zip"
    
    print_info "正在检测 ${platform_name} 可用性..."
    
    # 使用 HEAD 请求检测，超时 5 秒
    if curl -s --head --max-time 5 "$test_url" | head -1 | grep -q "200\|206\|302\|301"; then
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
    
    for i in 2 1 3; do  # 优先检测 Gitee(国内)、然后 GitHub、最后 Gitea
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
    
    print_info "正在下载 ${description}..."
    
    if curl -L \
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
    
    # 判断本机的处理器架构和操作系统版本
    cpu_arch=$(uname -m)
    os_version=$(cat /etc/os-release | grep PRETTY_NAME | cut -d '"' -f 2)
    echo "本机处理器架构：$cpu_arch"
    echo "本机操作系统版本：$os_version"

    # 更新软件包列表
    if [[ "$os_version" == *"Ubuntu"* || "$os_version" == *"Debian"* ]]; then
        echo "检测到系统类型为Debian/Ubuntu，正在更新软件包列表..."
        sudo apt update
    elif [[ "$os_version" == *"CentOS"* || "$os_version" == *"Red Hat"* || "$os_version" == *"Fedora"* ]]; then
        echo "检测到系统类型为CentOS/Red Hat/Fedora，正在更新软件包列表..."
        sudo yum update -y
    else
        echo "无法识别的操作系统类型。"
        exit 1
    fi

    # 检查并安装unzip
    if ! command -v unzip &> /dev/null; then
        echo "unzip未安装，正在安装..."
        if [[ "$os_version" == *"Ubuntu"* || "$os_version" == *"Debian"* ]]; then
            sudo apt install unzip -y
        elif [[ "$os_version" == *"CentOS"* || "$os_version" == *"Red Hat"* || "$os_version" == *"Fedora"* ]]; then
            sudo yum install unzip -y
        fi
    else
        echo "unzip已安装"
    fi

    # 检查 /usr/local/goedge 目录是否存在
    if [ ! -d "/usr/local/goedge" ]; then
        sudo mkdir -p /usr/local/goedge
        echo "安装目录创建成功，默认为/usr/local/goedge"
    else
        echo "检测到"
        echo "/usr/local/goedge"
        echo "已存在"
        echo "您可能已经安装过管理面板，无需重复安装，脚本已退出！"
        exit 1
    fi

    # 修改本机hosts屏蔽官方域名
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
            echo "$entry" | sudo tee -a /etc/hosts
        fi
    done

    echo "已成功屏蔽官方域名通信！"

    # 下载对应架构程序包
    cd /usr/local/goedge
    
    if [[ "$cpu_arch" == "x86_64" ]]; then
        admin_pkg="edge-admin-linux-amd64-plus-${VERSION}.zip"
        print_info "检测到 X86_64 架构"
    elif [[ "$cpu_arch" == "aarch64" ]]; then
        admin_pkg="edge-admin-linux-arm64-plus-${VERSION}.zip"
        print_info "检测到 ARM64 架构"
    else
        print_error "不支持的CPU架构: $cpu_arch"
        exit 1
    fi
    
    # 下载主程序包
    admin_url="${base_url}/${admin_pkg}"
    if ! download_file "$admin_url" "$admin_pkg" "Edge Admin 主程序"; then
        print_error "主程序包下载失败"
        return 1
    fi

    # 解压缩程序包
    unzip -o "$admin_pkg"

    # 进入 edge-admin 目录
    cd edge-admin

    # 启动 edge-admin 主程序
    bin/edge-admin start

    # 安装系统服务
    bin/edge-admin service

    # 删除 /deploy 自带程序包
    cd edge-api/deploy
    rm -rf *.zip

    # 拉取纯净plus版本程序包
    print_info "正在下载组件包..."
    
    # 定义组件包列表
    components=(
        "edge-node-linux-amd64-plus-${VERSION}.zip"
        "edge-node-linux-arm64-plus-${VERSION}.zip"
        "edge-dns-linux-amd64-${VERSION}.zip"
        "edge-dns-linux-arm64-${VERSION}.zip"
        "edge-user-linux-amd64-${VERSION}.zip"
        "edge-user-linux-arm64-${VERSION}.zip"
    )
    
    # 下载所有组件包
    for component in "${components[@]}"; do
        component_url="${base_url}/${component}"
        if ! download_file "$component_url" "$component" "$component"; then
            print_warn "$component 下载失败，继续下载其他组件..."
        fi
    done

    # 流程执行完毕，输出管理平台地址及通用注册码
    clear
    ipv4_address=$(curl -s ipv4.ip.sb)
    echo -e "\033[1;33m 执行完毕！请通过浏览器访问：\033[0m"
    echo -e "\033[1;33m http://$ipv4_address:7788/ \033[0m"
    echo -e "\033[1;33m 进入管理平台，并依据页面提示完成最后的安装流程！ \033[0m"
    echo -e "\033[1;33m 如果无法访问，请检查是否已在防火墙/安全组中开放对应端口！ \033[0m"
    echo -e "-------------"
    echo -e "如需激活旗舰版，请于安装完成后，在管理平台依次点击「系统设置」>「商业版本」>「激活」，粘贴下方提供的注册码即可完成离线永久授权："
    echo -e "F4BuVYEKSDWV+I13ISd5NUyBcWOlH0af4/ow9obzYBS3XvYC9IsK86k5UDyyBv9vqJWN2/FQTDbPyuAO0zxYlkLDC0c8rrShs+7PAkqM0O8wBIGknzForgidDZahky5Lo/ZWaPZ1dVFUxmV29ykb0I0b4tv7Q3OtnTylOuzf//MYrlvyw6VJQMGnsttmeHzsNL/r0yDONOEXZoGoLZsuBKnkfXt+qt6bZF+kM1ncbh+sY42BrPTWQ12sXqJS3qHlzU0FFl9lTNzLGYYhq5vi/4sJuPVE50/uLCtslTJdb9zOGR915hnM+jHYsR+jUk0QxOqtreaHpsvNuLkexXbkmA=="
}

# 主程序
main() {
    show_welcome
    
    read -p "请输入选项 (0-3): " choice
    
    case $choice in
        0)
            auto_select
            selected=$?
            if [ $selected -eq 0 ]; then
                print_error "所有平台都不可用，请检查网络连接"
                exit 1
            fi
            ;;
        1|2|3)
            selected=$choice
            if ! check_platform $selected; then
                print_error "您选择的平台不可用"
                read -p "是否尝试其他平台? (y/n): " try_other
                if [[ "$try_other" =~ ^[Yy]$ ]]; then
                    auto_select
                    selected=$?
                    if [ $selected -eq 0 ]; then
                        print_error "没有可用平台"
                        exit 1
                    fi
                else
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
        echo "是否尝试其他平台?"
        for i in 1 2 3; do
            if [ $i -ne $selected ]; then
                echo "  $i) ${PLATFORMS[$i]}"
            fi
        done
        echo "  0) 退出"
        
        read -p "请选择: " retry_choice
        
        if [[ "$retry_choice" =~ ^[123]$ ]] && [ "$retry_choice" -ne "$selected" ]; then
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
