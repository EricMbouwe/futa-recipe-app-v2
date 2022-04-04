#!/bin/bash

set -e
echo "Environment: $RAILS_ENV"

# Remove pre-existing puma/passenger server.pid
rm -f tmp/pids/server.pid

# run passed commands
exec bundle exec "$@"