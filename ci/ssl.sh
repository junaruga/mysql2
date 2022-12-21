#!/usr/bin/env bash

set -eux

ROOT_DIR="$(pwd)"

# Wherever MySQL configs live, go there (this is for cross-platform)
cd $(my_print_defaults --help | grep my.cnf | xargs find 2>/dev/null | xargs dirname)

# Put the configs into the server
echo "
[mysqld]
ssl-ca=${ROOT_DIR}/spec/ssl/ca-cert.pem
ssl-cert=${ROOT_DIR}/spec/ssl/server-cert.pem
ssl-key=${ROOT_DIR}/spec/ssl/server-key.pem
" >> my.cnf
