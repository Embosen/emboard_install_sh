#!/bin/bash

# X11权限监控脚本
# 定期检查并恢复X11权限

export DISPLAY=:0

# 检查X11权限是否设置正确
check_x11_permissions() {
    # 获取xhost输出
    local xhost_output=$(xhost 2>/dev/null)
    
    # 检查是否有docker相关的权限设置
    # xhost +local:docker 会显示 "LOCAL:" 行，表示本地连接被允许
    if echo "$xhost_output" | grep -q "LOCAL:"; then
        return 0  # 权限已设置
    else
        # 调试信息：显示当前权限状态
        echo "$(date): 当前X11权限状态: $xhost_output"
        return 1  # 权限未设置
    fi
}

# 设置X11权限
set_x11_permissions() {
    echo "$(date): 设置X11权限..."
    if xhost +local:docker && xhost +local:root 2>/dev/null; then
        echo "$(date): ✅ X11权限设置成功"
        return 0
    else
        echo "$(date): ❌ X11权限设置失败"
        return 1
    fi
}

# 主循环
echo "$(date): 启动X11权限监控服务"

while true; do
    # 检查X11服务器是否运行
    if ! xset q &>/dev/null; then
        echo "$(date): X11服务器未运行，等待..."
        sleep 10
        continue
    fi
    
    # 检查权限
    if ! check_x11_permissions; then
        echo "$(date): 检测到X11权限丢失，正在恢复..."
        set_x11_permissions
    fi
    
    # 每30秒检查一次
    sleep 30
done
