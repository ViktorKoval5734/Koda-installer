#!/bin/bash

# Старт установки
FORCE_RUN=1
export PATH="$HOME/.npm-global/bin:$PATH"

set -e

echo "=== Установка Koda CLI + ярлык ==="

# Определение ОС
IS_STEAMOS=false
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" = "steamos" ] || grep -q "SteamOS" /etc/os-release; then
        IS_STEAMOS=true
        echo "✅ Обнаружена SteamOS"
    else
        echo "✅ Обнаружена $NAME"
    fi
else
    echo "⚠️ Не удалось определить ОС"
fi

# Определение устройства
DEVICE_NAME="unknown"
if [ -f /sys/devices/virtual/dmi/id/product_name ]; then
    DEVICE_NAME=$(cat /sys/devices/virtual/dmi/id/product_name)
elif [ -f /sys/class/dmi/id/product_name ]; then
    DEVICE_NAME=$(cat /sys/class/dmi/id/product_name)
fi

# Отключение read-only на SteamOS
if [ "$IS_STEAMOS" = true ]; then
    echo "🔓 Отключение read-only режима SteamOS..."
    sudo steamos-readonly disable || echo "⚠️ steamos-readonly не найден"
fi

# Полная инициализация ключей pacman
echo "🔑 Настройка pacman ключей..."
if [ ! -d /etc/pacman.d/gnupg ] || [ -z "$(ls -A /etc/pacman.d/gnupg 2>/dev/null)" ]; then
    sudo pacman-key --init
    sudo pacman-key --populate archlinux
    [ "$IS_STEAMOS" = true ] && sudo pacman-key --populate holo 2>/dev/null || true
    echo "✅ Ключи pacman инициализированы"
else
    echo "✅ Ключи уже настроены"
fi

# УМНАЯ установка зависимостей
echo "📦 Проверка зависимостей..."

install_if_needed() {
    local pkg=$1
    if ! pacman -Qi "$pkg" &> /dev/null; then
        echo "  ➕ Устанавливаю $pkg..."
        sudo pacman -S --noconfirm "$pkg"
    else
        echo "  ✅ $pkg уже установлен"
    fi
}

install_if_needed nodejs
install_if_needed npm
install_if_needed git
install_if_needed base-devel
install_if_needed qrencode

# Проверка версии Node.js
NODE_MAJOR=$(node -e "console.log(process.versions.node.split('.')[0])" 2>/dev/null || echo "0")
if [ "$NODE_MAJOR" -ge 20 ]; then
    echo "✅ Node.js $NODE_MAJOR.x подходит"
else
    echo "❌ Node.js $NODE_MAJOR < 20. Обновляю..."
    sudo pacman -S --noconfirm nodejs npm
fi

# Безопасная настройка npm global
echo "🌍 Настройка npm global директории..."
mkdir -p ~/.npm-global
if ! grep -q "~/.npm-global" ~/.npmrc 2>/dev/null; then
    npm config set prefix '~/.npm-global'
fi
if ! grep -q "~/.npm-global" ~/.bashrc 2>/dev/null; then
    echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
fi
if [ -f ~/.zshrc ] && ! grep -q "~/.npm-global" ~/.zshrc 2>/dev/null; then
    echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.zshrc
fi
export PATH="$HOME/.npm-global/bin:$PATH"

# Установка/обновление Koda CLI
echo "🚀 Проверка Koda CLI..."
if command -v koda &> /dev/null; then
    echo "📥 Обновление Koda CLI..."
    npm install -g @kodadev/koda-cli@latest
    echo "✅ Koda CLI обновлен"
else
    echo "📥 Установка Koda CLI..."
    npm install -g @kodadev/koda-cli@latest
    echo "✅ Koda CLI установлен"
fi

# ✅ СОЗДАНИЕ ЯРЛЫКА "Konsole Koda"
echo "🖥️  Создание ярлыка на рабочий стол..."
DESKTOP_DIR="$HOME/Desktop"
KODA_DESKTOP="$DESKTOP_DIR/Konsole Koda.desktop"

cat > "$KODA_DESKTOP" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Konsole Koda
Comment=Запуск Koda CLI в Konsole
Icon=konsole
Exec=bash -c 'export PATH="$HOME/.npm-global/bin:$PATH"; konsole --noclose -e koda'
Terminal=false
Categories=Development;Utility;
StartupNotify=true
EOF

chmod +x "$KODA_DESKTOP"
xdg-desktop-icon activate "$KODA_DESKTOP" 2>/dev/null || true

echo "✅ Ярлык 'Konsole Koda' создан на рабочем столе!"

# ✅ СОЗДАНИЕ KODA.MD
echo "📝 Создание контекста Koda..."
mkdir -p ~/.kodacli

cat > ~/.kodacli/KODA.md << EOF
## Koda Added Memories

### Технические настройки
- При выполнении команд, требующих пароль sudo, выполнять команду через pkexec вместо sudo
- Пояснять пользователю свои действия и кратко описывать что делают те или иные выполняемые в настоящий момент команды
-
EOF

echo "✅ Файл контекста создан"

# ✅ НАСТРОЙКА МОДЕЛИ
echo "🎯 Настройка модели koda-base..."
mkdir -p ~/.kodacli
cat > ~/.kodacli/settings.json << 'EOF'
{
  "selectedAuthType": "koda-auth",
  "hideTips": true,
  "model": "koda-base"
}
EOF

echo "✅ Модель koda-base установлена"

# Предупреждение для SteamOS
if [ "$IS_STEAMOS" = true ]; then
    echo ""
    echo "⚠️  SteamOS: pacman-пакеты удалятся при обновлении!"
    echo "   Koda CLI и ярлык в ~/.npm-global сохранятся."
    echo ""
    read -p "Включить read-only? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo steamos-readonly enable
        echo "🔒 Read-only включен"
    else
        echo "🔓 Read-only отключен"
    fi
fi

# ✅ ОЧИСТКА ЭКРАНА И QR-КОД
clear
echo "
 █████   ████    ███████    ██████████     █████████
▒▒███   ███▒   ███▒▒▒▒▒███ ▒▒███▒▒▒▒███   ███▒▒▒▒▒███
 ▒███  ███    ███     ▒▒███ ▒███   ▒▒███ ▒███    ▒███
 ▒███████    ▒███      ▒███ ▒███    ▒███ ▒███████████
 ▒███▒▒███   ▒███      ▒███ ▒███    ▒███ ▒███▒▒▒▒▒███
 ▒███ ▒▒███  ▒▒███     ███  ▒███    ███  ▒███    ▒███
 █████ ▒▒████ ▒▒▒███████▒   ██████████   █████   █████
▒▒▒▒▒   ▒▒▒▒    ▒▒▒▒▒▒▒    ▒▒▒▒▒▒▒▒▒▒   ▒▒▒▒▒   ▒▒▒▒▒ "
echo ""
echo "🔄 Запустить Koda CLI можно с ярлыка на рабочем столе или командой: koda"
echo ""

qrencode -t utf8 "https://finance.ozon.ru/apps/sbp/ozonbankpay/019c8fe5-19dd-77a3-80c4-bb3ed668c0b2"

echo ""
echo "🙏 Пожалуйста поддержите автора по qr-коду выше"
echo ""
