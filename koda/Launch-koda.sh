#!/bin/bash

# Скрипт установки Koda CLI на SteamOS/Arch Linux
# + Создание ярлыка "Konsole Koda" на рабочий стол

# Если передан флаг --run, выполняем установку
# Иначе открываем Konsole
if [ "$1" != "--run" ]; then
    konsole --noclose -e "$0 --run" || {
        echo "Ошибка: Konsole не установлен или недоступен"
        echo "Запустите вручную: $0 --run"
        exit 1
    }
    exit 0
fi

set -e  # Выход при любой ошибке

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

# Делаем ярлык исполняемым и видимым
chmod +x "$KODA_DESKTOP"
xdg-desktop-icon activate "$KODA_DESKTOP" 2>/dev/null || true

echo "✅ Ярлык 'Konsole Koda' создан на рабочем столе!"

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

# Финальный тест И АВТОЗАПУСК
echo ""
echo "🧪 Тестирование Koda CLI..."
if command -v koda &> /dev/null; then
    echo "✅ Koda CLI готов!"
    echo ""
    echo "🔥 Запуск Koda CLI ассистента..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exec koda  # ЗАПУСКАЕМ Koda CLI
else
    echo "❌ koda не найден в PATH"
    echo "Перезапустите терминал и попробуйте снова"
    echo "=== Терминал открыт для отладки ==="
    exec bash
fi
