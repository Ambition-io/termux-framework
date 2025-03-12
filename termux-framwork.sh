#!/data/data/com.termux/files/usr/bin/bash

# ========================================
# Termux集成脚本框架
# 版本：1.0.2
# ========================================

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"

# 配置变量
SCRIPT_DIR="$HOME/.termux-framework"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
CONFIG_FILE="$SCRIPT_DIR/config.sh"
REPO_URL="https://github.com/Ambition-io/termux-framework.git"
VERSION="1.0.2"

# 确保目录存在
mkdir -p "$SCRIPTS_DIR"

# 创建配置文件（如果不存在）
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << EOF
#!/data/data/com.termux/files/usr/bin/bash
# 配置文件

# 仓库URL
REPO_URL="$REPO_URL"

# 默认镜像源（清华大学镜像）
DEFAULT_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/termux"

# 自动检查更新（天数）
CHECK_UPDATE_DAYS=7

# 上次检查更新时间
LAST_UPDATE_CHECK=0
EOF
    chmod +x "$CONFIG_FILE"
fi

# 加载配置
source "$CONFIG_FILE"

# 打印标题
print_title() {
    clear
    echo -e "${CYAN}============================================${RESET}"
    echo -e "${CYAN}          Termux 集成脚本框架 v$VERSION${RESET}"
    echo -e "${CYAN}============================================${RESET}"
    echo ""
}

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

# 按键继续
press_enter() {
    echo ""
    read -p "按 Enter 键继续..."
}

# 检查必要的命令是否安装
check_dependencies() {
    local deps=("git" "curl" "wget")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_warning "缺少必要的依赖：${missing[*]}"
        read -p "是否立即安装这些依赖？(y/n): " install
        if [[ "$install" =~ ^[Yy]$ ]]; then
            pkg update -y
            pkg install -y "${missing[@]}"
            print_success "依赖安装完成"
        else
            print_warning "部分功能可能无法正常使用"
        fi
    fi
}

# 更新框架
update_framework() {
    print_info "正在更新框架..."
    
    # 备份当前目录
    local backup_dir="$SCRIPT_DIR.backup"
    if [ -d "$SCRIPT_DIR/.git" ]; then
        cd "$SCRIPT_DIR"
        
        # 保存当前配置
        cp "$CONFIG_FILE" /tmp/termux_framework_config.tmp
        
        # 获取最新代码
        if git pull; then
            # 恢复配置（但保留可能的新设置）
            if [ -f /tmp/termux_framework_config.tmp ]; then
                source /tmp/termux_framework_config.tmp
                # 更新配置文件中的版本号但保留用户设置
                sed -i "s/VERSION=.*/VERSION=\"$VERSION\"/" "$CONFIG_FILE"
                rm /tmp/termux_framework_config.tmp
            fi
            
            print_success "框架更新成功"
            exec "$SCRIPT_DIR/termux-framework.sh"
            exit 0
        else
            print_error "更新失败，请检查网络连接或仓库权限"
        fi
    else
        print_error "未找到Git仓库信息，无法更新"
    fi
    
    press_enter
}

# 扫描可用脚本
scan_scripts() {
    local scripts=()
    
    # 扫描脚本目录
    if [ -d "$SCRIPTS_DIR" ]; then
        while IFS= read -r script; do
            if [ -x "$script" ]; then
                # 提取脚本名称和描述
                local name=$(basename "$script")
                local desc=$(grep -m 1 "# Description:" "$script" | cut -d ':' -f 2- | sed 's/^[[:space:]]*//')
                
                if [ -z "$desc" ]; then
                    desc="$name"
                fi
                
                scripts+=("$script:$desc")
            fi
        done < <(find "$SCRIPTS_DIR" -type f -name "*.sh")
    fi
    
    echo "${scripts[@]}"
}

# 切换Termux软件源
switch_mirror() {
    print_title
    echo -e "${CYAN}选择Termux软件源:${RESET}\n"
    echo "1) 清华大学镜像源 (推荐国内用户)"
    echo "2) 阿里云镜像源"
    echo "3) 中科大镜像源"
    echo "4) 官方源 (国际)"
    echo "5) 自定义源"
    echo "0) 返回主菜单"
    
    read -p "请选择 [0-5]: " choice
    
    local mirror=""
    case $choice in
        1) mirror="https://mirrors.tuna.tsinghua.edu.cn/termux" ;;
        2) mirror="https://mirrors.aliyun.com/termux" ;;
        3) mirror="https://mirrors.ustc.edu.cn/termux" ;;
        4) mirror="https://packages.termux.dev/apt/termux-main" ;;
        5)
            read -p "请输入自定义镜像源URL: " mirror
            ;;
        0) return ;;
        *) 
            print_error "无效选项"
            press_enter
            switch_mirror
            return
            ;;
    esac
    
    if [ -n "$mirror" ]; then
        mkdir -p $PREFIX/etc/apt/sources.list.d/
        echo "deb $mirror stable main" > $PREFIX/etc/apt/sources.list.d/termux-main.list
        apt update -y
        
        # 更新配置
        sed -i "s|DEFAULT_MIRROR=.*|DEFAULT_MIRROR=\"$mirror\"|" "$CONFIG_FILE"
        
        print_success "软件源已切换至: $mirror"
    fi
    
    press_enter
}

# 更新Termux环境
update_termux() {
    print_title
    print_info "正在更新Termux环境..."
    
    apt update -y && apt upgrade -y
    
    print_success "Termux环境更新完成"
    press_enter
}

# 基本环境安装菜单
install_basic_environment() {
    while true; do
        print_title
        echo -e "${YELLOW}基本环境安装选项:${RESET}"
        echo "1) 安装所有基本工具 (git, curl, wget, python, openssh, vim, nano)"
        echo "2) 安装 Git"
        echo "3) 安装 Curl"
        echo "4) 安装 Wget"
        echo "5) 安装 Python"
        echo "6) 安装 OpenSSH"
        echo "7) 安装 Vim"
        echo "8) 安装 Nano"
        echo "0) 返回主菜单"
        echo ""
        
        read -p "请选择 [0-8]: " choice
        
        case $choice in
            1) 
                print_info "正在安装所有基本工具..."
                pkg update -y
                pkg install -y git curl wget python openssh vim nano
                print_success "所有基本工具安装完成"
                ;;
            2)
                print_info "正在安装 Git..."
                pkg update -y
                pkg install -y git
                print_success "Git 安装完成"
                ;;
            3)
                print_info "正在安装 Curl..."
                pkg update -y
                pkg install -y curl
                print_success "Curl 安装完成"
                ;;
            4)
                print_info "正在安装 Wget..."
                pkg update -y
                pkg install -y wget
                print_success "Wget 安装完成"
                ;;
            5)
                print_info "正在安装 Python..."
                pkg update -y
                pkg install -y python
                print_success "Python 安装完成"
                ;;
            6)
                print_info "正在安装 OpenSSH..."
                pkg update -y
                pkg install -y openssh
                print_success "OpenSSH 安装完成"
                ;;
            7)
                print_info "正在安装 Vim..."
                pkg update -y
                pkg install -y vim
                print_success "Vim 安装完成"
                ;;
            8)
                print_info "正在安装 Nano..."
                pkg update -y
                pkg install -y nano
                print_success "Nano 安装完成"
                ;;
            0)
                return
                ;;
            *)
                print_error "无效选项"
                ;;
        esac
        
        press_enter
    done
}

# 拉取仓库脚本
pull_repository_scripts() {
    print_title
    print_info "正在从仓库拉取脚本..."
    
    if [ -d "$SCRIPTS_DIR/.git" ]; then
        cd "$SCRIPTS_DIR"
        git pull
    else
        # 假设脚本仓库可能与框架仓库不同
        read -p "请输入脚本仓库URL (直接回车使用默认): " scripts_repo
        if [ -z "$scripts_repo" ]; then
            scripts_repo="$REPO_URL"
        fi
        
        rm -rf "$SCRIPTS_DIR"
        git clone "$scripts_repo" "$SCRIPTS_DIR"
    fi
    
    # 确保所有脚本有执行权限
    find "$SCRIPTS_DIR" -name "*.sh" -exec chmod +x {} \;
    
    print_success "脚本更新完成"
    press_enter
}

# 执行选定的脚本
execute_script() {
    local script="$1"
    
    if [ -f "$script" ] && [ -x "$script" ]; then
        print_info "执行脚本: $(basename "$script")"
        "$script"
    else
        print_error "脚本不存在或没有执行权限"
    fi
    
    press_enter
}

# 主菜单
main_menu() {
    while true; do
        print_title
        
        echo -e "${YELLOW}基本功能:${RESET}"
        echo "1) 安装基本环境"
        echo "2) 更新Termux环境"
        echo "3) 切换软件源"
        echo "4) 更新框架"
        echo "5) 拉取最新脚本"
        echo "6) 卸载功能"
        echo ""
        
        # 扫描并显示可用脚本
        local scripts=($(scan_scripts))
        if [ ${#scripts[@]} -gt 0 ]; then
            echo -e "${YELLOW}可用脚本:${RESET}"
            local i=6
            
            for script_info in "${scripts[@]}"; do
                IFS=':' read -r script_path script_desc <<< "$script_info"
                echo "$i) $script_desc"
                script_paths[$i]="$script_path"
                ((i++))
            done
            echo ""
        fi
        
        echo -e "${YELLOW}其他选项:${RESET}"
        echo "0) 退出"
        echo ""
        
        read -p "请选择 [0-$((i-1))]: " choice
        
        case $choice in
            1) install_basic_environment ;;
            2) update_termux ;;
            3) switch_mirror ;;
            4) update_framework ;;
            5) pull_repository_scripts ;;
            6) uninstall_menu ;;
            0) 
                echo "感谢使用，再见！"
                exit 0
                ;;
            *)
                if [[ $choice -ge 6 && $choice -lt $i ]]; then
                    execute_script "${script_paths[$choice]}"
                else
                    print_error "无效选项"
                    press_enter
                fi
                ;;
        esac
    done
}

# 检查是否是首次运行
first_run() {
    if [ ! -f "$SCRIPT_DIR/.initialized" ]; then
        print_title
        print_info "首次运行设置..."
        
        # 检查依赖
        check_dependencies
        
        # 设置初始化完成标记
        touch "$SCRIPT_DIR/.initialized"
    fi
}

# 卸载菜单
uninstall_menu() {
    print_title
    echo -e "${YELLOW}卸载选项:${RESET}"
    echo "1) 卸载扩展脚本"
    echo "2) 卸载整个框架"
    echo "0) 返回主菜单"
    echo ""
    
    read -p "请选择 [0-2]: " choice
    
    case $choice in
        1) uninstall_extension ;;
        2) uninstall_framework ;;
        0) return ;;
        *) 
            print_error "无效选项"
            press_enter
            uninstall_menu
            ;;
    esac
}

# 卸载扩展脚本
uninstall_extension() {
    print_title
    echo -e "${YELLOW}可卸载的扩展脚本:${RESET}"
    
    # 扫描可用脚本
    local scripts=($(scan_scripts))
    if [ ${#scripts[@]} -eq 0 ]; then
        print_warning "没有找到可卸载的扩展脚本"
        press_enter
        return
    fi
    
    local i=1
    declare -A script_map
    
    for script_info in "${scripts[@]}"; do
        IFS=':' read -r script_path script_desc <<< "$script_info"
        echo "$i) $script_desc ($(basename "$script_path"))"
        script_map[$i]="$script_path"
        ((i++))
    done
    
    echo "0) 返回上一级菜单"
    echo ""
    
    read -p "请选择要卸载的脚本 [0-$((i-1))]: " choice
    
    if [[ $choice -eq 0 ]]; then
        uninstall_menu
        return
    elif [[ $choice -ge 1 && $choice -lt $i ]]; then
        local script_path="${script_map[$choice]}"
        local script_name=$(basename "$script_path")
        
        read -p "确定要卸载脚本 '$script_name'? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rm -f "$script_path"
            print_success "脚本 '$script_name' 已成功卸载"
        else
            print_warning "卸载已取消"
        fi
    else
        print_error "无效选项"
    fi
    
    press_enter
    uninstall_menu
}

# 卸载整个框架
uninstall_framework() {
    print_title
    echo -e "${RED}警告: 此操作将卸载整个Termux集成脚本框架${RESET}"
    echo "包括所有扩展脚本和配置。"
    echo ""
    
    read -p "确定要卸载整个框架? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "卸载已取消"
        press_enter
        uninstall_menu
        return
    fi
    
    # 再次确认
    read -p "再次确认卸载? 此操作无法撤销 (yes/no): " confirm2
    if [[ ! "$confirm2" == "yes" ]]; then
        print_warning "卸载已取消"
        press_enter
        uninstall_menu
        return
    fi
    
    # 创建临时脚本来完成卸载
    # 这是必要的，因为脚本不能在运行时删除自己
    local temp_script="/data/data/com.termux/files/usr/tmp/uninstall_framework_$.sh"
    
    cat > "$temp_script" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

# 清理符号链接
rm -f "$PREFIX/bin/termux-framework"

# 删除框架目录
rm -rf "$HOME/.termux-framework"

# 打印成功消息
echo -e "\033[32m[成功]\033[0m Termux集成脚本框架已成功卸载"
echo ""
echo "感谢您使用本框架！"

# 删除临时脚本（自己）
rm -f "$0"
EOF
    
    chmod +x "$temp_script"
    
    print_info "开始卸载..."
    # 执行临时脚本并退出
    exec "$temp_script"
    exit 0
}

# 主函数
main() {
    first_run
    main_menu
}

# 启动脚本
main