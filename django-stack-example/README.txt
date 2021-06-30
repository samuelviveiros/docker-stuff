CRIANDO UM SERVIÇO PARA UMA APLICAÇÃO DJANGO
--------------------------------------------

O objetivo deste tutorial é montar uma stack bem simples para uma aplicação Django.

O orquestrador que utilizaremos será o Docker Swarm.

Inicialmente, teremos apenas um serviço que representará a nossa aplicação web Django.

Posteriormente adicionaremos outro serviço que fará o papel de servidor de banco de dados.

Para fins didáticos, vamos supor que o nosso usuário Linux se chame dev, de maneira que o diretório home seria: /home/dev

Crie o diretório do projeto. Para o nosso exemplo será:

/home/dev/myproject

Vamos começar criando um ambiente virtual para a nossa aplicação:

$ cd /home/dev/myproject
$ python3 -m venv .venv

Faça a ativação do ambiente virtual:

$ source .venv/bin/activate

Instale a última versão LTS oficial do Django:

(.venv)$ pip install Django==3.2.4

Inicie um novo projeto Django:

$ django-admin startproject app src

Salve as dependências em um arquivo:

(.venv)$ pip freeze > src/requirements.txt

Faça a migração de dados:

(.venv)$ cd /home/dev/myproject/src
(.venv)$ python manage.py migrate

Nesse ponto, a estrutura do nosso deverá estar assim:

/home/dev/myproject
           -> .venv
           -> src
               -> app
                   -> asgi.py
                   -> __init__.py
                   -> settings.py
                   -> urls.py
                   -> wsgi.py
               -> manage.py
               -> requirements.txt

Caso deseje, execute o servidor web de desenvolvimento do Django para testar a aplicação:

(.venv)$ cd /home/dev/myproject/src
(.venv)$ python manage.py runserver 0.0.0.0:8080

Saia do ambiente virtual e exclua o diretório .venv. Posteriormente, ele será criado pelo nosso serviço:

(.venv)$ deactivate
$ rm -rf /home/dev/myproject/.venv

Com a estrutura inicial do nosso projeto pronta, podemos agora focar na criação do serviço docker.

Primeiramente, precisamos de uma imagem docker que tenha as ferramentas necessárias para rodar a nossa aplicação.

Apesar de existirem diversas imagens disponívels no site do docker geridas pela comunidade, iremos cria a nossa própria imagem customizada.

Entre no diretório do projeto:

$ cd /home/dev/myproject

Crie um arquivo Dockerfile com o seguinte conteúdo:


FROM ubuntu:20.04

RUN apt update && \
    apt install python3.8 python3-venv -y && \
    apt install inetutils-ping -y

VOLUME /app

WORKDIR /app


A nossa imagem será basicamente um Ubuntu com Python 3 e módulo de virtualenv instalado.

Crie a imagem. Aqui a chamaremos de myapp:

$ docker build -t myapp .

Com a imagem pronto, agora falta definirmos um arquivo compose que descreverá a nossa stack.

Crie um arquivo chamado stack.yml com o seguinte conteúdo:


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


# start.sh
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


Até o momento, a estrutura do nosso projeto está assim:

/home/dev/myproject
           -> Dockerfile
           -> stack.yml
           -> .venv
           -> src
               -> app
                   -> asgi.py
                   -> __init__.py
                   -> settings.py
                   -> urls.py
                   -> wsgi.py
                   -> start.sh
               -> db.sqlite3
               -> manage.py
               -> requirements.txt





docker exec -it $(docker container ls -f name=dj_worker -q) bash -c "source /app/.venv/bin/activate; exec /usr/bin/env bash --rcfile <(echo 'PS1=\"(venv)\${PS1}\"') -i"

docker service update dj_worker --force

docker stack deploy dj -c stack.yml

docker build -t myapp .

docker stack rm dj

docker run -it --rm -v $(pwd)/src:/app myapp bash

pip install -r requirements.txt

python3 -m venv .venv

pip freeze > requirements.txt

docker run -it --rm alpine ping 8.8.8.8

python manage.py createsuperuser

django-admin startproject app src

pip install django==3.2.4

source .venv/bin/activate

docker service logs -f dj_worker

docker run -it --rm alpine sh -c "echo Hello There!"

watch -n 1 "docker container ls"



CRIANDO UM SERVIÇO DE BANCO DE DADOS E CONECTANDO A APLICAÇÃO DJANGO
--------------------------------------------------------------------

Inclua a seguinte definição de serviço no arquivo compose:


# stack.yml
version: '3.7'

services:

  ...

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

Note que a porta que estamos utilizando do lado do host é 54321.

Adicione a seguinte linha ao final do arquivo requirements.txt:

psycopg2-binary>=2.8.4

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

docker stack deploy dj -c stack.yml

Instale o cliente PostgreSQL no host:

sudo apt install postgresql-client -y

A partir do host, conecte-se ao serviço de banco de dados:

psql -h 127.0.0.1 -p 54321 -U postgres

Crie o banco de dados:

postgres=# CREATE DATABASE myapp_db;

Reinicie o worker caso a página di Django esteja inacessível:

docker service update dj_worker --force

