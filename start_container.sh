#!/bin/bash

# AIOT容器后台启动脚本

echo "=== AIOT容器后台启动脚本 ==="

# 容器配置
CONTAINER_NAME="emboard_aiot"
IMAGE_NAME="emboard/mediapipe-gpu-aiot:r35.4.1"

# 检查Docker是否运行
if ! docker info &>/dev/null; then
    echo "错误: Docker服务未运行，请先启动Docker"
    exit 1
fi

# 设置X11权限，确保容器可以访问显示
echo "设置X11权限..."
export DISPLAY=:0
if xhost +local:docker && xhost +local:root 2>/dev/null; then
    echo "✅ X11权限设置成功"
else
    echo "⚠️ 警告: 无法设置X11权限，可能影响GUI显示"
fi

# 等待jtop服务启动
echo "等待jtop服务启动..."
JTOP_SOCK="/run/jtop.sock"
MAX_WAIT=60  # 最多等待60秒
WAIT_COUNT=0

while [ ! -S "$JTOP_SOCK" ] && [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    echo "等待jtop.sock文件创建... ($WAIT_COUNT/$MAX_WAIT)"
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
done

if [ -S "$JTOP_SOCK" ]; then
    echo "✅ jtop.sock文件已就绪"
else
    echo "⚠️ 警告: jtop.sock文件未在${MAX_WAIT}秒内创建，将跳过此挂载"
    JTOP_SOCK=""
fi

# 检查容器是否已经存在
if docker ps -a --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
    echo "容器 '$CONTAINER_NAME' 已存在"
    
    # 检查容器是否正在运行
    if docker ps --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
        echo "容器已在运行中，无需重复启动"
        echo "容器状态:"
        docker ps --filter "name=$CONTAINER_NAME"
        exit 0
    else
        echo "容器已停止，正在启动..."
        docker start $CONTAINER_NAME
        sleep 3
    fi
else
    echo "容器不存在，正在创建并启动..."
    
    # 构建docker run命令
    DOCKER_CMD="docker run \
        --runtime nvidia \
        -d \
        --name $CONTAINER_NAME \
        --network host \
        --restart always \
        --volume /var/run/dbus:/var/run/dbus \
        --volume /home/emboard/jetson-containers/data:/data \
        --device /dev/snd \
        --device /dev/bus/usb \
        --device /dev/ttyTHS0 \
        -e DISPLAY=:0 \
        -v /tmp/.X11-unix:/tmp/.X11-unix \
        --device /dev/video0 \
        --device /dev/video1"
    
    # 如果jtop.sock存在，则添加挂载
    if [ -n "$JTOP_SOCK" ] && [ -S "$JTOP_SOCK" ]; then
        DOCKER_CMD="$DOCKER_CMD -v $JTOP_SOCK:$JTOP_SOCK"
        echo "✅ 将挂载jtop.sock: $JTOP_SOCK"
    else
        echo "⚠️ 跳过jtop.sock挂载"
    fi
    
    # 添加镜像和命令
    DOCKER_CMD="$DOCKER_CMD $IMAGE_NAME sleep infinity"
    
    # 执行docker run命令
    echo "执行容器创建命令..."
    eval $DOCKER_CMD
    
    if [ $? -eq 0 ]; then
        echo "容器创建并启动成功"
        sleep 3
    else
        echo "错误: 容器创建失败"
        exit 1
    fi
fi

# 等待容器完全启动
echo "等待容器启动完成..."
sleep 5

# 检查容器状态
if docker ps --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
    echo "✅ 容器启动成功！"
    echo ""
    echo "容器信息:"
    docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}"
    
    echo ""
    echo "容器日志:"
    docker logs --tail 10 $CONTAINER_NAME
    
    echo ""
    echo "现在你可以："
    echo "1. 使用桌面图标启动AIOT程序"
    echo "2. 或者手动执行: docker exec -it $CONTAINER_NAME /bin/bash"
    echo "3. 查看容器状态: docker ps | grep $CONTAINER_NAME"
    echo "4. 查看容器日志: docker logs -f $CONTAINER_NAME"
else
    echo "❌ 容器启动失败"
    echo "容器日志:"
    docker logs $CONTAINER_NAME
    exit 1
fi 
