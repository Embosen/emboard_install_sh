#!/bin/bash

# AIOT容器停止脚本

echo "=== AIOT容器停止脚本 ==="

CONTAINER_NAME="emboard_aiot"

# 检查Docker是否运行
if ! docker info &>/dev/null; then
    echo "错误: Docker服务未运行"
    exit 1
fi

# 检查容器是否存在
if ! docker ps -a --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
    echo "容器 '$CONTAINER_NAME' 不存在"
    exit 0
fi

# 检查容器是否正在运行
if docker ps --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
    echo "正在停止容器 '$CONTAINER_NAME'..."
    docker stop $CONTAINER_NAME
    
    if [ $? -eq 0 ]; then
        echo "✅ 容器已停止"
    else
        echo "❌ 容器停止失败"
        exit 1
    fi
else
    echo "容器 '$CONTAINER_NAME' 已经停止"
fi

echo ""
echo "容器状态:"
docker ps -a --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 