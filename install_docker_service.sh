#!/bin/bash

# AIOT容器系统服务安装脚本 - 通用增强版

set -euo pipefail

echo "=== 安装AIOT容器系统服务 ==="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "错误: 此脚本需要root权限来安装系统服务"
    echo "请使用: sudo ./install_docker_service.sh"
    exit 1
fi

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="$SCRIPT_DIR/aiot-container.service"
START_SCRIPT="$SCRIPT_DIR/start_container.sh"
STOP_SCRIPT="$SCRIPT_DIR/stop_container.sh"

# 获取当前用户信息
CURRENT_USER="${SUDO_USER:-$(whoami)}"
CURRENT_USER_ID=$(id -u "$CURRENT_USER")
CURRENT_USER_HOME=$(getent passwd "$CURRENT_USER" | cut -d: -f6)

echo "检测到用户: $CURRENT_USER (ID: $CURRENT_USER_ID)"
echo "用户主目录: $CURRENT_USER_HOME"

# 检查必要文件
echo "检查必要文件..."
if [ ! -f "$SERVICE_FILE" ]; then
    echo "错误: 未找到服务文件: $SERVICE_FILE"
    exit 1
fi
echo "✓ 找到服务文件: $SERVICE_FILE"

if [ ! -f "$START_SCRIPT" ]; then
    echo "错误: 未找到启动脚本: $START_SCRIPT"
    exit 1
fi
echo "✓ 找到启动脚本: $START_SCRIPT"

if [ ! -f "$STOP_SCRIPT" ]; then
    echo "错误: 未找到停止脚本: $STOP_SCRIPT"
    exit 1
fi
echo "✓ 找到停止脚本: $STOP_SCRIPT"

# 检查Docker是否可用
echo "检查Docker环境..."
if ! command -v docker &> /dev/null; then
    echo "错误: Docker未安装或不在PATH中"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "警告: Docker服务未运行，请确保Docker已启动"
fi
echo "✓ Docker环境检查完成"

echo "正在安装系统服务..."

# 给脚本添加执行权限
chmod +x "$START_SCRIPT"
chmod +x "$STOP_SCRIPT"
echo "✓ 脚本权限设置完成"

# 停止现有服务（如果存在）
if systemctl is-active --quiet aiot-container.service 2>/dev/null; then
    echo "停止现有服务..."
    systemctl stop aiot-container.service
fi

# 创建优化的服务文件
echo "创建优化的服务配置..."
cat > /etc/systemd/system/aiot-container.service << EOF
[Unit]
Description=AIOT Docker Container Service
Documentation=https://github.com/Embosen/emboard_install_sh
After=docker.service network-online.target
Wants=docker.service network-online.target
Requires=docker.service

# 等待Docker完全启动
ExecStartPre=/bin/bash -c 'until docker info >/dev/null 2>&1; do sleep 1; done'

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$SCRIPT_DIR
ExecStart=$START_SCRIPT
ExecStop=$STOP_SCRIPT
ExecReload=/bin/kill -HUP \$MAINPID

# 超时设置
TimeoutStartSec=120
TimeoutStopSec=60
TimeoutSec=120

# 重试设置
Restart=on-failure
RestartSec=10
StartLimitInterval=300
StartLimitBurst=3

# 环境变量
Environment=HOME=$CURRENT_USER_HOME
Environment=USER=$CURRENT_USER
Environment=DISPLAY=:0

# 日志设置
StandardOutput=journal
StandardError=journal
SyslogIdentifier=aiot-container

[Install]
WantedBy=multi-user.target
EOF

# 重新加载systemd配置
echo "重新加载systemd配置..."
systemctl daemon-reload
echo "✓ systemd配置重新加载完成"

# 启用服务（开机自启）
echo "启用服务开机自启..."
systemctl enable aiot-container.service
echo "✓ 服务已启用开机自启"

# 启动服务
echo "启动服务..."
if systemctl start aiot-container.service; then
    echo "✓ 服务启动成功"
else
    echo "⚠ 服务启动失败，但已安装完成"
fi

echo ""
echo "✅ 系统服务安装完成！"
echo ""

# 显示服务状态
echo "=== 服务状态 ==="
systemctl status aiot-container.service --no-pager -l

echo ""
echo "=== 可用命令 ==="
echo "启动服务: sudo systemctl start aiot-container.service"
echo "停止服务: sudo systemctl stop aiot-container.service"
echo "重启服务: sudo systemctl restart aiot-container.service"
echo "查看状态: sudo systemctl status aiot-container.service"
echo "查看日志: sudo journalctl -u aiot-container.service -f"
echo "禁用自启: sudo systemctl disable aiot-container.service"
echo "卸载服务: sudo systemctl disable aiot-container.service && sudo rm /etc/systemd/system/aiot-container.service && sudo systemctl daemon-reload"

echo ""
echo "=== 服务特性 ==="
echo "• 自动等待Docker服务就绪"
echo "• 失败时自动重试（最多3次）"
echo "• 支持网络在线检测"
echo "• 优化的超时设置"
echo "• 完整的日志记录"

echo ""
echo "现在容器将在系统启动时自动运行！"
echo "你可以使用桌面图标来启动AIOT程序。" 