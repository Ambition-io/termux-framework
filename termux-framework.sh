#!/data/data/com.termux/files/usr/bin/bash

# Termux集成脚本框架
VERSION="1.0.4"

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
RESET="\033[0m"

# 配置变量
SCRIPT_DIR="$HOME/.termux-framework"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
CONFIG_FILE="$SCRIPT_DIR/config.sh"
REPO_URL="https://github.com/Ambition-io/termux-framework.git"

# 确保目录存在
mkdir -p "$SCRIPTS_DIR"

# 创建配置文件（如果不存在）
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << EOF
#!/data/data/com.termux/files/usr/bin/bash
# 配置文件
REPO_URL="$REPO_URL"
DEFAULT_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/termux"
SHORTCUT_NAME="termux-framework"
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

# 打印信息、成功、警告和错误消息
print_info() { echo -e "${BLUE}[信息]${RESET} $1"; }
print_success() { echo -e "${GREEN}[成功]${RESET} $1"; }
print_warning() { echo -e "${YELLOW}[警告]${RESET} $1"; }
print_error() { echo -e "${RED}[错误]${RESET} $1"; }

# 按键继续
press_enter() {
    echo ""
    read -p "按 Enter 键继续..."
}

# 初始化框架
init_framework() {
    # 确保必要的目录存在
    mkdir -p "$SCRIPTS_DIR"
    
    # 检查快捷链接是否存在，不存在则创建
    if [ ! -f "$PREFIX/bin/$SHORTCUT_NAME" ]; then
        update_framework_shortcut
    fi
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

# 配置Git以使用HTTPS
configure_git() {
    if command -v git &> /dev/null; then
        git config --global core.askPass ""
        git config --global credential.helper ""
        
        if [[ "$REPO_URL" == git@* ]]; then
            REPO_URL=$(echo "$REPO_URL" | sed -e 's|git@github.com:|https://github.com/|')
            sed -i "s|REPO_URL=.*|REPO_URL=\"$REPO_URL\"|" "$CONFIG_FILE"
            print_info "已将仓库URL从SSH格式转换为HTTPS格式"
        fi
    fi
}

# 更新框架快捷链接
update_framework_shortcut() {
    local current_script="$(realpath "$0")"
    
    if [ -n "$1" ] && [ "$1" != "$SHORTCUT_NAME" ] && [ -f "$PREFIX/bin/$1" ]; then
        rm -f "$PREFIX/bin/$1"
    fi
    
    cat > "$PREFIX/bin/$SHORTCUT_NAME" << EOF
#!/data/data/com.termux/files/usr/bin/bash
exec "$current_script" "\$@"
EOF
    chmod +x "$PREFIX/bin/$SHORTCUT_NAME"
    
    print_info "框架快捷链接已创建/更新: $SHORTCUT_NAME"
}

# 扫描已安装脚本
scan_installed_scripts() {
    local scripts=()
    
    if [ -d "$SCRIPTS_DIR" ]; then
        while IFS= read -r script; do
            if [ -x "$script" ]; then
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
    echo "1) 清华大学镜像源 (国内推荐)"
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
        5) read -p "请输入自定义镜像源URL: " mirror ;;
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
        echo -e "${YELLOW}基本环境安装:${RESET}"
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
                print_info "安装所有基本工具..."
                pkg update -y
                pkg install -y git curl wget python openssh vim nano
                print_success "所有基本工具安装完成"
                ;;
            2)
                print_info "安装 Git..."
                pkg update -y
                pkg install -y git
                print_success "Git 安装完成"
                ;;
            3)
                print_info "安装 Curl..."
                pkg update -y
                pkg install -y curl
                print_success "Curl 安装完成"
                ;;
            4)
                print_info "安装 Wget..."
                pkg update -y
                pkg install -y wget
                print_success "Wget 安装完成"
                ;;
            5)
                print_info "安装 Python..."
                pkg update -y
                pkg install -y python
                print_success "Python 安装完成"
                ;;
            6)
                print_info "安装 OpenSSH..."
                pkg update -y
                pkg install -y openssh
                print_success "OpenSSH 安装完成"
                ;;
            7)
                print_info "安装 Vim..."
                pkg update -y
                pkg install -y vim
                print_success "Vim 安装完成"
                ;;
            8)
                print_info "安装 Nano..."
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

# 卸载菜单
uninstall_menu() {
    print_title
    echo -e "${YELLOW}卸载选项:${RESET}"
    echo "1) 卸载插件"
    echo "2) 卸载整个框架"
    echo "0) 返回上一级菜单"
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

# 卸载插件
uninstall_extension() {
    print_title
    echo -e "${YELLOW}可卸载的插件:${RESET}"
    
    local scripts=($(scan_installed_scripts))
    if [ ${#scripts[@]} -eq 0 ]; then
        print_warning "没有找到可卸载的插件"
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
    
    read -p "请选择要卸载的插件 [0-$((i-1))]: " choice
    
    if [[ $choice -eq 0 ]]; then
        uninstall_menu
        return
    elif [[ $choice -ge 1 && $choice -lt $i ]]; then
        local script_path="${script_map[$choice]}"
        local script_name=$(basename "$script_path")
        
        read -p "确定要卸载插件 '$script_name'? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            # 移除固定列表中的项目
            local pinned_file="$SCRIPT_DIR/pinned/scripts.list"
            if [ -f "$pinned_file" ]; then
                grep -v "$script_path:" "$pinned_file" > "$pinned_file.tmp"
                mv "$pinned_file.tmp" "$pinned_file"
            fi
            
            # 移除快捷链接
            local shortcuts_file="$SCRIPT_DIR/shortcuts/shortcuts.list"
            if [ -f "$shortcuts_file" ]; then
                while IFS=: read -r shortcut_name script_link; do
                    if [[ "$script_link" == "$script_path" ]]; then
                        rm -f "$PREFIX/bin/$shortcut_name"
                    fi
                done < "$shortcuts_file"
                
                grep -v ":$script_path$" "$shortcuts_file" > "$shortcuts_file.tmp"
                mv "$shortcuts_file.tmp" "$shortcuts_file"
            fi
            
            # 删除脚本文件
            rm -f "$script_path"
            print_success "插件 '$script_name' 已成功卸载"
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
    echo "包括所有插件和配置。"
    echo ""
    
    read -p "确定要卸载整个框架? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "卸载已取消"
        press_enter
        uninstall_menu
        return
    fi
    
    # 创建临时脚本来完成卸载
    local temp_script="/data/data/com.termux/files/usr/tmp/uninstall_framework_$.sh"
    
    cat > "$temp_script" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

# 获取配置文件中的快捷名称
SHORTCUT_NAME=$(grep -m 1 "^SHORTCUT_NAME=" "$HOME/.termux-framework/config.sh" | cut -d'"' -f2)
if [ -z "$SHORTCUT_NAME" ]; then
    SHORTCUT_NAME="termux-framework"
fi

# 清理符号链接
rm -f "$PREFIX/bin/$SHORTCUT_NAME"

# 删除框架目录
rm -rf "$HOME/.termux-framework"

echo -e "\033[32m[成功]\033[0m Termux集成脚本框架已成功卸载"
echo ""
echo "感谢您使用本框架！"

# 删除临时脚本
rm -f "$0"
EOF
    
    chmod +x "$temp_script"
    
    print_info "开始卸载..."
    exec "$temp_script"
    exit 0
}

# 执行选定的脚本
execute_script() {
    local script="$1"
    
    if [ -f "$script" ] && [ -x "$script" ]; then
        print_info "执行插件: $(basename "$script")"
        "$script"
    else
        print_error "插件不存在或没有执行权限"
    fi
    
    press_enter
}

# 设置菜单
settings_menu() {
    while true; do
        print_title
        echo -e "${YELLOW}设置:${RESET}"
        echo "1) 查看版本信息"
        echo "2) 卸载功能"
        echo "3) 配置管理"
        echo "0) 返回主菜单"
        echo ""
        
        read -p "请选择 [0-3]: " choice
        
        case $choice in
            1) show_version_info ;;
            2) uninstall_menu ;;
            3) config_management ;;
            0) return ;;
            *) 
                print_error "无效选项"
                press_enter
                ;;
        esac
    done
}

# 显示详细的版本信息
show_version_info() {
    print_title
    echo -e "${YELLOW}版本信息:${RESET}"
    echo "框架版本: $VERSION"
    echo "安装路径: $SCRIPT_DIR"
    
    local script_count=$(find "$SCRIPTS_DIR" -type f -name "*.sh" | wc -l)
    echo "已安装插件: $script_count"
    
    local pinned_file="$SCRIPT_DIR/pinned/scripts.list"
    if [ -f "$pinned_file" ]; then
        local pinned_count=$(wc -l < "$pinned_file")
        echo "已固定插件: $pinned_count"
    else
        echo "已固定插件: 0"
    fi
    
    if [ -f "$SCRIPT_DIR/.initialized" ]; then
        local install_date=$(stat -c %y "$SCRIPT_DIR/.initialized" 2>/dev/null || stat -f "%Sm" "$SCRIPT_DIR/.initialized" 2>/dev/null)
        echo "安装日期: $install_date"
    fi
    
    echo ""
    press_enter
}

# 配置管理
config_management() {
    print_title
    echo -e "${YELLOW}配置管理:${RESET}"
    echo "1) 修改仓库URL"
    echo "2) 恢复默认配置"
    echo "3) 自定义框架快捷名称"
    echo "0) 返回上一级菜单"
    echo ""
    
    read -p "请选择 [0-3]: " choice
    
    case $choice in
        1)
            read -p "请输入新的仓库URL: " new_repo
            if [ -n "$new_repo" ]; then
                if [[ "$new_repo" == git@* ]]; then
                    new_repo=$(echo "$new_repo" | sed -e 's|git@github.com:|https://github.com/|')
                    print_info "已将仓库URL从SSH格式转换为HTTPS格式"
                fi
                sed -i "s|REPO_URL=.*|REPO_URL=\"$new_repo\"|" "$CONFIG_FILE"
                print_success "仓库URL已更新"
            fi
            ;;
        2)
            read -p "确定要恢复默认配置? (y/n): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                cat > "$CONFIG_FILE" << EOF
#!/data/data/com.termux/files/usr/bin/bash
# 配置文件
REPO_URL="$REPO_URL"
DEFAULT_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/termux"
SHORTCUT_NAME="termux-framework"
EOF
                chmod +x "$CONFIG_FILE"
                
                print_success "配置已重置为默认值"
            fi
            ;;
        3)
            echo "当前快捷名称: $SHORTCUT_NAME"
            read -p "请输入新的快捷名称 (留空使用默认值'termux-framework'): " new_name
            
            if [ -z "$new_name" ]; then
                new_name="termux-framework"
            fi
            
            if command -v "$new_name" &> /dev/null && [ "$new_name" != "$SHORTCUT_NAME" ]; then
                print_warning "命令 '$new_name' 已存在，可能会导致冲突。"
                read -p "是否继续? (y/n): " continue_anyway
                if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                    print_warning "快捷名称修改已取消"
                    press_enter
                    return
                fi
            fi
            
            local old_shortcut="$SHORTCUT_NAME"
            
            sed -i "s|SHORTCUT_NAME=.*|SHORTCUT_NAME=\"$new_name\"|" "$CONFIG_FILE"
            
            source "$CONFIG_FILE"
            
            update_framework_shortcut "$old_shortcut"
            
            print_success "快捷名称已更新为: $new_name"
            ;;
        0)
            return
            ;;
        *)
            print_error "无效选项"
            press_enter
            ;;
    esac
    
    press_enter
}

# ==================== 新的插件管理功能 ====================

# 插件管理菜单
plugin_management() {
    while true; do
        print_title
        echo -e "${YELLOW}插件管理:${RESET}"
        echo "1) 已安装插件列表"
        echo "2) 安装新插件"
        echo "3) 管理快捷命令"
        echo "4) 管理主页固定插件" 
        echo "0) 返回主菜单"
        echo ""
        
        read -p "请选择 [0-4]: " choice
        
        case $choice in
            1) show_installed_plugins ;;
            2) install_new_plugins ;;
            3) manage_shortcuts ;;
            4) manage_pinned_plugins ;;
            0) return ;;
            *) 
                print_error "无效选项"
                press_enter
                ;;
        esac
    done
}

# 显示已安装插件
show_installed_plugins() {
    print_title
    echo -e "${YELLOW}已安装插件列表:${RESET}"
    
    local scripts=($(scan_installed_scripts))
    if [ ${#scripts[@]} -eq 0 ]; then
        print_warning "没有找到已安装的插件"
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
    
    read -p "请选择要执行的插件 [0-$((i-1))]: " choice
    
    if [[ $choice -eq 0 ]]; then
        return
    elif [[ $choice -ge 1 && $choice -lt $i ]]; then
        execute_script "${script_map[$choice]}"
    else
        print_error "无效选项"
        press_enter
    fi
}

# 从仓库安装新插件
install_new_plugins() {
    print_title
    echo -e "${YELLOW}安装新插件:${RESET}"
    
    # 检查依赖
    check_dependencies
    
    # 首先确保仓库已克隆，以便查看可用插件
    if [ ! -d "$SCRIPTS_DIR/.git" ]; then
        print_info "正在获取可用插件列表..."
        
        local temp_dir="/data/data/com.termux/files/usr/tmp/scripts_temp_$$"
        mkdir -p "$temp_dir"
        
        # 克隆仓库以获取最新插件
        GIT_TERMINAL_PROMPT=0 git clone "$REPO_URL" "$temp_dir" 2>/dev/null
        
        if [ $? -ne 0 ]; then
            print_error "无法连接到插件仓库，请检查网络或仓库地址"
            rm -rf "$temp_dir"
            press_enter
            return
        fi
        
        # 如果存在scripts目录，则使用它
        if [ -d "$temp_dir/scripts" ]; then
            temp_dir="$temp_dir/scripts"
        fi
    else
        print_info "正在更新可用插件列表..."
        # 仓库已存在，执行pull操作
        cd "$SCRIPTS_DIR"
        GIT_TERMINAL_PROMPT=0 git pull 2>/dev/null
        temp_dir="$SCRIPTS_DIR"
    fi
    
    # 扫描可用插件
    local available_plugins=()
    local i=1
    declare -A plugin_map
    
    while IFS= read -r script; do
        if [ -f "$script" ]; then
            local name=$(basename "$script")
            local desc=$(grep -m 1 "# Description:" "$script" | cut -d ':' -f 2- | sed 's/^[[:space:]]*//')
            
            if [ -z "$desc" ]; then
                desc="$name"
            fi
            
            echo "$i) $desc ($(basename "$script"))"
            plugin_map[$i]="$script"
            ((i++))
        fi
    done < <(find "$temp_dir" -type f -name "*.sh")
    
    if [ $i -eq 1 ]; then
        print_warning "仓库中没有找到可用的插件"
        # 如果是临时目录，则清理
        if [ "$temp_dir" != "$SCRIPTS_DIR" ]; then
            rm -rf "$(dirname "$temp_dir")"
        fi
        press_enter
        return
    fi
    
    echo "0) 返回上一级菜单"
    echo ""
    
    read -p "请选择要安装的插件 [0-$((i-1))]: " choice
    
    if [[ $choice -eq 0 ]]; then
        # 如果是临时目录，则清理
        if [ "$temp_dir" != "$SCRIPTS_DIR" ]; then
            rm -rf "$(dirname "$temp_dir")"
        fi
        return
    elif [[ $choice -ge 1 && $choice -lt $i ]]; then
        local plugin_path="${plugin_map[$choice]}"
        local plugin_name=$(basename "$plugin_path")
        
        # 安装插件
        print_info "正在安装插件 '$plugin_name'..."
        
        # 确保脚本目录存在
        mkdir -p "$SCRIPTS_DIR"
        
        # 复制插件到脚本目录
        cp "$plugin_path" "$SCRIPTS_DIR/"
        chmod +x "$SCRIPTS_DIR/$plugin_name"
        
        print_success "插件 '$plugin_name' 已成功安装"
        
        # 询问是否创建快捷命令
        read -p "是否为此插件创建快捷命令? (y/n): " create_shortcut
        if [[ "$create_shortcut" =~ ^[Yy]$ ]]; then
            local script_name=$(basename "$plugin_name" .sh)
            read -p "请输入快捷命令名称 (默认: $script_name): " shortcut_name
            if [ -z "$shortcut_name" ]; then
                shortcut_name="$script_name"
            fi
            
            if command -v "$shortcut_name" &> /dev/null; then
                print_warning "命令 '$shortcut_name' 已存在，可能会导致冲突。"
                read -p "是否继续? (y/n): " continue_anyway
                if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                    print_warning "快捷命令创建已取消"
                else
                    create_script_shortcut_internal "$SCRIPTS_DIR/$plugin_name" "$shortcut_name"
                fi
            else
                create_script_shortcut_internal "$SCRIPTS_DIR/$plugin_name" "$shortcut_name"
            fi
        fi
        
        # 询问是否固定到主菜单
        read -p "是否将此插件固定到主菜单? (y/n): " pin_to_menu
        if [[ "$pin_to_menu" =~ ^[Yy]$ ]]; then
            read -p "请输入显示在菜单中的名称 (默认: $plugin_name): " display_name
            if [ -z "$display_name" ]; then
                display_name="$plugin_name"
            fi
            
            mkdir -p "$SCRIPT_DIR/pinned"
            echo "$SCRIPTS_DIR/$plugin_name:$display_name" >> "$SCRIPT_DIR/pinned/scripts.list"
            
            print_success "插件 '$plugin_name' 已固定到主菜单"
        fi
    else
        print_error "无效选项"
    fi
    
    # 如果是临时目录，则清理
    if [ "$temp_dir" != "$SCRIPTS_DIR" ]; then
        rm -rf "$(dirname "$temp_dir")"
    fi
    
    press_enter
}

# 创建脚本快捷方式的内部函数
create_script_shortcut_internal() {
    local script_path="$1"
    local shortcut_name="$2"
    
    local abs_script_path=$(readlink -f "$script_path" 2>/dev/null || realpath "$script_path" 2>/dev/null || echo "$script_path")
    
    # 如果已存在，先移除
    rm -f "$PREFIX/bin/$shortcut_name"
    
    # 在bin中创建快捷方式
    cat > "$PREFIX/bin/$shortcut_name" << EOF
#!/data/data/com.termux/files/usr/bin/bash
# 插件快捷方式
# 目标: $abs_script_path

cd "$(dirname "$abs_script_path")" && exec "./$(basename "$abs_script_path")" "\$@"
EOF
    chmod +x "$PREFIX/bin/$shortcut_name"
    
    # 存储快捷方式信息
    mkdir -p "$SCRIPT_DIR/shortcuts"
    
    # 如果快捷方式已存在，先移除旧条目
    if [ -f "$SCRIPT_DIR/shortcuts/shortcuts.list" ]; then
        grep -v "^$shortcut_name:" "$SCRIPT_DIR/shortcuts/shortcuts.list" > "$SCRIPT_DIR/shortcuts/shortcuts.list.tmp"
        mv "$SCRIPT_DIR/shortcuts/shortcuts.list.tmp" "$SCRIPT_DIR/shortcuts/shortcuts.list"
    fi
    
    echo "$shortcut_name:$abs_script_path" >> "$SCRIPT_DIR/shortcuts/shortcuts.list"
    
    print_success "快捷命令 '$shortcut_name' 已创建"
}

# 管理快捷命令
manage_shortcuts() {
    while true; do
        print_title
        echo -e "${YELLOW}快捷命令管理:${RESET}"
        echo "1) 查看现有快捷命令"
        echo "2) 创建新快捷命令"
        echo "3) 删除快捷命令"
        echo "0) 返回上一级菜单"
        echo ""
        
        read -p "请选择 [0-3]: " choice
        
        case $choice in
            1) view_shortcuts ;;
            2) create_shortcut ;;
            3) remove_shortcut ;;
            0) return ;;
            *) 
                print_error "无效选项"
                press_enter
                ;;
        esac
    done
}

# 查看现有快捷命令
view_shortcuts() {
    print_title
    echo -e "${YELLOW}现有快捷命令:${RESET}"
    
    local shortcuts_file="$SCRIPT_DIR/shortcuts/shortcuts.list"
    if [ ! -f "$shortcuts_file" ] || [ ! -s "$shortcuts_file" ]; then
        print_warning "没有找到快捷命令"
        press_enter
        return
    fi
    
    local i=1
    
    while IFS=: read -r shortcut_name script_path; do
        if [ -f "$PREFIX/bin/$shortcut_name" ]; then
            echo "$i) $shortcut_name -> $(basename "$script_path")"
            ((i++))
        fi
    done < "$shortcuts_file"
    
    if [ $i -eq 1 ]; then
        print_warning "没有找到有效的快捷命令"
    fi
    
    echo ""
    press_enter
}

# 创建新快捷命令
create_shortcut() {
    print_title
    echo -e "${YELLOW}为插件创建快捷命令:${RESET}"
    
    local scripts=($(scan_installed_scripts))
    if [ ${#scripts[@]} -eq 0 ]; then
        print_warning "没有找到可用的插件"
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
    
    read -p "请选择要创建快捷方式的插件 [0-$((i-1))]: " choice
    
    if [[ $choice -eq 0 ]]; then
        return
    elif [[ $choice -ge 1 && $choice -lt $i ]]; then
        local script_path="${script_map[$choice]}"
        local script_name=$(basename "$script_path" .sh)
        
        read -p "请输入快捷命令名称 (默认: $script_name): " shortcut_name
        if [ -z "$shortcut_name" ]; then
            shortcut_name="$script_name"
        fi
        
        if command -v "$shortcut_name" &> /dev/null; then
            print_warning "命令 '$shortcut_name' 已存在，可能会导致冲突。"
            read -p "是否继续? (y/n): " continue_anyway
            if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                print_warning "快捷命令创建已取消"
                press_enter
                return
            fi
        fi
        
        create_script_shortcut_internal "$script_path" "$shortcut_name"
    else
        print_error "无效选项"
    fi
    
    press_enter
}

# 删除快捷命令
remove_shortcut() {
    print_title
    echo -e "${YELLOW}删除快捷命令:${RESET}"
    
    local shortcuts_file="$SCRIPT_DIR/shortcuts/shortcuts.list"
    if [ ! -f "$shortcuts_file" ] || [ ! -s "$shortcuts_file" ]; then
        print_warning "没有找到快捷命令"
        press_enter
        return
    fi
    
    local i=1
    declare -A shortcut_map
    
    while IFS=: read -r shortcut_name script_path; do
        if [ -f "$PREFIX/bin/$shortcut_name" ]; then
            echo "$i) $shortcut_name -> $(basename "$script_path")"
            shortcut_map[$i]="$shortcut_name:$script_path"
            ((i++))
        fi
    done < "$shortcuts_file"
    
    if [ $i -eq 1 ]; then
        print_warning "没有找到有效的快捷命令"
        press_enter
        return
    fi
    
    echo "0) 返回上一级菜单"
    echo ""
    
    read -p "请选择要删除的快捷命令 [0-$((i-1))]: " choice
    
    if [[ $choice -eq 0 ]]; then
        return
    elif [[ $choice -ge 1 && $choice -lt $i ]]; then
        local entry="${shortcut_map[$choice]}"
        IFS=':' read -r shortcut_name script_path <<< "$entry"
        
        read -p "确定要删除快捷命令 '$shortcut_name'? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            # 删除快捷命令文件
            rm -f "$PREFIX/bin/$shortcut_name"
            
            # 从列表中移除
            grep -v "^$shortcut_name:" "$shortcuts_file" > "$shortcuts_file.tmp"
            mv "$shortcuts_file.tmp" "$shortcuts_file"
            
            print_success "快捷命令 '$shortcut_name' 已成功删除"
        else
            print_warning "删除已取消"
        fi
    else
        print_error "无效选项"
    fi
    
    press_enter
}

# 管理主页固定插件
manage_pinned_plugins() {
    while true; do
        print_title
        echo -e "${YELLOW}主页固定插件管理:${RESET}"
        echo "1) 查看已固定插件"
        echo "2) 添加固定插件"
        echo "3) 移除固定插件"
        echo "0) 返回上一级菜单"
        echo ""
        
        read -p "请选择 [0-3]: " choice
        
        case $choice in
            1) view_pinned_plugins ;;
            2) add_pinned_plugin ;;
            3) remove_pinned_plugin ;;
            0) return ;;
            *) 
                print_error "无效选项"
                press_enter
                ;;
        esac
    done
}

# 查看已固定插件
view_pinned_plugins() {
    print_title
    echo -e "${YELLOW}已固定的插件:${RESET}"
    
    local pinned_file="$SCRIPT_DIR/pinned/scripts.list"
    if [ ! -f "$pinned_file" ] || [ ! -s "$pinned_file" ]; then
        print_warning "没有找到已固定的插件"
        press_enter
        return
    fi
    
    local i=1
    
    while IFS=: read -r script_path display_name; do
        if [ -f "$script_path" ] && [ -x "$script_path" ]; then
            echo "$i) $display_name ($(basename "$script_path"))"
            ((i++))
        fi
    done < "$pinned_file"
    
    if [ $i -eq 1 ]; then
        print_warning "没有找到有效的固定插件"
    fi
    
    echo ""
    press_enter
}

# 添加固定插件
add_pinned_plugin() {
    print_title
    echo -e "${YELLOW}添加固定插件到主页:${RESET}"
    
    local scripts=($(scan_installed_scripts))
    if [ ${#scripts[@]} -eq 0 ]; then
        print_warning "没有找到可用的插件"
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
    
    read -p "请选择要固定的插件 [0-$((i-1))]: " choice
    
    if [[ $choice -eq 0 ]]; then
        return
    elif [[ $choice -ge 1 && $choice -lt $i ]]; then
        local script_path="${script_map[$choice]}"
        local script_name=$(basename "$script_path")
        
        # 检查是否已经固定
        local pinned_file="$SCRIPT_DIR/pinned/scripts.list"
        if [ -f "$pinned_file" ]; then
            if grep -q "^$script_path:" "$pinned_file"; then
                print_warning "该插件已经固定在主页"
                press_enter
                return
            fi
        fi
        
        read -p "请输入显示在主页的名称 (默认: $script_name): " display_name
        if [ -z "$display_name" ]; then
            display_name="$script_name"
        fi
        
        mkdir -p "$SCRIPT_DIR/pinned"
        echo "$script_path:$display_name" >> "$SCRIPT_DIR/pinned/scripts.list"
        
        print_success "插件 '$script_name' 已成功固定到主页"
    else
        print_error "无效选项"
    fi
    
    press_enter
}

# 移除固定插件
remove_pinned_plugin() {
    print_title
    echo -e "${YELLOW}从主页移除固定插件:${RESET}"
    
    local pinned_file="$SCRIPT_DIR/pinned/scripts.list"
    if [ ! -f "$pinned_file" ] || [ ! -s "$pinned_file" ]; then
        print_warning "没有找到已固定的插件"
        press_enter
        return
    fi
    
    local i=1
    declare -A pinned_map
    
    while IFS=: read -r script_path display_name; do
        if [ -f "$script_path" ] && [ -x "$script_path" ]; then
            echo "$i) $display_name ($(basename "$script_path"))"
            pinned_map[$i]="$script_path:$display_name"
            ((i++))
        fi
    done < "$pinned_file"
    
    if [ $i -eq 1 ]; then
        print_warning "没有找到有效的固定插件"
        press_enter
        return
    }
    
    echo "0) 返回上一级菜单"
    echo ""
    
    read -p "请选择要移除的固定插件 [0-$((i-1))]: " choice
    
    if [[ $choice -eq 0 ]]; then
        return
    elif [[ $choice -ge 1 && $choice -lt $i ]]; then
        local entry="${pinned_map[$choice]}"
        
        # 从固定列表中删除条目
        grep -v "^$entry$" "$pinned_file" > "$pinned_file.tmp"
        mv "$pinned_file.tmp" "$pinned_file"
        
        # 提取显示名称以用于成功消息
        IFS=':' read -r script_path display_name <<< "$entry"
        
        print_success "插件 '$display_name' 已成功从主页移除"
    else
        print_error "无效选项"
    fi
    
    press_enter
}

# 主菜单
main_menu() {
    while true; do
        print_title
        echo -e "${CYAN}主菜单:${RESET}"
        echo "1) 切换软件源"
        echo "2) 更新Termux环境"
        echo "3) 安装基本环境"
        echo "4) 插件管理"
        echo "5) 设置"
        echo "0) 退出"
        echo ""
        
        # 显示已固定的插件
        local pinned_file="$SCRIPT_DIR/pinned/scripts.list"
        local pinned_count=0
        
        if [ -f "$pinned_file" ] && [ -s "$pinned_file" ]; then
            echo -e "${YELLOW}快速启动:${RESET}"
            
            while IFS=: read -r script_path display_name; do
                if [ -f "$script_path" ] && [ -x "$script_path" ]; then
                    ((pinned_count++))
                    echo "$((pinned_count+5))) $display_name"
                fi
            done < "$pinned_file"
            
            if [ $pinned_count -gt 0 ]; then
                echo ""
            fi
        fi
        
        echo -n "请选择 [0-5"
        if [ $pinned_count -gt 0 ]; then
            echo -n "-$((pinned_count+5))"
        fi
        echo -n "]: "
        read choice
        
        case $choice in
            1) switch_mirror ;;
            2) update_termux ;;
            3) install_basic_environment ;;
            4) plugin_management ;;
            5) settings_menu ;;
            0) exit 0 ;;
            *)
                # 检查是否选择了固定插件
                if [ -f "$pinned_file" ] && [ -s "$pinned_file" ] && [ -n "$pinned_count" ]; then
                    local pinned_index=$((choice-5))
                    if [ $pinned_index -ge 1 ] && [ $pinned_index -le $pinned_count ]; then
                        local j=0
                        while IFS=: read -r script_path display_name; do
                            if [ -f "$script_path" ] && [ -x "$script_path" ]; then
                                ((j++))
                                if [ $j -eq $pinned_index ]; then
                                    execute_script "$script_path"
                                    break
                                fi
                            fi
                        done < "$pinned_file"
                        continue
                    fi
                fi
                
                print_error "无效选项"
                press_enter
                ;;
        esac
    done
}

# 主程序
init_framework
main_menu
