#!/usr/bin/env bash

set -eux

yum -y update
yum -y install epel-release
# The options are to install faster.
yum -y install \
  --setopt=deltarpm=0 \
  --setopt=install_weak_deps=false \
  --setopt=tsflags=nodocs \
  mariadb-server \
  mariadb-devel \
  ruby-devel \
  git \
  gcc \
  gcc-c++ \
  make
gem update --system > /dev/null
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
