#!/bin/bash

echo "Установка Grafana..."

sudo apt-get install -y adduser libfontconfig1 musl
wget https://dl.grafana.com/oss/release/grafana_10.4.1_amd64.deb
sudo dpkg -i grafana_10.4.1_amd64.deb

# Запускаем Grafana
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

echo "Grafana установлена и запущена. Проверьте статус:"
echo "sudo systemctl status grafana-server"
echo "Веб-интерфейс доступен на http://localhost:3000"
echo "Логин/пароль по умолчанию: admin/admin"
