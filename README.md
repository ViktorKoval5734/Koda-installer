# Koda CLI Installer

Установщик Koda CLI для SteamOS/Arch Linux с автоматическим созданием ярлыка на рабочем столе.

## Особенности

- 🚀 Автоматическая установка Node.js, npm, git, base-devel
- 🔑 Инициализация ключей pacman
- 📦 Установка/обновление Koda CLI
- 🖥️ Создание ярлыка "Konsole Koda" на рабочем столе
- 🔓 Автоматическое отключение read-only режима на SteamOS
- 🧪 Автоматический тест и запуск Koda CLI после установки

## Использование

### Через терминал:

```bash
# Запустите скрипт
curl -L koda-esbd.onrender.com/Launch-koda.sh|bash

```

Через файловый менеджер:
Скачайте файл`Launch-koda.sh` и запустите двойным кликом — он автоматически откроет Konsole.

## Требования

- SteamOS или иной Arch-подобный дистрибутив Linux
- Интернет-соединение
- Права администратора (sudo)

## Что устанавливается

- Node.js (версия 20+)
- npm
- git
- base-devel
- Koda CLI (@kodadev/koda-cli)

## Создаётся

- Ярлык `Konsole Koda` на рабочем столе для быстрого запуска

## Примечание для SteamOS

Pacman-пакеты будут удалены при обновлении SteamOS, но Koda CLI в `~/.npm-global` сохранится.
