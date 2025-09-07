# Emboard AIOT 安装脚本

这是一个用于在Jetson设备上安装和配置AIOT（人工智能物联网）系统的自动化脚本集合。

## 📋 项目概述

本项目提供了完整的AIOT系统安装和配置解决方案，包括：
- Docker容器管理
- 系统服务配置
- 桌面应用程序启动器
- 图形用户界面支持

## 🚀 功能特性

- **自动化安装**: 一键安装Docker桌面图标和系统服务
- **多应用支持**: 支持AICV实验演示、AIOT手势控制、AIOT控制系统
- **系统服务**: 开机自启动Docker容器
- **图形界面**: 提供桌面启动器和状态栏图标
- **容器管理**: 自动启动、停止和管理Docker容器

## 📁 文件结构

```
emboard_install_sh/
├── README.md                           # 项目说明文档
├── install_docker_desktop.sh          # Docker桌面图标安装脚本
├── install_docker_service.sh          # Docker系统服务安装脚本
├── start_container.sh                 # 容器启动脚本
├── stop_container.sh                  # 容器停止脚本
├── aiot-container.service             # 系统服务配置文件
├── AICV_base_GUI.desktop              # AICV实验演示桌面启动器
├── CVMP_AIOT.desktop                  # AIOT手势控制桌面启动器
├── Emlab_AIOT.desktop                 # AIOT控制系统桌面启动器
├── ico.png                            # 主图标文件
├── logo.png                           # 项目Logo
├── status_logo_aicv.png               # AICV状态栏图标
├── status_logo_aiot.png               # AIOT状态栏图标
└── status_logo_cvmp.png               # CVMP状态栏图标
```

## 🛠️ 安装要求

### 系统要求
- **操作系统**: Ubuntu 18.04+ (推荐Ubuntu 20.04+)
- **硬件平台**: NVIDIA Jetson设备 (Jetson Nano/AGX Xavier/Orin等)
- **Docker**: 已安装并配置Docker Engine
- **NVIDIA Container Toolkit**: 支持GPU加速的Docker运行时

### 依赖软件
- Docker Engine
- NVIDIA Container Toolkit
- systemd (系统服务管理)
- X11 (图形界面支持)

## 📦 安装步骤

### 1. 克隆仓库
```bash
git clone https://github.com/Embosen/emboard_install_sh.git
cd emboard_install_sh
```

### 2. 安装Docker桌面图标
```bash
chmod +x install_docker_desktop.sh
./install_docker_desktop.sh
```

### 3. 安装系统服务 (可选)
```bash
chmod +x install_docker_service.sh
sudo ./install_docker_service.sh
```

## 🎯 使用方法

### 启动AIOT容器
```bash
# 手动启动
./start_container.sh

# 或使用系统服务
sudo systemctl start aiot-container.service
```

### 停止AIOT容器
```bash
# 手动停止
./stop_container.sh

# 或使用系统服务
sudo systemctl stop aiot-container.service
```

### 桌面应用程序
安装完成后，您可以通过以下方式启动应用程序：

1. **应用程序菜单**: 在系统应用程序菜单中找到对应应用
2. **桌面图标**: 双击桌面上的应用图标
3. **命令行**: 使用Docker exec命令进入容器

## 🔧 配置说明

### Docker容器配置
- **容器名称**: `emboard_aiot`
- **镜像名称**: `emboard/mediapipe-gpu-aiot:r35.4.1`
- **GPU支持**: 启用NVIDIA GPU加速
- **网络模式**: Host网络模式
- **设备访问**: 支持摄像头、音频、USB设备

### 系统服务配置
- **服务名称**: `aiot-container.service`
- **开机自启**: 自动启用
- **依赖服务**: Docker服务
- **超时设置**: 启动60秒，停止30秒

## 📱 支持的应用程序

### 1. AICV实验演示
- **功能**: 计算机视觉实验演示
- **启动器**: `AICV_base_GUI.desktop`
- **状态图标**: `status_logo_aicv.png`

### 2. AIOT手势控制
- **功能**: 基于手势的智能控制
- **启动器**: `CVMP_AIOT.desktop`
- **状态图标**: `status_logo_cvmp.png`

### 3. AIOT控制系统
- **功能**: 综合AIOT控制平台
- **启动器**: `Emlab_AIOT.desktop`
- **状态图标**: `status_logo_aiot.png`

## 🔍 故障排除

### 常见问题

#### 1. Docker服务未运行
```bash
# 检查Docker状态
sudo systemctl status docker

# 启动Docker服务
sudo systemctl start docker
```

#### 2. 容器启动失败
```bash
# 查看容器日志
docker logs emboard_aiot

# 检查镜像是否存在
docker images | grep emboard
```

#### 3. 图形界面无法显示
```bash
# 设置X11权限
xhost +local:docker

# 检查DISPLAY环境变量
echo $DISPLAY
```

#### 4. 系统服务问题
```bash
# 查看服务状态
sudo systemctl status aiot-container.service

# 查看服务日志
sudo journalctl -u aiot-container.service -f
```

## 🛡️ 安全注意事项

- 脚本需要sudo权限来安装系统服务
- Docker容器以特权模式运行，请确保镜像来源可信
- X11权限设置可能影响系统安全，仅在受信任环境中使用

## 📝 开发说明

### 自定义配置
如需修改容器配置，请编辑 `start_container.sh` 文件中的相关参数：
- 容器名称
- 镜像名称
- 端口映射
- 设备挂载

### 添加新应用
1. 创建新的桌面启动器文件 (`.desktop`)
2. 添加对应的状态图标文件 (`.png`)
3. 更新 `install_docker_desktop.sh` 中的配置数组

## 📄 许可证

本项目采用 MIT 许可证。详情请参阅 [LICENSE](LICENSE) 文件。

## 🤝 贡献

欢迎提交Issue和Pull Request来改进这个项目。

## 📞 支持

如果您遇到问题或有任何建议，请：
1. 查看 [Issues](https://github.com/Embosen/emboard_install_sh/issues)
2. 创建新的Issue
3. 联系维护者

## 🔄 更新日志

### v1.0.0 (2024-09-07)
- 初始版本发布
- 支持AICV、AIOT、CVMP三个应用程序
- 完整的Docker容器管理功能
- 系统服务自动启动支持
- 桌面启动器安装功能

---

**注意**: 请确保在运行脚本前已正确安装Docker和NVIDIA Container Toolkit。
