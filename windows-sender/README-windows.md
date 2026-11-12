# PCSound Sender — Windows

## Быстрый старт

1. Установите **ffmpeg** и добавьте в PATH:
   - Скачайте с https://ffmpeg.org/download.html
   - Или через chocolatey: `choco install ffmpeg`
   - Или через winget: `winget install ffmpeg`

2. Узнайте IP телефона (Настройки → Wi-Fi → сеть).

3. Запустите в PowerShell:
   ```powershell
   cd \путь\к\PCSoundToPhone\windows-sender
   .\pc-sound-sender.ps1 192.168.1.42 9999
   ```

4. На телефоне запустите приложение **PCSound Receiver**, нажмите **«Старт»**.

## Параметры

| Параметр | Описание | Пример |
|----------|----------|--------|
| IP-телефона | IP адрес телефона в вашей Wi-Fi | `192.168.1.42` |
| Порт | Порт UDP (по умолчанию 9999) | `9999` |

## Остановка

Нажмите `Ctrl+C` в окне PowerShell.

## Примечание

Скрипт захватывает системный звук через **WASAPI loopback** — то, что вы слышите в динамиках/наушниках компьютера.
