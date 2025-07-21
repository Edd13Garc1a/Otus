```bash
#!/bin/bash

# Конфигурационные параметры
SCRIPT_PATH="./5_backup_slave_and_push.sh"
LOG_FILE="/var/log/backup.log"
CRON_JOB="0 2 * * * /bin/bash ${SCRIPT_PATH} >> ${LOG_FILE} 2>&1"

# Функция для проверки ошибок
check_error() {
    if [ $? -ne 0 ]; then
        echo "Ошибка: $1"
        exit 1
    fi
}

# Проверка существования скрипта
if [ ! -f "${SCRIPT_PATH}" ]; then
    echo "Ошибка: Скрипт ${SCRIPT_PATH} не найден"
    exit 1
fi

# Убедимся, что скрипт имеет права на выполнение
chmod +x "${SCRIPT_PATH}"
check_error "Не удалось установить права на выполнение для ${SCRIPT_PATH}"

# Проверка, существует ли уже такая задача в crontab
echo "Проверка наличия задачи Cron..."
if crontab -l 2>/dev/null | grep -q "${SCRIPT_PATH}"; then
    echo "Задача Cron уже существует, пропускаем настройку"
    exit 0
fi

# Добавление задачи в crontab
echo "Добавление задачи Cron для ежедневного выполнения в 2:00 AM..."
(crontab -l 2>/dev/null; echo "${CRON_JOB}") | crontab -
check_error "Не удалось добавить задачу в crontab"

echo "Задача Cron успешно добавлена. Логи будут записываться в ${LOG_FILE}"
```
