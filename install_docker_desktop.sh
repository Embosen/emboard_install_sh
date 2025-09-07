#!/bin/bash

# Docker桌面图标安装脚本 - 支持多个应用

echo "=== 安装AIOT控制系统Docker桌面图标 ==="

# 获取当前脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 定义要安装的桌面图标文件
DESKTOP_FILES=(
    "AICV_base_GUI.desktop"
    "CVMP_AIOT.desktop" 
    "Emlab_AIOT.desktop"
)

# 定义对应的状态栏图标文件
STATUS_ICONS=(
    "status_logo_aicv.png"
    "status_logo_cvmp.png"
    "status_logo_aiot.png"
)

# 定义应用名称（用于显示）
APP_NAMES=(
    "AICV实验演示"
    "AIOT手势控制"
    "AIOT控制系统"
)

# 检查ico.png文件
ICO_FILE="$SCRIPT_DIR/ico.png"
if [ ! -f "$ICO_FILE" ]; then
    echo "错误: 未找到图标文件: $ICO_FILE"
    exit 1
fi

# 检查所有桌面文件是否存在
echo "检查桌面文件..."
for desktop_file in "${DESKTOP_FILES[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$desktop_file" ]; then
        echo "错误: 未找到桌面启动器文件: $desktop_file"
        exit 1
    fi
    echo "✓ 找到: $desktop_file"
done

# 检查所有状态栏图标文件是否存在
echo "检查状态栏图标文件..."
for status_icon in "${STATUS_ICONS[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$status_icon" ]; then
        echo "错误: 未找到状态栏图标文件: $status_icon"
        exit 1
    fi
    echo "✓ 找到: $status_icon"
done

# 确定桌面目录
if [ -d "$HOME/Desktop" ]; then
    DESKTOP_DIR="$HOME/Desktop"
elif [ -d "$HOME/桌面" ]; then
    DESKTOP_DIR="$HOME/桌面"
else
    echo "错误: 未找到桌面目录"
    exit 1
fi

echo "桌面目录: $DESKTOP_DIR"

# 复制桌面文件到系统目录
echo "正在安装桌面启动器..."

# 创建应用程序目录（如果不存在）
sudo mkdir -p /usr/share/applications
sudo mkdir -p /usr/share/icons

# 复制ico.png图标文件到系统图标目录
sudo cp "$ICO_FILE" /usr/share/icons/.ico.png
sudo chmod 644 /usr/share/icons/.ico.png

# 安装每个桌面图标
for i in "${!DESKTOP_FILES[@]}"; do
    desktop_file="${DESKTOP_FILES[$i]}"
    status_icon="${STATUS_ICONS[$i]}"
    app_name="${APP_NAMES[$i]}"
    
    echo "正在安装: $app_name ($desktop_file)"
    
    # 复制桌面文件到系统应用程序目录
    sudo cp "$SCRIPT_DIR/$desktop_file" /usr/share/applications/
    
    # 复制对应的状态栏图标文件
    sudo cp "$SCRIPT_DIR/$status_icon" "/usr/share/icons/.$status_icon"
    sudo chmod 644 "/usr/share/icons/.$status_icon"
    
    echo "✓ $app_name 安装完成"
done

# 更新桌面数据库
sudo update-desktop-database

echo "所有桌面启动器安装完成！"

# 询问是否在桌面上创建快捷方式
read -p "是否在桌面上创建快捷方式？(y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "正在创建桌面快捷方式..."
    # 为每个应用在桌面上创建快捷方式
    for i in "${!DESKTOP_FILES[@]}"; do
        desktop_file="${DESKTOP_FILES[$i]}"
        app_name="${APP_NAMES[$i]}"
        
        cp "$SCRIPT_DIR/$desktop_file" "$DESKTOP_DIR/"
        chmod +x "$DESKTOP_DIR/$desktop_file"
        echo "✓ 桌面快捷方式已创建: $DESKTOP_DIR/$desktop_file ($app_name)"
    done
fi

echo ""
echo "安装完成！现在你可以："
echo "1. 在应用程序菜单中找到以下应用："
for app_name in "${APP_NAMES[@]}"; do
    echo "   - $app_name"
done
echo "2. 或者在桌面上双击对应的图标启动程序"
echo ""
echo "注意：确保Docker容器 'emboard_aiot' 正在运行"
echo "如果容器未运行，启动器会自动尝试启动它"
echo ""
echo "已安装的应用："
for i in "${!DESKTOP_FILES[@]}"; do
    echo "  • ${APP_NAMES[$i]} - 状态栏图标: ${STATUS_ICONS[$i]}"
done 