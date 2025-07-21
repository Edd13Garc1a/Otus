#!/bin/bash

# Путь до скрипта, который должен выполняться по cron
TARGET_SCRIPT="/root/Otus/5_backup_slave_and_push.sh"

# Проверка наличия скрипта
if [ ! -f "$TARGET_SCRIPT" ]; then
    echo "❌ Ошибка: Скрипт $TARGET_SCRIPT не найден."
    exit 1
fi

# Делаем скрипт исполняемым
chmod +x "$TARGET_SCRIPT"

# Добавляем cron-задание (удаляем предыдущее, если было)
(crontab -l 2>/dev/null | grep -v "$TARGET_SCRIPT"; echo "0 1 * * * $TARGET_SCRIPT >> /var/log/mysql_backup.log 2>&1") | crontab -

echo "✅ Cron-задание добавлено: ежедневный запуск в 01:00"
echo "⏱️  Лог будет сохраняться в /var/log/mysql_backup.log"
