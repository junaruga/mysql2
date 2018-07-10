#!/usr/bin/env bash

set -eux

echo -e "deltarpm=0\ninstall_weak_deps=0\ntsflags=nodocs" >> /etc/dnf/dnf.conf
dnf -y update
dnf -y install \
  mariadb-connector-c-devel \
  mariadb-server \
  hostname \
  ruby-devel \
  rubygem-rdoc \
  rubygem-bigdecimal \
  git \
  gcc \
  gcc-c++ \
  make \
  redhat-rpm-config
gem install bundler

MYSQL_TEST_LOG="$(pwd)/mysql.log"

mysql_install_db \
  --log-error="${MYSQL_TEST_LOG}"
/usr/libexec/mysqld \
  --user=root \
  --log-error="${MYSQL_TEST_LOG}" \
  --ssl &
sleep 3
cat ${MYSQL_TEST_LOG}

mysql -u root -e 'CREATE DATABASE IF NOT EXISTS test'
