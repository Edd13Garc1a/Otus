#!/bin/bash

# Проверка на root-права
if [ "$(id -u)" -ne 0 ]; then
    echo "Этот скрипт должен быть запущен с правами root" >&2
    exit 1
fi

# Директория с пакетами
PKG_DIR="/home/odmin/elk"

# Установка Elasticsearch
echo "🔵 Установка Elasticsearch..."
dpkg -i "${PKG_DIR}/elasticsearch-8.9.1-amd64.deb"

# Настройка Elasticsearch
echo "🔵 Настройка Elasticsearch..."
cat > /etc/elasticsearch/elasticsearch.yml <<EOL
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch

xpack.security.enabled: false
xpack.security.enrollment.enabled: true

xpack.security.http.ssl:
  enabled: false
  keystore.path: certs/http.p12

xpack.security.transport.ssl:
  enabled: false
  verification_mode: certificate
  keystore.path: certs/transport.p12
  truststore.path: certs/transport.p12
# cluster.initial_master_nodes: ["elk"]
discovery.type: single-node

http.host: 0.0.0.0
EOL

systemctl daemon-reload
systemctl enable elasticsearch
systemctl start elasticsearch

# Установка Kibana
echo "🔵 Установка Kibana..."
dpkg -i "${PKG_DIR}/kibana-8.9.1-amd64.deb"

# Настройка Kibana
echo "🔵 Настройка Kibana..."
cat > /etc/kibana/kibana.yml <<EOL
server.port: 5601
server.host: "0.0.0.0"
elasticsearch.hosts: ["http://localhost:9200"]
EOL

systemctl enable kibana
systemctl start kibana

# Установка Filebeat
echo "🔵 Установка Filebeat..."
dpkg -i "${PKG_DIR}/filebeat-8.9.1-amd64.deb"

# Настройка Filebeat
echo "🔵 Настройка Filebeat..."

# 1. Включение модуля Nginx
filebeat modules enable nginx

# 2. Настройка модуля Nginx (пути к логам)
cat > /etc/filebeat/modules.d/nginx.yml <<EOL
- module: nginx
  access:
    enabled: true
    var.paths: ["/var/log/nginx/access.log*"]
  error:
    enabled: true
    var.paths: ["/var/log/nginx/error.log*"]
EOL

# 3. Основная конфигурация Filebeat
cat > /etc/filebeat/filebeat.yml <<EOL
filebeat.inputs:
- type: filestream
  enabled: false

filebeat.config.modules:
  path: \${path.config}/modules.d/*.yml
  reload.enabled: false

setup.template.settings:
  index.number_of_shards: 1

output.elasticsearch:
  hosts: ["localhost:9200"]

processors:
  - add_host_metadata:
      when.not.contains.tags: forwarded
  - add_cloud_metadata: ~
  - add_docker_metadata: ~
  - add_kubernetes_metadata: ~
EOL

# 4. Загрузка дашбордов Kibana
filebeat setup --dashboards

# 5. Запуск Filebeat
systemctl enable filebeat
systemctl start filebeat

# Проверка статуса
echo "🔵 Проверка статуса сервисов..."
systemctl status elasticsearch kibana filebeat --no-pager

echo "✅ Установка и настройка завершены!"
echo "🌐 Kibana доступна по адресу: http://192.168.33.245:5601"
echo "📊 Готовые дашборды для Nginx:"
echo "  1. Откройте Kibana → Analytics → Dashboard"
echo "  2. Найдите '[Filebeat Nginx] Access and error logs'"
