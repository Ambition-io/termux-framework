#!/data/data/com.termux/files/usr/bin/bash

# ========================================
# Termux集成脚本框架安装程序
# ========================================

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

# 配置变量
SCRIPT_DIR="$HOME/.termux-framework"
REPO_URL="https://github.com/Ambition-io/termux-framework.git"

# 打印信息
print_info() {
    echo -e "${BLUE}[信息]${RESET} $1"
}

# 打印成功
print_success() {
    echo -e "${GREEN}[成功]${RESET} $1"
}

# 打印警告
print_warning() {
    echo -e "${YELLOW}[警告]${RESET} $1"
}

# 打印错误
print_error() {
    echo -e "${RED}[错误]${RESET} $1"
}

# 检查依赖
check_dependencies() {
    if ! command -v git &> /dev/null; then
        print_warning "未安装Git，正在安装..."
        pkg update -y
        pkg install -y git
    fi
}

# 主安装函数
main() {
    clear
    echo -e "${GREEN}============================================${RESET}"
    echo -e "${GREEN}      Termux集成脚本框架 - 安装程序      ${RESET}"
    echo -e "${GREEN}============================================${RESET}"
    echo ""
    
    # 检查依赖
    check_dependencies
    
    # 询问仓库URL
    read -p "请输入Git仓库URL [默认: $REPO_URL]: " input_url
    if [ -n "$input_url" ]; then
        REPO_URL="$input_url"
    fi
    
    print_info "安装目录: $SCRIPT_DIR"
    print_info "仓库URL: $REPO_URL"
    echo ""
    
    # 确认安装
    read -p "是否开始安装? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "安装已取消"
        exit 0
    fi
    
    # 开始安装
    print_info "开始安装..."
    
    # 备份旧目录（如果存在）
    if [ -d "$SCRIPT_DIR" ]; then
        print_info "备份现有安装..."
        mv "$SCRIPT_DIR" "${SCRIPT_DIR}.bak.$(date +%Y%m%d%H%M%S)"
    fi
    
    # 克隆仓库
    print_info "正在克隆仓库..."
    if git clone "$REPO_URL" "$SCRIPT_DIR"; then
        # 设置执行权限
        chmod +x "$SCRIPT_DIR/termux-framework.sh"
        
        # 创建快捷方式
        ln -sf "$SCRIPT_DIR/termux-framework.sh" "$PREFIX/bin/termux-framework"
        
        print_success "安装完成！"
        echo ""
        echo -e "您可以通过以下命令启动框架："
        echo -e "  ${GREEN}termux-framework${RESET}"
        echo ""
        
        # 询问是否立即启动
        read -p "是否立即启动框架? (y/n): " start
        if [[ "$start" =~ ^[Yy]$ ]]; then
            exec "$SCRIPT_DIR/termux-framework.sh"
        fi
    else
        print_error "克隆仓库失败，请检查网络连接和仓库URL"
        exit 1
    fi
}

# 启动安装程序
main