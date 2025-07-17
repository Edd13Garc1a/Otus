#!/bin/bash

git clone https://github.com/Edd13Garc1a/Otus.git
cd Otus

# 2. Делаем скрипты исполняемыми
chmod +x 2_install.sh
chmod +x 4_install_mysql.sh
chmod +x 5_install_monitoring.sh
chmod +x 6_install_elk_v3.sh
chmod +x 7_backup_slave_and_push.sh
chmod +x 8_restore_db_master.sh

echo "Запуск установки nginx, apache2."
./2_install.sh

# раскомментировать при аварином восстановлении
# echo "Установка свежего бекапа"
# ./8_restore_db_master.sh

echo "Запуск установки и настройки MySQL..."
./4_install_mysql.sh

echo "Запуск установки Prometheus, node_exporter, Grafana ..."
./5_install_monitoring.sh

echo "Запуск установки Elasticsearch, Kibana, Filebeat..."
./6_install_elk_v3.sh

echo "Бекап БД и пуш в репозиторий"
./7_backup_slave_and_push.sh
                                               
echo "Установка завершена!"
