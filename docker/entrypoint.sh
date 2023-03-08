#!/bin/bash

# if any of the commands in your code fails for any reason, the entire script fails
set -o errexit
# fail exit if one of your pipe command fails
set -o pipefail
# exits if any of your variables is not set
set -o nounset

postgres_ready() {
python << END
import sys

import psycopg2

try:
    psycopg2.connect(
        dbname="${POSTGRES_DB}",
        user="${POSTGRES_USER}",
        password="${POSTGRES_PASSWORD}",
        host="${POSTGRES_HOST}",
        port="${POSTGRES_PORT}",
    )
except psycopg2.OperationalError:
    sys.exit(-1)
sys.exit(0)

END
}
until postgres_ready; do
  >&2 echo 'Waiting for PostgreSQL to become available...'
  sleep 1
done
>&2 echo 'PostgreSQL is available'


case "$1" in
  run-server )
    echo 'Run Migrate'
    python manage.py migrate
    echo 'Running Server'
    python manage.py runserver 0.0.0.0:8000
    ;;
  run-beat )
    echo 'Run Beat'
    rm -f './celerybeat.pid'
    celery -A investment beat -l INFO --scheduler django_celery_beat.schedulers:DatabaseScheduler
    ;;
  run-worker )
    echo 'Run Worker'
    watchmedo auto-restart -d ./ -p '*tasks.py;*celery.py' --recursive -- celery -A investment worker -l INFO
    ;;
  * )
    "$@"
    ;;
esac

exec "$@"