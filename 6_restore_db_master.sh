#!/bin/bash

# === НАСТРОЙКИ ===
GITHUB_REPO="git@github.com:Edd13Garc1a/Otus.git"
WORK_DIR="/home/odmin/mysql_restore_work"
EXTRACT_DIR="$WORK_DIR/extracted"
DB_NAME="Otus_test"
MYSQL_ROOT_PASS="Testpass1$"

# === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
info()    { echo -e "\e[34mℹ️  $1\e[0m"; }
success() { echo -e "\e[32m✅ $1\e[0m"; }
error()   { echo -e "\e[31m❌ $1\e[0m"; }

# === 1. Подготовка ===
echo -e "\n=============================================="
echo "Скрипт восстановления MySQL из бекапа в GitHub"
echo "Выполняется на сервере: $(hostname)"
echo "IP адрес: $(hostname -I | awk '{print $1}')"
echo "=============================================="

info "1. Подготовка рабочей директории: $WORK_DIR"
rm -rf "$WORK_DIR"
mkdir -p "$EXTRACT_DIR"

# === 2. Клонирование репозитория ===
info "2. Клонирование репозитория: $GITHUB_REPO"
git clone "$GITHUB_REPO" "$WORK_DIR/repo" || { error "Не удалось клонировать репозиторий"; exit 1; }

# === 3. Поиск последнего бэкапа ===
info "3. Поиск последнего бэкапа"
LATEST_BACKUP=$(find "$WORK_DIR/repo" -name "${DB_NAME}_*.sql.tar.gz" | sort | tail -n 1)
if [[ -z "$LATEST_BACKUP" ]]; then
    error "Не найден файл бэкапа для $DB_NAME"
    exit 1
fi
success "Найден бэкап: $LATEST_BACKUP"

# === 4. Извлечение бэкапа ===
info "4. Извлечение бэкапа"
tar -xzf "$LATEST_BACKUP" -C "$EXTRACT_DIR" || { error "Не удалось распаковать архив"; exit 1; }

SQL_FILE=$(find "$EXTRACT_DIR" -name "${DB_NAME}_*.sql" | head -n 1)
if [[ ! -f "$SQL_FILE" ]]; then
    error "SQL-файл не найден после распаковки"
    exit 1
fi
success "Найден SQL-файл: $SQL_FILE"

# === 5. Восстановление базы данных ===
info "5. Восстановление базы данных"
mysql -u root -p"$MYSQL_ROOT_PASS" -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;" || { error "Не удалось создать базу данных"; exit 1; }
mysql -u root -p"$MYSQL_ROOT_PASS" "$DB_NAME" < "$SQL_FILE" || { error "Ошибка при импорте SQL-файла"; exit 1; }
success "Импорт SQL завершён"

# === 6. Проверка восстановления ===
info "6. Проверка восстановления"
TABLE_COUNT=$(mysql -u root -p"$MYSQL_ROOT_PASS" -sN -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$DB_NAME';")

if [[ -z "$TABLE_COUNT" ]]; then
    error "Не удалось получить количество таблиц в базе $DB_NAME"
    exit 1
elif [[ "$TABLE_COUNT" -eq 0 ]]; then
    error "База данных $DB_NAME не содержит таблиц"
    exit 1
else
    success "База данных $DB_NAME успешно восстановлена: $TABLE_COUNT таблиц"
fi

echo -e "\n🎉 \e[1;32mВосстановление завершено успешно!\e[0m"
