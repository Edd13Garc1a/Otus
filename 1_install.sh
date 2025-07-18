#!/bin/bash

# Проверка прав root
if [ "$(id -u)" -ne 0 ]; then
  echo "Запустите скрипт с правами root: sudo $0" >&2
  exit 1
fi
sudo apt update

# Установка компонентов
apt install -y nginx apache2 mysql-server php libapache2-mod-php php-mysql || {
  echo "Ошибка при установке пакетов" >&2
  exit 1
}

# Запуск MySQL
systemctl start mysql
systemctl status mysql || {
  echo "MySQL не запущен" >&2
  exit 1
}

MYSQL_USER="root"
NEW_PASS="Testpass1$"

# Выполнение SQL команд
mysql -u"$MYSQL_USER" -p"$NEW_PASS" -e "
ALTER USER 'root'@'localhost' IDENTIFIED WITH 'caching_sha2_password' BY '$NEW_PASS';
CREATE DATABASE IF NOT EXISTS Otus_test;
USE Otus_test;
CREATE TABLE IF NOT EXISTS cart (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(255),
    quantity INT,
    source_ip VARCHAR(45) NOT NULL,
    destination_port INT NOT NULL,
    action_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);" || {
  echo "Ошибка при выполнении SQL-команд" >&2
  exit 1
}

# Полная очистка дефолтных конфигов
rm -f /etc/nginx/sites-enabled/*
rm -f /etc/apache2/sites-enabled/*

# Настройка Apache
echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf
a2enconf servername

echo "# Apache ports" > /etc/apache2/ports.conf
for port in 8080 8081 8082; do
  echo "Listen $port" >> /etc/apache2/ports.conf
  
  # Создаем контент для каждого порта
  webroot="/var/www/port-$port"
  mkdir -p $webroot
  
  cat > $webroot/index.php <<'EOF'
<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Подключение к БД
$db_host = 'localhost';
$db_user = 'root';
$db_pass = 'Testpass1$';
$db_name = 'Otus_test';

try {
    $conn = new PDO("mysql:host=$db_host;dbname=$db_name", $db_user, $db_pass);
    $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    die("Ошибка подключения к MySQL: " . $e->getMessage());
}

// Получение IP и порта
$source_ip = $_SERVER['REMOTE_ADDR'];
$destination_port = $_SERVER['SERVER_PORT'];

// Обработка добавления товара
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['product'], $_POST['quantity'])) {
    $product = trim($_POST['product']);
    $quantity = (int)$_POST['quantity'];

    if ($product !== '' && $quantity > 0) {
        $stmt = $conn->prepare("INSERT INTO cart (product_name, quantity, source_ip, destination_port) VALUES (?, ?, ?, ?)");
        $stmt->execute([$product, $quantity, $source_ip, $destination_port]);
    }
}

// Удаление товара
if (isset($_GET['delete'])) {
    $id = (int)$_GET['delete'];
    $stmt = $conn->prepare("DELETE FROM cart WHERE id = ?");
    $stmt->execute([$id]);
}

// Получение корзины
$cart = $conn->query("SELECT * FROM cart ORDER BY action_time DESC")->fetchAll();
?>

<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Корзина покупок</title>
    <style>
        body {
            font-family: 'Segoe UI', sans-serif;
            background: #f8f9fa;
            margin: 40px;
            color: #333;
        }

        .container {
            max-width: 900px;
            margin: auto;
        }

        h1 {
            text-align: center;
            color: #007bff;
            margin-bottom: 40px;
        }

        form {
            display: flex;
            gap: 10px;
            margin-bottom: 30px;
            justify-content: center;
        }

        input[type="text"], input[type="number"] {
            padding: 10px;
            font-size: 16px;
            border-radius: 8px;
            border: 1px solid #ccc;
            width: 200px;
        }

        button {
            background-color: #28a745;
            color: white;
            border: none;
            padding: 12px 20px;
            border-radius: 8px;
            font-size: 16px;
            cursor: pointer;
            transition: background 0.3s;
        }

        button:hover {
            background-color: #218838;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            background: white;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 4px 8px rgba(0,0,0,0.05);
        }

        th, td {
            padding: 14px;
            border-bottom: 1px solid #e9ecef;
            text-align: left;
        }

        th {
            background-color: #f1f3f5;
        }

        tr:last-child td {
            border-bottom: none;
        }

        .delete-link {
            color: #dc3545;
            text-decoration: none;
        }

        .delete-link:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
<div class="container">
    <h1>Корзина покупок</h1>

    <form method="post">
        <input type="text" name="product" placeholder="Название товара" required>
        <input type="number" name="quantity" placeholder="Количество" min="1" required>
        <button type="submit">Добавить</button>
    </form>

    <table>
        <tr>
            <th>Время</th>
            <th>Товар</th>
            <th>Кол-во</th>
            <th>IP</th>
            <th>Порт</th>
            <th>Удалить</th>
        </tr>
        <?php foreach ($cart as $item): ?>
        <tr>
            <td><?= htmlspecialchars($item['action_time']) ?></td>
            <td><?= htmlspecialchars($item['product_name']) ?></td>
            <td><?= htmlspecialchars($item['quantity']) ?></td>
            <td><?= htmlspecialchars($item['source_ip']) ?></td>
            <td><?= htmlspecialchars($item['destination_port']) ?></td>
            <td><a class="delete-link" href="?delete=<?= $item['id'] ?>" onclick="return confirm('Удалить товар?');">Удалить</a></td>
        </tr>
        <?php endforeach; ?>
    </table>
</div>
</body>
</html>
EOF

  # Проверка создания файла
  [ -f "$webroot/index.php" ] || {
    echo "Ошибка: не удалось создать $webroot/index.php" >&2
    exit 1
  }

  # Проверка синтаксиса PHP
  php -l $webroot/index.php || {
    echo "Ошибка синтаксиса в $webroot/index.php" >&2
    exit 1
  }

  # Конфиг виртуального хоста
  cat > /etc/apache2/sites-available/port-$port.conf <<EOF
<VirtualHost *:$port>
    DocumentRoot $webroot
    ErrorLog \${APACHE_LOG_DIR}/error-$port.log
    CustomLog \${APACHE_LOG_DIR}/access-$port.log combined
    
    <Directory $webroot>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

  a2ensite port-$port.conf
done

# Настройка Nginx
cat > /etc/nginx/conf.d/load-balancer.conf <<'EOF'
upstream backend {
    server 127.0.0.1:8080;
    server 127.0.0.1:8081;
    server 127.0.0.1:8082;
}

server {
    listen 80 default_server;
    server_name _;
    
    location = / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location ~ ^/port(8080|8081|8082)/?$ {
        proxy_pass http://127.0.0.1:$1/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

# Удаляем дефолтный сайт Nginx
rm -f /etc/nginx/sites-enabled/default

# Настройка прав
chown -R www-data:www-data /var/www/port-*
chmod -R 755 /var/www/port-*
chmod 644 /var/www/port-*/index.php

# Перезапуск служб
systemctl restart apache2
systemctl restart nginx
systemctl enable apache2 nginx mysql

# Проверка
echo "Настройка завершена!

Проверьте работу:
1. Балансировка:       http://192.168.33.245/
   (обновите несколько раз чтобы увидеть разные порты)

2. Прямой доступ:
   http://192.168.33.245:8080
   http://192.168.33.245:8081
   http://192.168.33.245:8082

3. Проверка портов:
   netstat -tulnp | grep -E '80|8080|8081|8082'
"
