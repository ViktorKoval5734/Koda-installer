#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.npm-global/bin:$PATH"

show_step() {
    local percent=$1
    local msg=$2

    local width=100
    local filled=$percent
    local empty=$((width - filled))

    # Генерируем строку заполненной части (█)
    local filled_bar=""
    for ((i=0; i<filled; i++)); do
        filled_bar+="█"
    done

    # Генерируем строку пустой части (▒)
    local empty_bar=""
    for ((i=0; i<empty; i++)); do
        empty_bar+="▒"
    done

    local bar="${filled_bar}${empty_bar}"

    # Очищаем предыдущую строку сообщения (поднимаемся на 1 строку вверх) и пишем новое сообщение + бар
    printf "\r\x1b[2K\x1b[A\x1b[2K%s\n[%s] %3d%%" "$msg" "$bar" "$percent"
}

echo "=== Установка Koda CLI + ярлык ==="
echo ""
printf "⏱️  ⚠️  ВНИМАНИЕ: Процесс установки может занять до 15 минут\n"
printf "   Пожалуйста, не закрывайте терминал во время установки\n"
sleep 1

IS_STEAMOS=false
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "${ID:-}" = "steamos" ] || grep -qi "SteamOS" /etc/os-release; then
        IS_STEAMOS=true
    fi
fi

sleep 0.2

DEVICE_NAME="unknown"
if [ -f /sys/devices/virtual/dmi/id/product_name ]; then
    DEVICE_NAME=$(cat /sys/devices/virtual/dmi/id/product_name)
elif [ -f /sys/class/dmi/id/product_name ]; then
    DEVICE_NAME=$(cat /sys/class/dmi/id/product_name)
fi

echo "🔐 Запрашиваю права sudo для установки зависимостей..."
echo "   Введите пароль пользователя для продолжения установки..."
# Запрос пароля sudo и кэширование сессии на всю сессию входа
sudo -v || { echo "❌ Ошибка: требуется пароль sudo для продолжения установки"; exit 1; }

# Запускаем фоновый процесс для поддержания актуальности кэша sudo
(while true; do sudo -v; sleep 600; done) &
SUDO_KEEPALIVE_PID=$!

# Останавливаем фоновый процесс при завершении скрипта
trap "kill $SUDO_KEEPALIVE_PID 2>/dev/null || true" EXIT

# Сбрасываем кэш sudo для чистого запроса
sudo -k
# Запрашиваем пароль ещё раз для явного подтверждения
sudo -v || { echo "❌ Ошибка: требуется пароль sudo для продолжения установки"; exit 1; }

if [ "$IS_STEAMOS" = true ]; then
    sudo steamos-readonly disable >/dev/null 2>&1 || true
fi

show_step 5 "🔑 Настройка pacman ключей..."
if [ ! -d /etc/pacman.d/gnupg ] || [ -z "$(ls -A /etc/pacman.d/gnupg 2>/dev/null)" ]; then
    sudo pacman-key --init >/dev/null 2>&1 || true
    sudo pacman-key --populate archlinux >/dev/null 2>&1 || true
    if [ "$IS_STEAMOS" = true ]; then
        sudo pacman-key --populate holo >/dev/null 2>&1 || true
    fi
fi

show_step 10 "📦 Проверка зависимостей..."

if ! pacman -Qi nodejs &>/dev/null; then
    sudo pacman -S --noconfirm nodejs >/dev/null 2>&1 || true
fi
if ! pacman -Qi npm &>/dev/null; then
    sudo pacman -S --noconfirm npm >/dev/null 2>&1 || true
fi
if ! pacman -Qi git &>/dev/null; then
    sudo pacman -S --noconfirm git >/dev/null 2>&1 || true
fi
if ! pacman -Qi base-devel &>/dev/null; then
    sudo pacman -S --noconfirm base-devel >/dev/null 2>&1 || true
fi
if ! pacman -Qi qrencode &>/dev/null; then
    sudo pacman -S --noconfirm qrencode >/dev/null 2>&1 || true
fi
show_step 20 "✅ Зависимости проверены"

show_step 25 "🔍 Проверка Node.js версии..."
NODE_MAJOR=$(node -e "console.log(process.versions.node.split('.')[0])" 2>/dev/null || echo "0")
if [ "${NODE_MAJOR:-0}" -ge 20 ]; then
    show_step 30 "✅ Node.js $NODE_MAJOR.x подходит"
else
    sudo pacman -S --noconfirm nodejs npm >/dev/null 2>&1 || true
    show_step 30 "✅ Node.js обновлён"
fi

show_step 35 "🌍 Настройка npm директории..."
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global" 2>/dev/null || true
show_step 40 "✅ npm настроен"

show_step 45 "📝 Добавление PATH в rc-файлы..."
ensure_path_bash() {
    local rc="$1"
    touch "$rc" 2>/dev/null || true
    if ! grep -Fq 'export PATH="$HOME/.npm-global/bin:$PATH"' "$rc"; then
        printf '\nexport PATH="$HOME/.npm-global/bin:$PATH"\n' >> "$rc"
    fi
}
ensure_path_fish() {
    mkdir -p "$HOME/.config/fish" 2>/dev/null || true
    local cfg="$HOME/.config/fish/config.fish"
    touch "$cfg" 2>/dev/null || true
    if ! grep -Fq '$HOME/.npm-global/bin' "$cfg"; then
        printf '\nfish_add_path "$HOME/.npm-global/bin"\n' >> "$cfg"
    fi
}
ensure_path_zsh() {
    local rc="$1"
    touch "$rc" 2>/dev/null || true
    if ! grep -Fq 'export PATH="$HOME/.npm-global/bin:$PATH"' "$rc"; then
        printf '\nexport PATH="$HOME/.npm-global/bin:$PATH"\n' >> "$rc"
    fi
}
ensure_path_bash "$HOME/.bashrc"
ensure_path_bash "$HOME/.bash_profile"
ensure_path_zsh "$HOME/.zshrc"
ensure_path_fish

export PATH="$HOME/.npm-global/bin:$PATH"

show_step 55 "🚀 Установка Koda CLI..."
npm install -g @kodadev/koda-cli@latest >/dev/null 2>&1 || npm install -g @kodadev/koda-cli@latest

if ! command -v koda &>/dev/null; then
    if [ -x "$HOME/.npm-global/bin/koda" ]; then
        show_step 65 "✅ koda установлен"
    else
        show_step 65 "❌ Koda CLI не установился"
        exit 1
    fi
else
    show_step 65 "✅ Koda CLI установлен"
fi

DESKTOP_DIR="$HOME/Desktop"
if [ ! -d "$DESKTOP_DIR" ]; then
    DESKTOP_DIR="$HOME/Рабочий стол"
fi
mkdir -p "$DESKTOP_DIR" 2>/dev/null || true
KODA_DESKTOP="$DESKTOP_DIR/Konsole Koda.desktop"
cat > "$KODA_DESKTOP" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Konsole Koda
Comment=Запуск Koda CLI в Konsole
Icon=konsole
Exec=fish -lc 'fish_add_path "$HOME/.npm-global/bin"; konsole --noclose -e koda'
Terminal=false
Categories=Development;Utility;
StartupNotify=true
EOF
chmod +x "$KODA_DESKTOP" 2>/dev/null || true
xdg-desktop-icon activate "$KODA_DESKTOP" 2>/dev/null || true
show_step 75 "✅ Ярлык создан"

show_step 80 "📝 Создание контекста Koda..."
mkdir -p "$HOME/.kodacli" 2>/dev/null || true
cat > "$HOME/.kodacli/KODA.md" << 'EOF'
## Koda Added Memories

### Технические настройки
- ВСЕГДА И БЕЗ ИСКЛЮЧЕНИЙ при выполнении команд, требующих пароль sudo, выполнять команду через pkexec вместо sudo.
- Пояснять пользователю свои действия и кратко описывать что делают те или иные выполняемые в настоящий момент команды
EOF

cat > "$HOME/.kodacli/settings.json" << 'EOF'
{
  "selectedAuthType": "koda-auth",
  "hideTips": true,
  "model": "koda-base"
}
EOF
show_step 90 "✅ Контекст Koda создан"

if [ "$IS_STEAMOS" = true ]; then
    printf "\n⚠️ ВНИМАНИЕ: pacman-пакеты могут быть удалены при обновлении SteamOS.\n"
    printf "   Koda CLI сохранится в $HOME/.npm-global\n\n"
    REPLY="y"
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        sudo steamos-readonly enable >/dev/null 2>&1 || true
        printf "🔒 Read-only включен\n\n"
    else
        printf "🔓 Read-only отключен\n\n"
    fi
fi

show_step 100 "✅ Установка завершена"
clear
cat <<'EOF'
 █████   ████    ███████    ██████████     █████████
▒▒███   ███▒   ███▒▒▒▒▒███ ▒▒███▒▒▒▒███   ███▒▒▒▒▒███
 ▒███  ███    ███     ▒▒███ ▒███   ▒▒███ ▒███    ▒███
 ▒███████    ▒███      ▒███ ▒███    ▒███ ▒███████████
 ▒███▒▒███   ▒███      ▒███ ▒███    ▒███ ▒███▒▒▒▒▒███
 ▒███ ▒▒███  ▒▒███     ███  ▒███    ███  ▒███    ▒███
 █████ ▒▒████ ▒▒▒███████▒   ██████████   █████   █████
▒▒▒▒▒   ▒▒▒▒    ▒▒▒▒▒▒▒▒▒   ▒▒▒▒▒▒▒▒▒▒   ▒▒▒▒▒   ▒▒▒▒▒
EOF

printf "\n✅ Готово. Запускать можно командой: koda\n"
printf "✅ Для fish путь добавлен через fish_add_path в ~/.config/fish/config.fish\n"
printf "✅ Для bash/zsh путь добавлен в rc-файлы\n\n"

printf "📱 Генерация QR-кода...\n"
qrencode -t utf8 "https://finance.ozon.ru/apps/sbp/ozonbankpay/019c8fe5-19dd-77a3-80c4-bb3ed668c0b2" 2>/dev/null || printf "⚠️ qrencode не доступен\n"
printf "\n🙏 Пожалуйста поддержите автора по qr-коду выше\n"
