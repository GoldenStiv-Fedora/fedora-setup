#!/bin/bash
# 03_maintenance.sh — Еженедельная самопроверка системы Fedora Auto-Setup

CONFIG_FILE="/etc/fedora-setup.conf"
[ -f "$CONFIG_FILE" ] || { echo "❌ Конфиг не найден!"; exit 1; }
source "$CONFIG_FILE"

# Логирование
LOG_DIR="/var/log/fedora-auto-setup"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_DIR/maintenance-$(date +%F).log") 2>&1

echo "=== Старт еженедельной проверки ==="

# Шаг 1: Проверка доступности интернета
ping -c 3 8.8.8.8 &>/dev/null
if [[ $? -eq 0 ]]; then
    echo "✅ Интернет доступен"
else
    echo "❌ Нет подключения к интернету!"
    notify-send "Fedora Setup" "Внимание: Нет подключения к интернету!"
    exit 1
fi

# Шаг 2: Обновление системы
echo "🔄 Обновление системы..."
dnf upgrade -y

# Шаг 3: Самопроверка служб
echo "🔍 Проверка состояния службы auto-setup..."
systemctl is-active --quiet fedora-auto-setup.service && echo "✅ Служба активна" || echo "❌ Служба не активна"

# Шаг 4: Проверка свежести скриптов
echo "🔄 Проверка на обновления скриптов..."
bash /usr/local/bin/00_fetch_logs.sh
bash /usr/local/bin/01_analyze_and_prepare.sh
source /tmp/system_config_detected.conf

# Шаг 5: Самообновление (если нужно)
bash /usr/local/bin/02_full_auto_setup.sh --update-only

# Шаг 6: Отправка уведомления
notify-send "Fedora Setup" "✅ Еженедельная проверка завершена. Система в порядке."

echo "=== Самопроверка завершена успешно ==="
