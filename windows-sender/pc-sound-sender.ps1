#requires -Version 5.1
#
# PCSound SENDER (Windows)
# Отправляет системный звук компьютера на телефон по UDP.
#
# Требования:
#   - ffmpeg (должен быть в PATH или указано полное имя исполняемого файла)
#   - Права на запись в сеть (обычно есть по умолчанию)
#
# Использование:
#   .\pc-sound-sender.ps1 <IP-телефона> [порт]
#   Пример:   .\pc-sound-sender.ps1 192.168.1.42 9999
#
# Формат потока: s16le, стерео, 48000 Гц — сразу понимается Android AudioTrack.
#

param(
    [Parameter(Mandatory = $true)]
    [string]$PhoneIp,

    [Parameter(Mandatory = $false)]
    [int]$Port = 9999
)

$ErrorActionPreference = 'Stop'

# Проверяем наличие ffmpeg
$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if (-not $ffmpeg) {
    Write-Error "ffmpeg не найден в PATH. Установите ffmpeg (https://ffmpeg.org/download.html) и добавьте в PATH."
    exit 1
}

# Конечная точка UDP
$endPoint = New-Object System.Net.IPEndPoint(
    [System.Net.IPAddress]::Parse($PhoneIp),
    $Port
)
$udpClient = New-Object System.Net.Sockets.UdpClient

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  PCSound SENDER (Windows)" -ForegroundColor Cyan
Write-Host "  Источник : WASAPI loopback (системный звук)" -ForegroundColor Cyan
Write-Host "  Формат   : s16le, 2ch, 48000 Гц" -ForegroundColor Cyan
Write-Host "  Куда     : udp://$PhoneIp:$Port" -ForegroundColor Cyan
Write-Host "  Стоп     : Ctrl+C" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Запускаем ffmpeg: захватывает системный звук через WASAPI loopback
    # и отдаёт сырой PCM (s16le, 2ch, 48000 Гц) в stdout
    $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processStartInfo.FileName = "ffmpeg"
    $processStartInfo.Arguments = "-f wasapi -i loopback -f s16le -ar 48000 -ac 2 -"
    $processStartInfo.UseShellExecute = $false
    $processStartInfo.RedirectStandardOutput = $true
    $processStartInfo.RedirectStandardError = $true
    $processStartInfo.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::Start($processStartInfo)

    # Читаем бинарные данные из stdout ffmpeg и отправляем по UDP
    $stdout = $process.StandardOutput.BaseStream
    $reader = New-Object System.IO.BinaryReader($stdout)
    $buffer = New-Object byte[] 4096

    while ($true) {
        $read = $reader.Read($buffer, 0, $buffer.Length)
        if ($read -le 0) { break }
        $udpClient.Send($buffer, $read, $endPoint)
    }
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
finally {
    try { $udpClient.Close() } catch {}
    try { $process.Dispose() } catch {}
}
