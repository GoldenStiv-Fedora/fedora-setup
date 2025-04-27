#!/bin/bash

#####################################################################
#   УЛЬТИМАТИВНЫЙ АВТОМАТИЧЕСКИЙ СКРИПТ НАСТРОЙКИ FEDORA ДЛЯ НОУТБУКА #
#             Полная автоматизация, оптимизация и автообновление    #
# Версия: 7.1                                                       #
# Требуется: root-доступ                                            #
#####################################################################

# --------------------------
# 🔄 Самообновление скрипта
# --------------------------
SCRIPT_URL="https://raw.githubusercontent.com/GoldenStiv-Fedora/fedora-setup/main/custom_laptop_setup.sh"
LOCAL_SCRIPT="/root/custom_laptop_setup.sh"
TMP_SCRIPT="/tmp/custom_laptop_setup_latest.sh"

if curl -s --output "$TMP_SCRIPT" --fail "$SCRIPT_URL"; then
    if ! cmp -s "$LOCAL_SCRIPT" "$TMP_SCRIPT"; then
        echo "🆕 Найдена новая версия скрипта! Обновление..."
        cp "$TMP_SCRIPT" "$LOCAL_SCRIPT"
        chmod +x "$LOCAL_SCRIPT"
        notify-send "Обновление скрипта" "Скрипт был обновлен. Перезапуск..."
        exec "$LOCAL_SCRIPT"
        exit 0
    else
        echo "✅ Скрипт актуален."
        rm -f "$TMP_SCRIPT"
    fi
else
    echo "⚠️ Не удалось проверить обновление скрипта. Продолжаем с текущей версией."
fi

# --------------------------
# 📅 Автонапоминание об обновлении скрипта раз в неделю
# --------------------------
(crontab -l 2>/dev/null; echo "0 12 * * 1 DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus notify-send 'Напоминание' 'Проверьте обновление скрипта Fedora Setup!'") | crontab -u $(whoami) -

# --------------------------
# 🛡️ Проверка root-доступа
# --------------------------
if [[ $EUID -ne 0 ]]; then
    echo "⛔ Требуются права root!"
    exit 1
fi

FEDORA_VERSION=$(rpm -E %fedora)
echo "📋 Обнаружена Fedora версии: $FEDORA_VERSION"

# --------------------------
# 📦 Установка необходимых пакетов
# --------------------------
echo "📦 Установка пакетов для оптимизации и мониторинга..."
dnf install -y powertop tuned thermald lm_sensors irqbalance nvme-cli smartmontools audit fprintd pipewire pipewire-pulseaudio pipewire-alsa wireplumber dnf-automatic libnotify cronie || {
    echo "⚠️ Ошибка установки базовых пакетов!";
}

# --------------------------
# 🔥 Оптимизация температуры CPU и NVMe-диска
# --------------------------
echo "🔥 Настройка контроля температуры и энергопотребления..."
systemctl enable --now thermald.service irqbalance.service tuned.service || echo "⚠️ Проблема с включением термалд или irqbalance"
tuned-adm profile powersave || echo "⚠️ Не удалось установить профиль powersave"

# --------------------------
# 🚀 Ускорение работы DNF
# --------------------------
echo "🚀 Ускорение работы DNF..."
sed -i 's/^#fastestmirror=1/fastestmirror=1/' /etc/dnf/dnf.conf
sed -i 's/^#max_parallel_downloads=.*/max_parallel_downloads=10/' /etc/dnf/dnf.conf
sed -i 's/^#deltarpm=1/deltarpm=true/' /etc/dnf/dnf.conf

# --------------------------
# 🔒 Настройка отпечатка пальца
# --------------------------
echo "🔒 Настройка отпечатка пальца..."
if fprintd-list $(whoami); then
    echo "✅ Отпечаток уже зарегистрирован."
else
    echo "⚠️ Нет зарегистрированных отпечатков. Запустите: fprintd-enroll для регистрации."
fi

# --------------------------
# 🎵 Настройка PipeWire для звука
# --------------------------
echo "🎵 Перезапуск PipeWire для корректной работы звука..."
systemctl --user enable --now pipewire.service pipewire-pulse.service || echo "⚠️ Не удалось включить PipeWire"

# --------------------------
# 📈 Настройка автообновления системы
# --------------------------
echo "📈 Настройка автоматического обновления системы..."
systemctl enable --now dnf-automatic.timer

cat <<EOF > /etc/dnf/automatic.conf
[commands]
upgrade_type = default
download_updates = yes
apply_updates = yes
[emitters]
emit_via = motd
emit_via = notify
EOF

# --------------------------
# 📡 Оптимизация сетевых параметров
# --------------------------
echo "📡 Оптимизация TCP-соединений..."
cat <<EOF > /etc/sysctl.d/99-network-tuning.conf
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
EOF
sysctl --system || echo "⚠️ Ошибка применения сетевых настроек"

# --------------------------
# 🔍 Включение мониторинга состояния дисков
# --------------------------
echo "🔍 Включение SMART-мониторинга дисков..."
systemctl enable --now smartd.service || echo "⚠️ Не удалось включить smartd"

# --------------------------
# 🔋 Автоопределение режима работы батареи
# --------------------------
echo "🔋 Настройка автоматического профиля энергосбережения..."
cat <<'EOF' > /etc/cron.hourly/battery-profile-switcher
#!/bin/bash
battery_status=$(cat /sys/class/power_supply/BAT*/status)
if [[ "$battery_status" == "Discharging" ]]; then
  tuned-adm profile powersave
  notify-send "Режим батареи" "Активирован энергосберегающий профиль."
else
  tuned-adm profile balanced
  notify-send "Режим питания" "Активирован сбалансированный профиль."
fi
EOF
chmod +x /etc/cron.hourly/battery-profile-switcher

# --------------------------
# 🛡️ Еженедельная самопроверка системы
# --------------------------
echo "🛡️ Настройка еженедельной самопроверки системы..."
cat <<'EOF' > /etc/cron.weekly/system-health-check
#!/bin/bash
smartctl -H /dev/nvme0 || true
sensors || true
notify-send "Еженедельная проверка" "Температуры и состояние диска проверены."
EOF
chmod +x /etc/cron.weekly/system-health-check

# --------------------------
# 🧹 Очистка старых логов диагностики
# --------------------------
echo "🧹 Очистка ненужных файлов..."
rm -rf /home/fedora-log-ultimate || echo "⚠️ Не удалось удалить старые логи"

# --------------------------
# 🏁 Финализация
# --------------------------
echo "✅ Все оптимизации применены! Пожалуйста, перезагрузите ноутбук для полной активации настроек."
notify-send "Fedora оптимизирована" "Настройка завершена. Перезагрузите систему."

