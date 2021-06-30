#!/usr/bin/env bash

echo
echo "[*] Starting Django application..."
echo

echo
echo "[*] Preparing virtual environment..."
echo

rm -rf /app/.venv

python3.8 -m venv /app/.venv

source /app/.venv/bin/activate

echo
echo "[*] Installing dependencies..."
echo

pip install -r /app/requirements.txt

echo
echo "[*] Migrating database..."
echo

python manage.py migrate

echo
echo "[*] Starting development web server..."
echo

python manage.py runserver 0.0.0.0:8000

