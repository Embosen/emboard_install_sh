#!/bin/bash

# AIOT容器用户服务安装脚本 - 支持X11权限
# 此脚本只安装用户级服务，不安装系统级服务

set -euo pipefail

echo "=== 安装AIOT容器用户服务 ==="

# 检查是否为root用户
if [ "$EUID" -eq 0 ]; then
    echo "错误: 此脚本不应以root用户运行"
    echo "请以普通用户身份运行: ./install_docker_service.sh"
    echo "注意: 这是用户级服务，无需root权限"
    exit 1
fi

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="$SCRIPT_DIR/aiot-container.service"
START_SCRIPT="$SCRIPT_DIR/start_container.sh"
STOP_SCRIPT="$SCRIPT_DIR/stop_container.sh"

echo "脚本目录: $SCRIPT_DIR"
echo "启动脚本: $START_SCRIPT"
echo "停止脚本: $STOP_SCRIPT"

# 获取当前用户信息
CURRENT_USER=$(whoami)
CURRENT_USER_ID=$(id -u "$CURRENT_USER")
CURRENT_USER_HOME="$HOME"

echo "当前用户: $CURRENT_USER (ID: $CURRENT_USER_ID)"
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
    echo "请确保在正确的目录中运行此脚本"
    exit 1
fi
echo "✓ 找到启动脚本: $START_SCRIPT"

if [ ! -f "$STOP_SCRIPT" ]; then
    echo "错误: 未找到停止脚本: $STOP_SCRIPT"
    echo "请确保在正确的目录中运行此脚本"
    exit 1
fi
echo "✓ 找到停止脚本: $STOP_SCRIPT"

# 检查Docker是否可用
echo "检查Docker环境..."
if ! command -v docker &> /dev/null; then
    echo "错误: Docker未安装或不在PATH中"
    exit 1
fi

# 检查用户是否在docker组中
if ! groups | grep -q docker; then
    echo "⚠️ 警告: 当前用户不在docker组中"
    echo "请运行以下命令将用户添加到docker组:"
    echo "sudo usermod -aG docker $CURRENT_USER"
    echo "然后重新登录或运行: newgrp docker"
    echo ""
    echo "继续安装服务，但可能需要sudo权限运行Docker命令"
fi

if ! docker info &> /dev/null; then
    echo "警告: Docker服务未运行，请确保Docker已启动"
fi
echo "✓ Docker环境检查完成"

echo "正在安装用户服务..."

# 给脚本添加执行权限
chmod +x "$START_SCRIPT"
chmod +x "$STOP_SCRIPT"
chmod +x "$SCRIPT_DIR/x11-permissions-monitor.sh"
echo "✓ 脚本权限设置完成"

# 创建用户服务目录
USER_SERVICE_DIR="$CURRENT_USER_HOME/.config/systemd/user"
mkdir -p "$USER_SERVICE_DIR"
echo "✓ 创建用户服务目录: $USER_SERVICE_DIR"

# 停止现有用户服务（如果存在）
if systemctl --user is-active --quiet aiot-container.service 2>/dev/null; then
    echo "停止现有用户服务..."
    systemctl --user stop aiot-container.service
fi

# 创建X11权限监控服务
echo "创建X11权限监控服务..."
cat > "$USER_SERVICE_DIR/x11-permissions-monitor.service" << EOF
[Unit]
Description=X11 Permissions Monitor for Docker
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
ExecStart=$SCRIPT_DIR/x11-permissions-monitor.sh
Restart=always
RestartSec=10
Environment=DISPLAY=:0

[Install]
WantedBy=default.target
EOF

# 创建用户服务文件
echo "创建用户服务配置..."
cat > "$USER_SERVICE_DIR/aiot-container.service" << EOF
[Unit]
Description=AIOT Docker Container Service
Documentation=https://github.com/Embosen/emboard_install_sh
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$SCRIPT_DIR
# 等待Docker完全启动（最多等待30秒）
ExecStartPre=/bin/bash -c 'for i in {1..30}; do if docker info >/dev/null 2>&1; then break; fi; sleep 1; done'
# 设置X11权限，允许Docker容器访问显示
ExecStartPre=/bin/bash -c 'export DISPLAY=:0 && xhost +local:docker && xhost +local:root 2>/dev/null || echo "警告: 无法设置X11权限，可能影响GUI显示"'
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
WantedBy=default.target
EOF

# 重新加载用户systemd配置
echo "重新加载用户systemd配置..."
systemctl --user daemon-reload
echo "✓ 用户systemd配置重新加载完成"

# 启用X11监控服务（开机自启）
echo "启用X11监控服务开机自启..."
systemctl --user enable x11-permissions-monitor.service
echo "✓ X11监控服务已启用开机自启"

# 启用用户服务（开机自启）
echo "启用用户服务开机自启..."
systemctl --user enable aiot-container.service
echo "✓ 用户服务已启用开机自启"

# 启用用户服务在系统启动时自动启动
echo "启用用户服务在系统启动时自动启动..."
sudo loginctl enable-linger "$CURRENT_USER"
echo "✓ 用户服务将在系统启动时自动启动"

# 启动X11监控服务
echo "启动X11监控服务..."
if systemctl --user start x11-permissions-monitor.service; then
    echo "✓ X11监控服务启动成功"
else
    echo "⚠ X11监控服务启动失败，但已安装完成"
fi

# 启动用户服务
echo "启动用户服务..."
if systemctl --user start aiot-container.service; then
    echo "✓ 用户服务启动成功"
else
    echo "⚠ 用户服务启动失败，但已安装完成"
fi

echo ""
echo "✅ 用户服务安装完成！"
echo ""

# 显示服务状态
echo "=== 用户服务状态 ==="
systemctl --user status aiot-container.service --no-pager -l

echo ""
echo "=== 可用命令 ==="
echo "启动服务: systemctl --user start aiot-container.service"
echo "停止服务: systemctl --user stop aiot-container.service"
echo "重启服务: systemctl --user restart aiot-container.service"
echo "查看状态: systemctl --user status aiot-container.service"
echo "查看日志: journalctl --user -u aiot-container.service -f"
echo "禁用自启: systemctl --user disable aiot-container.service"
echo "卸载服务: systemctl --user disable aiot-container.service && rm $USER_SERVICE_DIR/aiot-container.service && systemctl --user daemon-reload"

echo ""
echo "=== 用户服务特性 ==="
echo "• 用户级服务，无需root权限"
echo "• 自动等待Docker服务就绪"
echo "• 自动设置X11显示权限"
echo "• X11权限监控服务，自动恢复丢失的权限"
echo "• 失败时自动重试（最多3次）"
echo "• 支持网络在线检测"
echo "• 优化的超时设置"
echo "• 完整的日志记录"

echo ""
echo "=== X11权限说明 ==="
echo "• 用户服务在图形会话启动后自动设置X11权限"
echo "• X11监控服务每30秒检查一次权限状态"
echo "• 如果检测到权限丢失，会自动恢复"
echo "• 重启后权限会自动恢复，无需手动设置"
echo "• 如果X11权限设置失败，会显示警告信息但不影响容器启动"
echo "• 支持root权限访问X服务器"

echo ""
echo "=== 重要说明 ==="
echo "• 这是纯用户级服务，无需root权限"
echo "• 在用户登录后自动启动"
echo "• 已启用linger，系统启动时自动启动用户服务"
echo "• 自动设置X11权限，支持GUI应用"
echo "• 确保用户已添加到docker组: sudo usermod -aG docker $CURRENT_USER"
echo ""
echo "=== 与系统服务的区别 ==="
echo "• 不安装系统级服务，避免权限冲突"
echo "• 更安全，无需root权限"
echo "• 更好的X11权限管理"
echo ""
echo "现在容器将在用户登录后自动运行！"
echo "你可以使用桌面图标来启动AIOT程序。" 