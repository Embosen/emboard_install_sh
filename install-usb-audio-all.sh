#!/bin/bash
# install-usb-audio.sh
# 合并版：一键安装 systemd 服务。运行时自动识别
#  - GeneralPlus_USB_Audio_Device -> IEC958(光纤)输出 + 多声道输入
#  - 2K_USB_Camera                -> 多声道输出 + 多声道输入

set -euo pipefail

USER_NAME=$(whoami)
USER_ID=$(id -u "$USER_NAME")

SCRIPT_PATH="/usr/local/bin/set-usb-audio.sh"
SERVICE_PATH="/etc/systemd/system/set-usb-audio.service"

echo ">>> 创建脚本 $SCRIPT_PATH ..."
sudo tee "$SCRIPT_PATH" > /dev/null <<'EOS'
#!/bin/bash
set -euo pipefail

# === 运行环境（pactl 依赖）===
USER_NAME=${USER_NAME:-$(whoami)}
USER_ID=${USER_ID:-$(id -u "$USER_NAME")}
export XDG_RUNTIME_DIR="/run/user/${USER_ID}"

# === 设备定义（先定义，后使用）===

# GeneralPlus
GP_CARD_NAME="alsa_card.usb-GeneralPlus_USB_Audio_Device-00"
GP_CARD_PROFILE="output:iec958-stereo+input:multichannel-input"
GP_SINK_RE='^alsa_output\.usb-GeneralPlus_USB_Audio_Device-00\.iec958-stereo$'
GP_SRC_RE='^alsa_input\.usb-GeneralPlus_USB_Audio_Device-00\.multichannel-input$'
GP_SINK_FALLBACK_RE='^alsa_output\.usb-.*\.iec958-stereo$'
GP_SRC_FALLBACK_RE='^alsa_input\.usb-.*\.multichannel-input$'
# 通用的 “GeneralPlus 声卡”正则（用于探测）
GP_CARD_RE='alsa_card\.usb-.*USB_Audio_Device-00'

# 2K USB Camera
CAM_CARD_RE='alsa_card\.usb-.*2K_USB_Camera.*'
CAM_CARD_PROFILE="output:multichannel-output+input:multichannel-input"
CAM_SINK_RE='^alsa_output\.usb-.*2K_USB_Camera.*\.multichannel-output$'
CAM_SRC_RE='^alsa_input\.usb-.*2K_USB_Camera.*\.multichannel-input$'
CAM_SINK_FALLBACK_RE='^alsa_output\.usb-.*\.multichannel-output$'
CAM_SRC_FALLBACK_RE='^alsa_input\.usb-.*\.multichannel-input$'

# === 通用函数 ===
have_card() { pactl list short cards | awk '{print $2}' | grep -qx "$1"; }
find_card_regex() { pactl list short cards | awk '{print $2}' | grep -E "$1" | head -n1 || true; }

wait_pulse() {
  for i in {1..240}; do # 最长约2分钟，冷启动/重建节点时更稳
    pactl info >/dev/null 2>&1 && return 0
    sleep 0.5
  done
  echo "WARN: pactl 无法连接到 pulse/pipewire-pulse" >&2
  return 1
}

wait_card_regex() {
  local re="$1"
  for i in {1..240}; do
    pactl list short cards | awk '{print $2}' | grep -Eq "$re" && return 0
    sleep 0.5
  done
  return 1
}

wait_nodes() {
  local sink_re="$1" src_re="$2" tries="${3:-240}"
  local sinks srcs
  for ((i=0;i<tries;i++)); do
    sinks=$(pactl list short sinks   | awk '{print $2}')
    srcs=$(pactl list short sources  | awk '{print $2}')
    if echo "$sinks" | grep -Eq "$sink_re" \
    && echo "$srcs" | grep -Eq "$src_re"; then
      return 0
    fi
    sleep 0.5
  done
  return 1
}

set_defaults_and_move() {
  local sink="$1" src="$2"
  [ -n "${sink:-}" ] && pactl set-default-sink   "$sink" || true
  [ -n "${src:-}"  ] && pactl set-default-source "$src"  || true
  pactl list short sink-inputs    | awk '{print $1}' | xargs -r -I{} pactl move-sink-input {}    "$sink" || true
  pactl list short source-outputs | awk '{print $1}' | xargs -r -I{} pactl move-source-output {} "$src"  || true
  echo "OK: Default Sink   -> $sink"
  echo "OK: Default Source -> $src"
}

# === 开始 ===
# 等到 pulse/pipewire-pulse 可用
wait_pulse || exit 0

# 可选：如果真在跑 pulseaudio 再 kill（PipeWire 环境通常无需）
if command -v pulseaudio >/dev/null 2>&1 && pactl info >/dev/null 2>&1; then
  pulseaudio -k || true
  sleep 2
  wait_pulse || true
fi

# 设备检测（若同时存在，优先 GeneralPlus）
MODE=""
for i in {1..120}; do
  if have_card "$GP_CARD_NAME" \
     || pactl list short cards | awk '{print $2}' | grep -Eq "$GP_CARD_RE" \
     || pactl list short sinks | awk '{print $2}' | grep -q 'usb-GeneralPlus_USB_Audio_Device'; then
    MODE="generalplus"; break
  fi
  if pactl list short cards | awk '{print $2}' | grep -Eq "$CAM_CARD_RE" \
     || pactl list short sinks | awk '{print $2}' | grep -q '2K_USB_Camera'; then
    MODE="camera"; break
  fi
  sleep 0.5
done

if [ -z "$MODE" ]; then
  echo "WARN: 未检测到 GeneralPlus 或 2K_USB_Camera，跳过设置。"
  exit 0
fi

echo ">>> 检测到设备类型：$MODE"

if [ "$MODE" = "generalplus" ]; then
  # 切换 GeneralPlus 档位（IEC958 输出 + 多声道输入）
  if have_card "$GP_CARD_NAME"; then
    pactl set-card-profile "$GP_CARD_NAME" "$GP_CARD_PROFILE" || true
  else
    CARD_FALLBACK=$(find_card_regex "$GP_CARD_RE")
    [ -n "${CARD_FALLBACK:-}" ] && pactl set-card-profile "$CARD_FALLBACK" "$GP_CARD_PROFILE" || true
  fi

  # 等设备并设置默认（带兜底）
  if ! wait_nodes "$GP_SINK_RE" "$GP_SRC_RE" 240; then
    TARGET_SINK=$(pactl list short sinks   | awk '{print $2}' | grep -E "$GP_SINK_FALLBACK_RE" | head -n1 || true)
    TARGET_SRC=$(pactl list short sources  | awk '{print $2}' | grep -E "$GP_SRC_FALLBACK_RE" | head -n1 || true)
  else
    TARGET_SINK=$(pactl list short sinks   | awk '{print $2}' | grep -E "$GP_SINK_RE" | head -n1 || true)
    TARGET_SRC=$(pactl list short sources  | awk '{print $2}' | grep -E "$GP_SRC_RE" | head -n1 || true)
  fi

  if [ -z "${TARGET_SINK:-}" ] || [ -z "${TARGET_SRC:-}" ]; then
    echo "WARN: 未找到 GeneralPlus 目标 sink/source，跳过。"
    exit 0
  fi
  set_defaults_and_move "$TARGET_SINK" "$TARGET_SRC"

else
  # 2K_USB_Camera：先等卡出现再切档
  wait_card_regex "$CAM_CARD_RE" || { echo "WARN: 相机声卡未就绪"; exit 0; }
  CAM_CARD=$(find_card_regex "$CAM_CARD_RE")
  if [ -z "${CAM_CARD:-}" ]; then
    # 兜底：取第一个 USB 声卡
    CAM_CARD=$(pactl list short cards | awk '$2 ~ /alsa_card\.usb-/ {print $2}' | head -n1 || true)
  fi
  if [ -n "${CAM_CARD:-}" ]; then
    pactl set-card-profile "$CAM_CARD" "$CAM_CARD_PROFILE" || true
  fi

  # 等设备并设置默认（带兜底）
  if ! wait_nodes "$CAM_SINK_RE" "$CAM_SRC_RE" 240; then
    TARGET_SINK=$(pactl list short sinks   | awk '{print $2}' | grep -E "$CAM_SINK_FALLBACK_RE" | head -n1 || true)
    TARGET_SRC=$(pactl list short sources  | awk '{print $2}' | grep -E "$CAM_SRC_FALLBACK_RE" | head -n1 || true)
  else
    TARGET_SINK=$(pactl list short sinks   | awk '{print $2}' | grep -E "$CAM_SINK_RE" | head -n1 || true)
    TARGET_SRC=$(pactl list short sources  | awk '{print $2}' | grep -E "$CAM_SRC_RE"  | head -n1 || true)
  fi

  if [ -z "${TARGET_SINK:-}" ] || [ -z "${TARGET_SRC:-}" ]; then
    echo "WARN: 未找到 USB 摄像头音频 sink/source，跳过。"
    exit 0
  fi
  set_defaults_and_move "$TARGET_SINK" "$TARGET_SRC"
fi

exit 0
EOS
sudo chmod +x "$SCRIPT_PATH"

echo ">>> 创建 systemd 服务 $SERVICE_PATH ..."
sudo tee "$SERVICE_PATH" > /dev/null <<EOF
[Unit]
Description=Force USB Audio as Default (GeneralPlus IEC958 / 2K USB Camera multichannel)
Wants=sound.target pipewire-pulse.service pulseaudio.service user@${USER_ID}.service
After=sound.target pipewire-pulse.service pulseaudio.service user@${USER_ID}.service

[Service]
Type=oneshot
User=$USER_NAME
Environment=XDG_RUNTIME_DIR=/run/user/$USER_ID
# 等待 udev 设备就绪再执行（冷启动更稳）
ExecStartPre=/usr/bin/udevadm settle -t 10
# 给管线再一点点时间
ExecStartPre=/bin/sleep 3
ExecStart=$SCRIPT_PATH
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

echo ">>> 启用并启动服务 ..."
sudo systemctl daemon-reload
sudo systemctl enable set-usb-audio.service
sudo systemctl start set-usb-audio.service

echo ">>> 完成！系统将自动识别 GeneralPlus 或 2K_USB_Camera 并设置为默认音频设备（开机生效）。"
echo ">>> 若需要无人登录即生效，建议：sudo loginctl enable-linger $USER_NAME"

