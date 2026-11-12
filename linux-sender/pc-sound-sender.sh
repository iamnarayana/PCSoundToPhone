#!/usr/bin/env bash
#
# PCSound SENDER (Linux)
# Отправляет системный звук компьютера на телефон по UDP.
#
# Формат потока: s16le, стерео, 48000 Гц — сразу понимается Android AudioTrack.
#
# Использование:
#   ./pc-sound-sender.sh <IP-телефона> [порт]
#   Переменные окружения: PCSOUND_PHONE_IP, PCSOUND_PORT (по умолчанию 9999)

set -u

PORT="${PCSOUND_PORT:-9999}"
PHONE_IP="${1:-${PCSOUND_PHONE_IP:-}}"

if [[ -z "$PHONE_IP" ]]; then
    echo "Использование: $0 <IP-телефона> [порт]"
    echo "Пример:   $0 192.168.1.42 9999"
    echo
    echo "IP телефона: Настройки → Wi-Fi → подключённая сеть."
    exit 1
fi

# Устройство по умолчанию и его «монитор» (то, что играет в колонках)
DEFAULT_SINK="$(pactl get-default-sink 2>/dev/null || true)"
MONITOR="${PCSOUND_MONITOR:-${DEFAULT_SINK}.monitor}"

if ! pactl list sources short 2>/dev/null | grep -Fq "$MONITOR"; then
    echo "Ошибка: источник звука '$MONITOR' не найден."
    echo "Доступные источники:"
    pactl list sources short 2>/dev/null
    exit 1
fi

echo "================================================"
echo "  PCSound SENDER (Linux)"
echo "  Источник : $MONITOR"
echo "  Формат   : s16le, 2ch, 48000 Гц"
echo "  Куда     : udp://$PHONE_IP:$PORT"
echo "  Стоп     : Ctrl+C"
echo "================================================"
echo

# Захват звука монитора -> сырой PCM -> в сеть UDP
# --latency-msec=20 — маленький буфер на стороне компа (меньше задержка)
parec -d "$MONITOR" --format=s16le --rate=48000 --channels=2 --latency-msec=5 \
    | socat - UDP-DATAGRAM:"$PHONE_IP":"$PORT"
