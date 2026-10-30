#!/bin/bash
set -e

DB_PASSWORD=$(cat /run/secrets/db_password)
ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

# Initialize MariaDB only if the database is new.
if [ ! -d /var/lib/mysql/mysql ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
fi

# Start MariaDB temporarily without network access.
mariadbd --user=mysql --skip-networking \
    --socket=/run/mysqld/mysqld.sock &
pid=$!

for i in $(seq 1 30); do
    if mariadb-admin ping --silent; then
        break
    fi

    if [ "$i" -eq 30 ]; then
        echo "MariaDB failed to start"
        exit 1
    fi

    sleep 1
done

# Configure database and user only on first startup.
if [ ! -f /var/lib/mysql/.inception_initialized ]; then
    mariadb -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost'
IDENTIFIED VIA mysql_native_password USING PASSWORD('${ROOT_PASSWORD}')
OR unix_socket;
FLUSH PRIVILEGES;
SQL

    touch /var/lib/mysql/.inception_initialized
fi

# Verify MariaDB is accessible through the local Unix socket.
mariadb -u root \
    --protocol=socket \
    --socket=/run/mysqld/mysqld.sock \
    -e "SELECT 1;" >/dev/null

# Shut down the temporary MariaDB server.
mariadb-admin -u root \
    --protocol=socket \
    --socket=/run/mysqld/mysqld.sock shutdown

wait "$pid"

# Start MariaDB as the main container process.
exec mariadbd --user=mysql --console