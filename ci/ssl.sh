#!/usr/bin/env bash

set -eux

# TEST_RUBY_MYSQL2_SSL_DIR: custom SSL directory.
SSL_DIR=${TEST_RUBY_MYSQL2_SSL_DIR:-/etc/mysql}

# Make sure there is an /etc/mysql
mkdir -p "${SSL_DIR}"

# Copy the local certs to /etc/mysql
cp spec/ssl/*pem "${SSL_DIR}"

# Wherever MySQL configs live, go there (this is for cross-platform)
cd $(my_print_defaults --help | grep my.cnf | xargs find 2>/dev/null | xargs dirname)

# Put the configs into the server
echo "
[mysqld]
ssl-ca=${SSL_DIR}/ca-cert.pem
ssl-cert=${SSL_DIR}/server-cert.pem
ssl-key=${SSL_DIR}/server-key.pem
" >> my.cnf
