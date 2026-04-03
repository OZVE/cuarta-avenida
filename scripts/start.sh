#!/bin/sh
set -e

echo "==> Waiting for PostgreSQL..."
until nc -z "${DB_HOST:-postgres}" "${DB_PORT:-5432}"; do
  echo "    PostgreSQL not ready, retrying in 3s..."
  sleep 3
done
echo "==> PostgreSQL ready."

echo "==> Running database migrations..."
npx medusa db:migrate

echo "==> Starting Medusa API..."
exec npx medusa start
