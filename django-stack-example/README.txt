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

$ pip install -r requirements.txt

Mas no nosso exemplo, esse trabalho será automatizado por um script bash.

Dando continuidade, faça a migração de dados:

(.venv)$ cd /home/dev/myproject/src
(.venv)$ python manage.py migrate

Como o banco de dados ainda é o padrão Django, será criado um arquivo db.sqlite3.

Nesse ponto, a estrutura do nosso projeto deverá estar assim:

/home/dev/myproject
           -> .venv
           -> src
               -> app
                   -> asgi.py
                   -> __init__.py
                   -> settings.py
                   -> urls.py
                   -> wsgi.py
               -> db.sqlite3
               -> manage.py
               -> requirements.txt

Caso deseje, execute o servidor web de desenvolvimento do Django para testar a aplicação:

(.venv)$ cd /home/dev/myproject/src
(.venv)$ python manage.py runserver 0.0.0.0:8080

Saia do ambiente virtual e exclua o diretório .venv (posteriormente, a criação dele será automatizada por um script):

(.venv)$ deactivate
$ rm -rf /home/dev/myproject/.venv

Com a estrutura inicial do nosso projeto pronta, podemos agora focar na criação do serviço docker.

Primeiramente, precisaremos "buildar" uma imagem docker que tenha as ferramentas necessárias para rodar a nossa aplicação.

Apesar de existirem diversas imagens disponívels no site do docker geridas pela comunidade, iremos cria a nossa própria imagem customizada.

Entre no diretório do projeto,

$ cd /home/dev/myproject

E crie um arquivo Dockerfile com o seguinte conteúdo:


FROM ubuntu:20.04

RUN apt update && \
    apt install python3.8 python3-venv -y && \
    apt install inetutils-ping -y

VOLUME /app

WORKDIR /app


A nossa imagem será basicamente um Ubuntu com Python 3 e módulo de virtualenv instalado.

Crie a imagem, que em nosso exemplo chamaremos de myapp:

$ docker build -t myapp .

Com a imagem pronta, agora falta definirmos um arquivo compose que descreverá a nossa stack.

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




docker exec -it $(docker container ls -f name=dj_worker -q) /bin/bash --rcfile /etc/profile --init-file /app/.venv/bin/activate

docker exec -it $(docker container ls -f name=dj_worker -q) bash -c "source /app/.venv/bin/activate; exec /usr/bin/env bash --rcfile <(echo 'PS1=\"(venv)\${PS1}\"') -i"

docker service update dj_worker --force

docker stack rm dj

docker run -it --rm alpine ping 8.8.8.8

python manage.py createsuperuser

docker run -it --rm alpine sh -c "echo Hello There!"



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

Note que a porta que estamos utilizando do lado do host é 54321. Pode ser qualquer porta alta, desde que não esteja em uso por outro processo.

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

Reinicie o worker caso a página do Django esteja inacessível:

docker service update dj_worker --force

