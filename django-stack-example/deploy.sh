#!/usr/bin/env bash

APP_IMG_NAME=myapp
DOCKERFILE_DIR=$PWD/images
STACK_NAME=dj
COMPOSE_FILE=stack.yml
DATABASE_DIR=$PWD/data

function echo_fancy() {
  echo
  echo $1
  echo
}

function build() {
  echo_fancy "[*] Building app image..."
  docker build -t $APP_IMG_NAME $DOCKERFILE_DIR
  if [ ! $? == 0 ]; then
    echo_fancy "[-] Could not build the app image."
    exit 1
  fi
}

function remove_stack() {
  echo_fancy "[*] Removing the old stack..."
  docker stack rm $STACK_NAME
  while true; do
    echo_fancy "[*] Waiting for services to be totally purged..."
    docker service ls -f name=$STACK_NAME | grep -i ${STACK_NAME}_ >/dev/null
    SERVICES_STILL_RUNNING=$?

    docker network ls -f name=${STACK_NAME}_default | grep -i ${STACK_NAME}_default >/dev/null
    NETWORK_STILL_EXISTS=$?

    if [ ! $SERVICES_STILL_RUNNING == 0 ] && [ ! $NETWORK_STILL_EXISTS == 0 ]; then
      break
    fi

    sleep 3
  done
}

function deploy() {
  echo_fancy "[*] Deploying now..."
  docker stack deploy $STACK_NAME -c $COMPOSE_FILE
}

build
remove_stack

if [ ! -d $DATABASE_DIR ]; then
  echo_fancy "[*] Creating database directory..."
  mkdir $DATABASE_DIR
fi

deploy

exit 0

