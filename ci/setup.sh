#!/usr/bin/env bash

set -eux

# Disable apparmor profile if it is enabled.
# MariaDB recommends not running MariaDB with an apparmor profile.
# https://mariadb.com/kb/en/the-community-mariadb-troubles-only-running-after-reboot-times-out-when-try/
DISABLE_APPARMOR_IF_ENABLED=false
# Change the password to be empty.
CHANGED_PASSWORD=false
# Change the password to be empty, recreating the root user on mariadb < 10.2
# where ALTER USER is not available.
# https://stackoverflow.com/questions/56052177/
CHANGED_PASSWORD_BY_RECREATE=false

# Install the default used DB if DB is not set.
if [[ -n ${GITHUB_ACTIONS-} && -z ${DB-} ]]; then
  if command -v lsb_release > /dev/null; then
    case "$(lsb_release -cs)" in
    xenial | bionic)
      sudo apt-get install -qq mysql-server-5.7 mysql-client-core-5.7 mysql-client-5.7
      CHANGED_PASSWORD=true
      ;;
    focal)
      sudo apt-get install -qq mysql-server-8.0 mysql-client-core-8.0 mysql-client-8.0
      CHANGED_PASSWORD=true
      ;;
    *)
      ;;
    esac
  fi
fi

# Install MySQL 5.5 if DB=mysql55
if [[ -n ${DB-} && x$DB =~ ^xmysql55 ]]; then
  sudo bash ci/mysql55.sh
fi

# Install MySQL 5.7 if DB=mysql57
if [[ -n ${DB-} && x$DB =~ ^xmysql57 ]]; then
  sudo bash ci/mysql57.sh
  CHANGED_PASSWORD=true
fi

# Install MySQL 8.0 if DB=mysql80
if [[ -n ${DB-} && x$DB =~ ^xmysql80 ]]; then
  sudo bash ci/mysql80.sh
  CHANGED_PASSWORD=true
fi

# Install MariaDB client headers after Travis CI fix for MariaDB 10.2 broke earlier 10.x
if [[ -n ${DB-} && x$DB =~ ^xmariadb10.0 ]]; then
  if [[ -n ${GITHUB_ACTIONS-} ]]; then
    sudo apt-get install -y -o Dpkg::Options::='--force-confnew' mariadb-server mariadb-server-10.0 libmariadb2
    CHANGED_PASSWORD_BY_RECREATE=true
  else
    sudo apt-get install -y -o Dpkg::Options::='--force-confnew' libmariadbclient-dev
  fi
fi

# Install MariaDB client headers after Travis CI fix for MariaDB 10.2 broke earlier 10.x
if [[ -n ${DB-} && x$DB =~ ^xmariadb10.1 ]]; then
  if [[ -n ${GITHUB_ACTIONS-} ]]; then
    sudo apt-get install -y -o Dpkg::Options::='--force-confnew' mariadb-server mariadb-server-10.1 libmariadb-dev
    CHANGED_PASSWORD_BY_RECREATE=true
  else
    sudo apt-get install -y -o Dpkg::Options::='--force-confnew' libmariadbclient-dev
  fi
fi

# Install MariaDB 10.2 if DB=mariadb10.2
# NOTE this is a workaround until Travis CI merges a fix to its mariadb addon.
if [[ -n ${DB-} && x$DB =~ ^xmariadb10.2 ]]; then
  sudo apt-get install -y -o Dpkg::Options::='--force-confnew' mariadb-server mariadb-server-10.2 libmariadbclient18
fi

# Install MariaDB 10.3 if DB=mariadb10.3
if [[ -n ${GITHUB_ACTIONS-} && -n ${DB-} && x$DB =~ ^xmariadb10.3 ]]; then
  # sudo apt-get remove --purge mariadb-server mariadb-server-10.3

  # sudo systemctl stop apparmor.service
  # sudo update-rc.d -f apparmor remove

  # sudo apt-get remove --purge mysql-server mysql-client mysql-common
  # sudo apt-get autoremove
  # sudo apt-get autoclean
  # sudo apt-get install mariadb-server

  # sudo systemctl start apparmor.service
  # sudo update-rc.d apparmor defaults

  ls -l /etc/apparmor.d
  ls -l /etc/apparmor.d/disable

  sudo ln -s /etc/apparmor.d/usr.sbin.mysqld /etc/apparmor.d/disable/
  # Remove apparmor definitions
  sudo apparmor_parser -R /etc/apparmor.d/usr.sbin.mysqld
  sudo aa-status

  sudo apt-get install -y mariadb-server mariadb-server-10.3 libmariadb-dev

  ls -l /etc/apparmor.d
  ls -l /etc/apparmor.d/disable

  service mysql status || true
  # cat /lib/systemd/system/mariadb.service || true
  grep ^LimitNOFILE /lib/systemd/system/mariadb.service
  # journalctl -xe -n 100 || true

  # https://mariadb.com/kb/en/could-not-increase-number-of-max_open_files-to-more-than-1024-request-1835/
  sudo sed -i -E '/^LimitNOFILE=/ s/[0-9]+/infinity/' /lib/systemd/system/mariadb.service
  grep ^LimitNOFILE /lib/systemd/system/mariadb.service

  pushd $(my_print_defaults --help | grep my.cnf | xargs find 2>/dev/null | xargs dirname)
  echo "
[mysqld]
max_connections=300
" | sudo tee -a my.cnf
  popd

  sudo systemctl daemon-reload || true

  if ! sudo service mysql restart; then
    # service mysql status || true
    systemctl status mysql.service || true
    systemctl status mariadb.service || true
    journalctl -xe -n 50 -u mariadb

    sudo systemctl restart mariadb.service || true
    sudo systemctl status mariadb.service || true

    false
  fi

  DISABLE_APPARMOR_IF_ENABLED=true
  CHANGED_PASSWORD=true
fi

# Install MySQL/MariaDB if OS=darwin
if [[ x$OSTYPE =~ ^xdarwin ]]; then
  brew update > /dev/null

  # Check available packages.
  for KEYWORD in mysql mariadb; do
    brew search "${KEYWORD}"
  done

  brew info "$DB"
  brew install "$DB"
  DB_PREFIX="$(brew --prefix "${DB}")"
  export PATH="${DB_PREFIX}/bin:${PATH}"
  export LDFLAGS="-L${DB_PREFIX}/lib"
  export CPPFLAGS="-I${DB_PREFIX}/include"

  mysql.server start
  CHANGED_PASSWORD_BY_RECREATE=true
fi

# if [ "${DISABLE_APPARMOR_IF_ENABLED}" = true ]; then
#   sudo ln -s /etc/apparmor.d/usr.sbin.mysqld /etc/apparmor.d/disable/
#   sudo apparmor_parser -R /etc/apparmor.d/usr.sbin.mysqld
#   sudo aa-status
#   sudo dpkg --configure mariadb-server
# fi

# TODO: get SSL working on OS X in Travis
if ! [[ x$OSTYPE =~ ^xdarwin ]]; then
  # Skip mariadb 10.3 on GitHub Actions failing to start the service.
  sudo bash ci/ssl.sh
  if ! sudo service mysql restart; then
    systemctl status mysql.service || true
    # journalctl -xe -n 100 || true
    false
  fi
fi

mysqld --version

MYSQL_OPTS=''
DB_SYS_USER=root
if ! [[ x$OSTYPE =~ ^xdarwin ]]; then
  if [[ -n ${GITHUB_ACTIONS-} && -f /etc/mysql/debian.cnf ]]; then
    MYSQL_OPTS='--defaults-extra-file=/etc/mysql/debian.cnf'
    # Install from packages in OS official packages.
    if sudo grep -q debian-sys-maint /etc/mysql/debian.cnf; then
      # bionic, focal
      DB_SYS_USER=debian-sys-maint
    else
      # xenial
      DB_SYS_USER=root
    fi
  fi
fi

# Verify server connection.
if ! sudo mysql ${MYSQL_OPTS} -u "${DB_SYS_USER}" -e 'SHOW DATABASES' > /dev/null; then
  journalctl -xe -n 100 || true
  false
fi

if [ "${CHANGED_PASSWORD}" = true ]; then
  # https://www.percona.com/blog/2016/03/16/change-user-password-in-mysql-5-7-with-plugin-auth_socket/
  sudo mysql ${MYSQL_OPTS} -u "${DB_SYS_USER}" \
    -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY ''"
elif [ "${CHANGED_PASSWORD_BY_RECREATE}" = true ]; then
  sudo mysql ${MYSQL_OPTS} -u "${DB_SYS_USER}" <<SQL
DROP USER 'root'@'localhost';
CREATE USER 'root'@'localhost' IDENTIFIED BY '';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL
fi

mysql -u root -e 'CREATE DATABASE IF NOT EXISTS test'
