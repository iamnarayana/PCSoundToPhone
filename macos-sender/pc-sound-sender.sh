#!/usr/bin/env bash
#
# PCSound SENDER (macOS)
# Отправляет системный звук компьютера на телефон по UDP.
#
# Требования:
#   - ffmpeg (установить: brew install ffmpeg)
#   - socat или nc (netcat) — для отправки по UDP
#
# ВАЖНО: macOS не позволяет напрямую捕�ить системный аудиовывод.
# Нужно установить виртуальное аудиоустройство (например, BlackHole),
# настроить выход системного звука в него, а затем читать с этого устройства.
#
# Использование:
#   ./pc-sound-sender.sh <IP-телефона> [порт]
#   Пример:   ./pc-sound-sender.sh 192.168.1.42 9999
#
# Формат потока: s16le, стерео, 48000 Гц — сразу понимается Android AudioTrack.
#

set -u

PORT="${PCSOUND_PORT:-9999}"
PHONE_IP="${1:-}"

if [[ -z "$PHONE_IP" ]]; then
    echo "Использование: $0 <IP-телефона> [порт]"
    echo "Пример:   $0 192.168.1.42 9999"
    echo
    echo "IP телефона: Настройки → Wi-Fi → подключённая сеть."
    exit 1
fi

# Проверка ffmpeg
if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Ошибка: ffmpeg не найден. Установите: brew install ffmpeg"
    exit 1
fi

# Проверка socat или nc
SEND_TOOL=""
if command -v socat >/dev/null 2>&1; then
    SEND_TOOL="socat"
elif command -v nc >/dev/null 2>&1; then
    SEND_TOOL="nc"
else
    echo "Ошибка: не найден ни socat, ни nc (netcat). Установите один из них: brew install socat"
    exit 1
fi

# Источник звука macOS (AVFoundation)
# По умолчанию :0 — устройство ввода по умолчанию (микрофон).
# Для системного звука настройте BlackHole и укажите его имя:
#   -f avfoundation -i "BlackHole 2ch"
AUDIO_SOURCE="${PCSOUND_AUDIO_SOURCE:-:0}"

echo "================================================"
echo "  PCSound SENDER (macOS)"
echo "  Источник : $AUDIO_SOURCE (AVFoundation)"
echo "  Формат   : s16le, 2ch, 48000 Гц"
echo "  Куда     : udp://$PHONE_IP:$PORT"
echo "  Инструмент отправки: $SEND_TOOL"
echo "  Стоп     : Ctrl+C"
echo "================================================"
echo

# Захват звука -> сырой PCM -> в сеть UDP
if [[ "$SEND_TOOL" == "socat" ]]; then
    ffmpeg -f avfoundation -i "$AUDIO_SOURCE" \
        -f s16le -ar 48000 -ac 2 - \
        | socat - UDP-DATAGRAM:"$PHONE_IP":"$PORT"
else
    # nc -u (UDP) — отправляет в фоновом режиме, ffmpeg пишет в stdin
    ffmpeg -f avfoundation -i "$AUDIO_SOURCE" \
        -f s16le -ar 48000 -ac 2 - \
        | nc -u "$PHONE_IP" "$PORT"
fi
