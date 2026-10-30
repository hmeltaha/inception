
#!/bin/bash
set -e

DB_PASSWORD=$(cat /run/secrets/db_password)
ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

if [ ! -d /var/lib/mysql/mysql ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
fi

mariadbd --user=mysql --skip-networking \
    --socket=/run/mysqld/mysqld.sock &
pid=$!

until mariadb-admin ping --silent; do
    sleep 1
done

mariadb -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
SQL

if [ ! -f /var/lib/mysql/.root_password_set ]; then
    mariadb -u root <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASSWORD}';
FLUSH PRIVILEGES;
SQL
    touch /var/lib/mysql/.root_password_set
fi

mariadb-admin -u root -p"${ROOT_PASSWORD}" shutdown
wait "$pid"

exec mariadbd --user=mysql --console
