# Installing murano as service
## Install murano packages

Enable Openstack repositories:

    $ apt-get  install software-properties-common
    $ add-apt-repository cloud-archive:newton

Then, install murano packages:

    $ apt-get install murano-api murano-engine python-muranoclient

## Create database

To create the database, complete these steps:

Use the database access client to connect to the database server as the root user (specifying the password if required) :

    $ mysql -u root -p

Create the murano database:

    CREATE DATABASE murano;

Grant proper access to the heat database, replacing MURANO_DBPASS with a suitable password:

    GRANT ALL PRIVILEGES ON murano.* TO 'murano'@'localhost' \
    IDENTIFIED BY 'MURANO_DBPASS';

    GRANT ALL PRIVILEGES ON murano.* TO 'murano'@'%' \
    IDENTIFIED BY 'MURANO_DBPASS';


Exit the database access client.

## Create endpoints

Create the application-catalog service API endpoints:

    $ keystone service-create --name application-catalog --type application-catalog \
     --description "application-catalog"

    $ keystone endpoint-create \
     --service-id $(keystone service-list | awk '/ application-catalog / {print $2}') \
     --publicurl http://controller:8082/v1/%\(tenant_id\)s \
     --internalurl http://controller:8082/v1/%\(tenant_id\)s \
     --adminurl http://controller:8082/v1/%\(tenant_id\)s \
     --region regionOne

## Configure murano
Edit the /etc/murano/murano.conf file and complete the following actions:

In the [database] section, configure database access, replacing MURANO_DBPASS with the password you chose for the Murano database:

    [database]
    ...
    connection = mysql://murano:MURANO_DBPASS@controller/murano


In the [DEFAULT] section, configure RabbitMQ message broker access, replacing RABBIT_PASS with
the password you chose for the guest account in RabbitMQ:

    [DEFAULT]
    ...
    rpc_backend = rabbit
    rabbit_host = controller
    rabbit_password = RABBIT_PASS


In the [keystone_authtoken] and [ec2authtoken] sections, configure Identity service access replacing MURANO_PASS
with the password you chose for the heat user in the Identity service:

    [keystone_authtoken]
    ...
    auth_uri = http://controller:5000/v2.0
    identity_uri = http://controller:35357
    admin_tenant_name = service
    admin_user = murano
    admin_password = MURANO_PASS

    [ec2authtoken]
    ...
    auth_uri = http://controller:5000/v2.0

In the murano section, it is required to specified the default region in a multiregion environment

    [murano]

    region_name_for_services = RegionOne

In the rabbitmq section [rabbitmq], which represents the rabbit between murano-engine and virtual machines, add
the information about its hosts, login and password.

    [rabbitmq]
    ...
    host = (the rabbitmq host)
    login = (the RabbitMQ login)
    password = (the RabbitMQ password)

In the engine section, you should specify the folder where Murano core library are configured. For instance, it is
 required for [multiregion](http://docs.openstack.org/developer/murano/articles/multi_region.html).

    [engine]

    class_configs = /etc/murano/class-configs

In this folder, it is possible to specify a file for managing multi-region as io.murano.Environment.yaml, which the content:

    regionConfigs:
    Spain2:
        agentRabbitMq:
            host: RABBIT_HOST
            login: RABBIT_LOGIN
            password: RABBIT_PASSWORD


In the networking section, specify the public network and router to be used.
    [networking]
    ...
    external_network = public-ext-net-01 (the public network)
    router_name = rt2-external (the router name to be created)


### Populate the murano database

Use the following command:

    $ murano-db-manage upgrade

### Import core library.
It is required to obtain the core library which is in [murano repository](https://github.com/openstack/murano/tree/master/meta/io.murano)
We need to execute the zip file for that folder and import in murano by:

    $ murano package-import --exists-action u  --is-public io.murano.zip

For obtaining the files for the murano core library, it is required to obtain the core library from murano OpenStack repository plus the FIWARE
specific requirements. An example to do it can be:

    $ mkdir /murano && cd /murano && git init && git remote add -f origin https://github.com/openstack/murano && git config core.sparseCheckout true && echo "meta/io.murano/" >> .git/info/sparse-checkout && git pull origin stable/newton
    $ mkdir /fiware-murano && cd /fiware-murano && git init && git remote add -f origin https://github.com/telefonicaid/fiware-murano  && git config core.sparseCheckout true && echo "docker/meta/io.murano/" >> .git/info/sparse-checkout && git pull origin develop
    $ cp -rf /fiware-murano/docker/* /murano
    $ echo "  io.murano.resources.FiwareMuranoInstance: resources/FiwareMuranoInstance.yaml" >> /murano/meta/io.murano/manifest.yaml

### Import Murano packages

Import a package from a local .zip file, run:

    $ murano package-import /path/to/PACKAGE.zip

where PACKAGE is the name of the package stored on your computer.

For example:

    $ murano package-import /home/downloads/mysql.zip
    Importing package com.example.databases.MySql
    +---------------------------------+------+----------------------------+--------------+---------+
    | ID                              | Name | FQN                        | Author       |Is Public|
    +---------------------------------+------+----------------------------+--------------+---------+
    | 83e4038885c248e3a758f8217ff8241f| MySQL| com.example.databases.MySql| Mirantis, Inc|         |
    +---------------------------------+------+----------------------------+--------------+---------+

Murano FIWARE packages are in the following [link](https://github.com/telefonicaid/fiware-enablers/tree/develop/murano-apps).

## How to use muranoservice with Docker

Docker allows you to deploy an muranoservice container in a few minutes. This method requires that you have installed docker or can deploy container into the FIWARE Lab (see previous details about it).

Consider this method if you want to try muranoservice and do not want to bother about losing data.

Follow these steps:

1. Download [fiware-murano' source code](https://github.com/telefonicaid/fiware-murano) from GitHub (`git clone https://github.com/telefonicaid/fiware-murano.git`)
2. `cd fiware-murano/docker/muranoservice`
3. Using the command-line and within the directory you created type: `docker build -t muranoservice -f Dockerfile .`.

After a few seconds you should have your fiware-murano image created. Just run the command `docker images` and you see the following response:

    REPOSITORY          TAG                 IMAGE ID            CREATED              SIZE
    muranoservice      latest              bd78d006c2ea        About a minute ago   480.8 MB
    ...

muranoservice image needs the PASSWORD variable to be defined, as well as RABBIT_HOST, RABBIT_LOGIN and RABBIT_PASSWORD for multi-region.
In addition, it needs the docker mysql and rabbitmq alredy deployed.
Thus, to deploy the contanair we need
to execute the command:

    docker run -p 8082:8082 -e PASSWORD=$PASSWORD -e RABBIT_HOST=$RABBIT_HOST -e RABBIT_LOGIN=$RABBIT_LOGIN -e RABBIT_PASSWORD=$RABBIT_PASSWORD --link rabbit --link mysql -d muranoservice

It will launch the muranoservice service
listening on port `8082`, which is linked to mysql and rabbitmq dockers and which has the environment variable password required for configuring murano.

To check that the service is running correcly, just do

	curl <IP address of a machine>:8082

You can obtain the IP address of the machine just executing `docker-machine ip`.

If you want to stop the scenario you have to execute `docker ps` and you see something like this:

    CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                    NAMES
    b8e1de41deb5        muranoservice      "/bin/sh -c ./start.s"   6 minutes ago       Up 6 minutes        0.0.0.0:8082->8082/tcp   fervent_davinci
    ...

Take the Container ID and execute `docker stop b8e1de41deb5` or `docker kill b8e1de41deb5`. Note that you will lose any data that was being used in
muranoservice using this method.

However, there is a simpler way to deploy the container. That is docker-compose and it avoids to deploy containers previously and specifies the port for
murano. It involves just exporting the following variables:

    export PASSWORD=<OpenStack admin user password>
    export RABBIT_HOST=<host where the rabbitmq is located>
    export RABBIT_LOGIN=<login for the rabbitmq>
    export RABBIT_PASSWORD=<password for the rabbitmq>

and executing `docker-compose up -d` to launch the architecture. If you want to check the containers just execute `docker-compose ps`.

        Name                    Command               State                    Ports
    --------------------------------------------------------------------------------------------------
    muranoservice     /bin/sh -c ./start.sh            Up      0.0.0.0:8082->8082/tcp
    mysql             docker-entrypoint.sh mysqld      Up      3306/tcp
    rabbit            /docker-entrypoint.sh rabb ...   Up      25672/tcp, 4369/tcp, 5671/tcp, 5672/tcp


You can take a look to the log generated executing `docker-compose logs`.

