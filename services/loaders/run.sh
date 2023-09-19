#!/usr/bin/env bash
cd /app

if [ -z "$SERVICE_ROLE" ]; then
  echo "Please set a SERVICE_ROLE environment variable"
  exit -1
fi

case $SERVICE_ROLE in
listener)
  bundle exec ruby listener.rb
  ;;
rebuild_index)
  bundle exec ruby fulltext_loader.rb
  ;;
plaats)
  bundle exec ruby plaats_loader.rb
*)
  echo "Unknown SERVICE_ROLE environment variable"
  exit -2
  ;;
esac

