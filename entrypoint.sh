#!/bin/sh

# This script waits for the database to be ready before starting the web server.

# Get database configuration from environment (with defaults)
DB_HOST="${POSTGRES_HOST:-db}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_USER="${POSTGRES_USER:-postgres}"

# The until loop will continue until the command `pg_isready` succeeds.
until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER"; do
  echo "Waiting for the database to be ready..."
  sleep 2
done

echo "Database is ready."

# Run database migrations to ensure the schema is up to date.
echo "Running database migrations..."
python manage.py migrate --settings=backend.production

# Collect all static files into the designated directory.
echo "Collecting static files..."
python manage.py collectstatic --settings=backend.production --noinput

# Start the Gunicorn web server.
echo "Starting Gunicorn server..."
python -m gunicorn backend.wsgi:application --bind 0.0.0.0:8000 --timeout 300