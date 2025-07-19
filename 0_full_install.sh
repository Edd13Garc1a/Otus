#!/bin/bash
# Делаем скрипты исполняемыми
chmod +x 1_install.sh
chmod +x 2_install_mysql.sh
chmod +x 3_install_monitoring.sh
chmod +x 4_install_elk_v3.sh
chmod +x 5_backup_slave_and_push.sh
chmod +x 6_restore_db_master.sh

echo "Запуск установки nginx, apache2."
./1_install.sh

echo "Запуск установки и настройки MySQL..."
./2_install_mysql.sh

echo "Запуск установки Prometheus, node_exporter, Grafana ..."
./3_install_monitoring.sh

echo "Запуск установки Elasticsearch, Kibana, Filebeat..."
./4_install_elk.sh

echo "Бекап БД и пуш в репозиторий"
./5_backup_slave_and_push.sh

 # раскомментировать при аварином восстановлении
# echo "Установка свежего бекапа"
# ./6_restore_db_master.sh

echo "Установка завершена!"
