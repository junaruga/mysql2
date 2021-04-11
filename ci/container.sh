#!/usr/bin/env bash

set -eux

ruby -v
bundle install --path vendor/bundle --without development

# Start mysqld service.
bash ci/setup_container.sh

MAKE="make V=1" bundle exec rake
