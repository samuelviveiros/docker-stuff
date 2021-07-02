#!/usr/bin/env bash

CHECKSUM_ENABLED="off"

echo
echo "[*] Starting worker service..."
echo


echo
echo "[*] Preparing virtual environment..."
echo

cd /app

#rm -rf .venv

if [ ! -d .venv ]; then
  python3.8 -m venv .venv
fi

source .venv/bin/activate


if [ $CHECKSUM_ENABLED == "on" ]; then
  echo
  echo "[*] Checking requirements.txt MD5 hash..."
  echo

  OLD_MD5=$(cat requirements.md5 2>/dev/null || echo "fallback-hash")
  NEW_MD5=$(md5sum requirements.txt | awk '{ print $1 }')

  if [ $OLD_MD5 != $NEW_MD5 ]; then
    echo
    echo "[*] Installing dependencies..."
    echo

    echo $NEW_MD5 > requirements.md5
    pip install -U -r requirements.txt
  fi
else
  echo
  echo "[*] Installing dependencies..."
  echo
  pip install -U -r requirements.txt
fi


echo
echo "[*] Migrating database..."
echo

python manage.py migrate


echo
echo "[*] Starting development web server..."
echo

python manage.py runserver 0.0.0.0:8000

