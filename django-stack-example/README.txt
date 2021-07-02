CRIANDO UM SERVIÇO PARA UMA APLICAÇÃO DJANGO
--------------------------------------------

O objetivo deste tutorial é montar uma stack bem simples para uma aplicação Django.

O orquestrador que utilizaremos será o Docker Swarm.

Inicialmente, teremos apenas um serviço que representará a nossa aplicação web Django.

Posteriormente adicionaremos outro serviço que fará o papel de servidor de banco de dados.

Para fins didáticos, vamos supor que o nosso usuário Linux se chame dev, de maneira que o diretório home seria: /home/dev

Vamos lá então. Crie o diretório do projeto, que em nosso exemplo será:

/home/dev/myproject

Vamos começar criando um ambiente virtual para a nossa aplicação:

$ cd /home/dev/myproject
$ python3 -m venv .venv

Faça a ativação do ambiente virtual:

$ source .venv/bin/activate

Instale a última versão LTS oficial do Django:

(.venv)$ pip install Django==3.2.4

Inicie um novo projeto Django:

(.venv)$ django-admin startproject app src

Perceba que todo o código-fonte da aplicação Django estará localizado no diretório src.

Salve as dependências em um arquivo:

(.venv)$ pip freeze > src/requirements.txt

Apenas para conhecimento, os pacotes listados nesse arquivo podem ser facilmente instalado da seguinte forma:

$ pip install -U -r requirements.txt

Mas no nosso projeto de exemplo, esse trabalho será automatizado por um script bash.

Também é interessante incluir no requirements.txt o pacote do IPython.

Trata-se de um shell interativo de Python muito mais versátil de utilizar.

Com exceção do pacote Django, substitua os operadores == por >=

O conteúdo deverá ficar assim:

asgiref>=3.4.0
Django==3.2.4
pytz>=2021.1
sqlparse>=0.4.1
ipython>=7.25.0

Faça a migração de dados:

(.venv)$ cd /home/dev/myproject/src
(.venv)$ python manage.py migrate

Como o banco de dados ainda é o padrão Django, será criado um arquivo db.sqlite3.

Nesse ponto, a estrutura do nosso projeto deverá estar assim:

 /
 └─ home
     └─ dev
         └─ myproject
             ├─ .venv
             └─ src
                 ├─ app
                 │   ├─ asgi.py
                 │   ├─ __init__.py
                 │   ├─ settings.py
                 │   ├─ urls.py
                 │   └─ wsgi.py
                 ├─ db.sqlite3
                 ├─ manage.py
                 └─ requirements.txt

Caso deseje, execute o servidor web de desenvolvimento do Django para testar a aplicação:

(.venv)$ cd /home/dev/myproject/src
(.venv)$ python manage.py runserver 0.0.0.0:8080

Saia do ambiente virtual e exclua o diretório .venv:

(.venv)$ deactivate
$ rm -rf /home/dev/myproject/.venv

Posteriormente, automatizaremos a criação do ambiente virtual, mas dessa vez dentro do diretório src via script bash.

Com a estrutura inicial do nosso projeto pronta, podemos agora focar na criação do serviço docker.

Primeiramente, precisaremos "buildar" uma imagem docker que tenha as ferramentas necessárias para rodar a nossa aplicação.

Apesar de existirem diversas imagens disponívels no site do docker geridas pela comunidade, iremos cria a nossa própria imagem customizada.

Entre no diretório do projeto e crie um diretório chamado images:

$ cd /home/dev/myproject
$ mkdir images

Dentro do diretório images, crie um arquivo Dockerfile com o seguinte conteúdo:


FROM ubuntu:20.04

RUN apt update && \
    apt install python3.8 python3-venv -y && \
    apt install inetutils-ping -y

VOLUME /app

WORKDIR /app


A nossa imagem será basicamente um Ubuntu com Python 3 e módulo de virtualenv instalado.

Crie a imagem, que em nosso exemplo chamaremos de myapp:

$ cd /home/dev/myproject
$ docker build -t myapp ./images

Com a imagem pronta, agora falta definirmos um arquivo compose que descreverá a nossa stack.

No diretório do projeto, crie um arquivo chamado stack.yml com o seguinte conteúdo:


# stack.yml
version: '3.7'

services:

  worker:
    image: myapp

    # Ponto de entrada:
    command: bash /app/start.sh

    stop_signal: SIGINT

    volumes:
      - ${PWD}/src:/app

    ports:
      # host:serviço
      - 8080:8000


Nesse arquivo, estamos definindo um serviço chamado worker que rodará na porta 8000 a qual será mapeada para a porta 8080 do host.

Note também que o nosso serviço se baseia na imagem myapp que criamos anteriormente.

Na linha onde temos volumes, o código-fonte da nossa aplicação Django está localizado no diretório ${PWD}/src (/home/dev/myproject/src) e está sendo mapeado para um diretório dentro do container em /app.

Por fim, na linha command, estamos definindo o ponto de entrada da nossa aplicação. Trata-se nesse caso de um script bash que será executado assim que o docker iniciar o serviço.

Crie o script start.sh no diretório src com o seguinte conteúdo:


#!/usr/bin/env bash
# start.sh

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


Até o momento, a estrutura do nosso projeto está assim:

 /
 └─ home
     └─ dev
         └─ myproject
             ├─ stack.yml
             ├─ images
             │   └─ Dockerfile
             └─ src
                 ├─ app
                 │   ├─ asgi.py
                 │   ├─ __init__.py
                 │   ├─ settings.py
                 │   ├─ urls.py
                 │   └─ wsgi.py
                 ├─ db.sqlite3
                 ├─ manage.py
                 ├─ requirements.txt
                 ├─ start.sh
                 └─ .venv

Antes de prosseguirmos com o deploy da stack, pode ser interessante subir um container diretamente apenas para testar o script start.sh:

$ cd /home/dev/myproject
$ docker run -it --rm -p 8080:8000 -v $(pwd)/src:/app myapp bash /app/start.sh

Se tudo correu bem, a aplicação estará acessível no host através do endereço http://127.0.0.1:8080

Perceba que tudo o que fizemos até o momento foi "buildar" uma imagem capaz de rodar a nossa aplicação, porém com o código-fonte "do lado de fora", ou seja, acessível no container através de um volume.

Essa organização é muito conveniente para um ambiente de desenvolvimento. Mas quando o código for para produção, tudo deverá ir "empacotado" na imagem, sem ficar nada "do lado de fora".

Agora chegou o momento de fazer o deploy no Docker Swarm:

$ cd /home/dev/myproject
$ docker stack deploy dj -c stack.yml

É isso. O nome da nossa stack é "dj", e todos os serviços dessa stack serão prefixados com "dj_".

Para monitorar esse processo de subir a stack, eu gosto de manter o comando watch rodando em um terminal separado:

$ watch -n 1 "docker service ls"

Assim eu tenho condições de saber se todos os serviços subiram, e se algum apresentou problemas.

Outro comando muito útil é a exibição de logs de um serviço, e até o momento temos apenas um serviço. Vamos ver o que está acontecendo nele:

$ docker service logs -f dj_worker

Abra o browser de sua preferência no host e tente acessar a página do Django:

http://127.0.0.1:8080

Utilize o comando a seguir para entrar no shell do serviço dj_worker já com o ambiente virtual ativado:

$ docker exec -it $(docker container ls -f name=dj_worker -q) /bin/bash --rcfile /etc/profile --init-file /app/.venv/bin/activate

Se precisar reiniciar o serviço:

$ docker service update dj_worker --force

Se precisar remover a stack:

$ docker stack rm dj

Para fechar essa parte do tutorial com chave de ouro, defina um script, dentro do diretório do projeto, para automatizar o deploy:


#!/usr/bin/env bash
# deploy.sh

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


Por fim, para fazer o deploy basta executar o script:

$ bash deploy.sh

Até o momento, a estrutura do nosso projeto está assim:

 /
 └─ home
     └─ dev
         └─ myproject
             ├─ deploy.sh
             ├─ stack.yml
             ├─ images
             │   └─ Dockerfile
             └─ src
                 ├─ app
                 │   ├─ asgi.py
                 │   ├─ __init__.py
                 │   ├─ settings.py
                 │   ├─ urls.py
                 │   └─ wsgi.py
                 ├─ db.sqlite3
                 ├─ manage.py
                 ├─ requirements.txt
                 ├─ start.sh
                 └─ .venv

Boa sorte :)



CRIANDO UM SERVIÇO DE BANCO DE DADOS E CONECTANDO A APLICAÇÃO DJANGO
--------------------------------------------------------------------

Abra o arquivo compose stack.yml e defina um serviço que vamos chamar de database:


# stack.yml
version: '3.7'

services:

  worker:
    image: myapp
    # Ponto de entrada:
    command: bash /app/start.sh
    stop_signal: SIGINT
    volumes:
      - ${PWD}/src:/app
    ports:
      # host:serviço
      - 8080:8000

  database:
    image: postgres:10
    environment:
      PGDATA: /data
      POSTGRES_PASSWORD: 123
    volumes:
      - ${PWD}/data:/data
    ports:
      - 54321:5432


No diretório do projeto, crie o diretório data.

Até o momento, a estrutura do nosso projeto está assim:

 /
 └─ home
     └─ dev
         └─ myproject
             ├─ data
             ├─ deploy.sh
             ├─ stack.yml
             ├─ images
             │   └─ Dockerfile
             └─ src
                 ├─ app
                 │   ├─ asgi.py
                 │   ├─ __init__.py
                 │   ├─ settings.py
                 │   ├─ urls.py
                 │   └─ wsgi.py
                 ├─ db.sqlite3
                 ├─ manage.py
                 ├─ requirements.txt
                 ├─ start.sh
                 └─ .venv

Note que a porta que estamos utilizando do lado do host é 54321. Pode ser qualquer porta alta, desde que não esteja em uso por outro processo.

Adicione a seguinte linha ao final do arquivo requirements.txt:

psycopg2-binary>=2.9.1

Altere o dicionário DATABASES localizado no arquivo settings.py do Django para que fique da seguinte forma:

DATABASES = {
    'default': {
        'NAME': 'myapp_db',
        'USER': 'postgres',
        'PASSWORD': '123',
        'HOST': 'database',
        'PORT': '5432',
        'CONN_MAX_AGE': 30,
        'ENGINE': 'django.db.backends.postgresql_psycopg2'
    },
}

Suba a stack:

$ docker stack deploy dj -c stack.yml

Instale o cliente PostgreSQL no host:

$ sudo apt install postgresql-client -y

A partir do host, conecte-se ao serviço de banco de dados:

$ psql -h 127.0.0.1 -p 54321 -U postgres

Crie o banco de dados:

postgres=# CREATE DATABASE myapp_db;

Reinicie o worker caso a página do Django esteja inacessível:

$ docker service update dj_worker --force

Abra o browser de sua preferência no host e tente acessar a página do Django:

http://127.0.0.1:8080

Agora que configuramos o Django com o PostgreSQL, não precisamos mais do arquivo SQLite3 gerado pelo Django:

$ cd /home/dev/myproject
$ rm -f src/db.sqlite3




=====================================================


docker run -it --rm alpine ping 8.8.8.8

python manage.py createsuperuser

docker run -it --rm alpine sh -c "echo Hello There!"


