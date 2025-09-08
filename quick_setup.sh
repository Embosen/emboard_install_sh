#!/bin/bash

# 快速系统设置脚本
# 专门用于配置NoMachine和Docker
# 包括: NoMachine音频接口禁用、Docker daemon.json配置、Docker权限设置

set -euo pipefail

echo "=== 快速系统设置脚本 ==="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "错误: 此脚本需要root权限"
    echo "请使用: sudo ./quick_setup.sh"
    exit 1
fi

# 获取当前用户信息
CURRENT_USER="${SUDO_USER:-$(whoami)}"
echo "当前用户: $CURRENT_USER"

# 1. 配置NoMachine
echo ""
echo "=== 配置NoMachine ==="
NX_CONFIG="/usr/NX/etc/node.cfg"

if [ -f "$NX_CONFIG" ]; then
    echo "找到NoMachine配置文件: $NX_CONFIG"
    
    # 备份原配置文件
    cp "$NX_CONFIG" "${NX_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "✅ 已备份原配置文件"
    
    # 配置AudioInterface
    if grep -q "AudioInterface" "$NX_CONFIG"; then
        echo "更新AudioInterface设置..."
        sed -i 's/^AudioInterface.*/AudioInterface disabled/' "$NX_CONFIG"
    else
        echo "添加AudioInterface设置..."
        echo "AudioInterface disabled" >> "$NX_CONFIG"
    fi
    
    echo "✅ NoMachine音频接口已禁用"
    
    # 重启NoMachine服务
    if systemctl is-active --quiet nxserver 2>/dev/null; then
        echo "重启NoMachine服务..."
        systemctl restart nxserver
        echo "✅ NoMachine服务已重启"
    else
        echo "⚠️ NoMachine服务未运行"
    fi
else
    echo "⚠️ 未找到NoMachine配置文件: $NX_CONFIG"
fi

# 2. 配置Docker
echo ""
echo "=== 配置Docker ==="

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker未安装，跳过Docker配置"
else
    # 2.1 替换Docker daemon.json
    echo "配置Docker daemon.json..."
    DAEMON_JSON_SOURCE="./daemon.json"
    DAEMON_JSON_TARGET="/etc/docker/daemon.json"
    
    if [ -f "$DAEMON_JSON_SOURCE" ]; then
        echo "找到daemon.json配置文件: $DAEMON_JSON_SOURCE"
        
        # 备份原配置文件
        if [ -f "$DAEMON_JSON_TARGET" ]; then
            cp "$DAEMON_JSON_TARGET" "${DAEMON_JSON_TARGET}.backup.$(date +%Y%m%d_%H%M%S)"
            echo "✅ 已备份原daemon.json配置文件"
        fi
        
        # 复制新配置文件
        cp "$DAEMON_JSON_SOURCE" "$DAEMON_JSON_TARGET"
        echo "✅ Docker daemon.json配置已更新"
    else
        echo "⚠️ 未找到daemon.json配置文件: $DAEMON_JSON_SOURCE"
    fi
    
    # 2.2 配置Docker权限
    echo "配置Docker权限..."
    # 检查用户是否已在docker组中
    if groups "$CURRENT_USER" | grep -q docker; then
        echo "✅ 用户 $CURRENT_USER 已在docker组中"
    else
        echo "将用户 $CURRENT_USER 添加到docker组..."
        usermod -aG docker "$CURRENT_USER"
        echo "✅ 用户已添加到docker组"
    fi
    
    # 重启Docker服务
    echo "重启Docker服务..."
    systemctl restart docker
    echo "✅ Docker服务已重启"
fi

echo ""
echo "=== 设置完成 ==="
echo ""
echo "重要提示:"
echo "1. Docker权限配置需要重新登录或运行: newgrp docker"
echo "2. 建议重新登录系统以确保所有配置生效"
echo ""
echo "现在可以运行以下命令测试Docker权限:"
echo "docker ps"
echo ""
echo "如果仍有权限问题，请运行: newgrp docker"
