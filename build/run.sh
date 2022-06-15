#!/bin/bash
cd /app

if [ -f "start.sh" ]; then
  ./start.sh
fi


if [ -n "$DEBUG" ]; then
echo "DEBUG started"
  bundle exec rdebug-ide --host 0.0.0.0 --port 1234 -- /usr/local/bundle/bin/puma -C "-" -b tcp://0.0.0.0:9292 -v -e development
else
  bundle exec puma -C config/puma.rb
fi
