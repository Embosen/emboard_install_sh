#!/bin/bash

# AIOT容器系统服务安装脚本

echo "=== 安装AIOT容器系统服务 ==="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "错误: 此脚本需要root权限来安装系统服务"
    echo "请使用: sudo ./install_service.sh"
    exit 1
fi

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="$SCRIPT_DIR/aiot-container.service"
START_SCRIPT="$SCRIPT_DIR/start_container.sh"
STOP_SCRIPT="$SCRIPT_DIR/stop_container.sh"

# 检查必要文件
if [ ! -f "$SERVICE_FILE" ]; then
    echo "错误: 未找到服务文件: $SERVICE_FILE"
    exit 1
fi

if [ ! -f "$START_SCRIPT" ]; then
    echo "错误: 未找到启动脚本: $START_SCRIPT"
    exit 1
fi

if [ ! -f "$STOP_SCRIPT" ]; then
    echo "错误: 未找到停止脚本: $STOP_SCRIPT"
    exit 1
fi

echo "正在安装系统服务..."

# 给脚本添加执行权限
chmod +x "$START_SCRIPT"
chmod +x "$STOP_SCRIPT"

# 复制服务文件到系统目录，并替换路径占位符
sed "s|%i|$SCRIPT_DIR|g" "$SERVICE_FILE" > /etc/systemd/system/aiot-container.service

# 重新加载systemd配置
systemctl daemon-reload

# 启用服务（开机自启）
systemctl enable aiot-container.service

echo "✅ 系统服务安装完成！"
echo ""

echo "服务状态:"
systemctl status aiot-container.service --no-pager -l

echo ""
echo "可用命令:"
echo "启动服务: sudo systemctl start aiot-container.service"
echo "停止服务: sudo systemctl stop aiot-container.service"
echo "重启服务: sudo systemctl restart aiot-container.service"
echo "查看状态: sudo systemctl status aiot-container.service"
echo "查看日志: sudo journalctl -u aiot-container.service -f"
echo "禁用自启: sudo systemctl disable aiot-container.service"

echo ""
echo "现在容器将在系统启动时自动运行！"
echo "你可以使用桌面图标来启动AIOT程序。" 