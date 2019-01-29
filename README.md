# docker-phabricator

Docker image for Phabricator Deployment

## Usage in docker-compose.yml

Nginx and mariaDB-configuration see below!

```yaml
version: '3'

volumes:
  mariadb-data:
  phabricator:
  phabricator-ssh-config:

services:
  nginx:
    image: nginx:latest
    container_name: nginx
    volumes:
      - ./nginx/conf.d/:/etc/nginx/conf.d
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/ssl_config:/etc/nginx/ssl_config
      - ./nginx/static_logging.conf:/etc/nginx/static_logging.conf
      - ./nginx/dhparams.pem:/etc/nginx/dhparams.pem
      - /etc/letsencrypt/:/etc/letsencrypt
      - phabricator:/www/phabricator
    ports:
      - "80:80"
      - "443:443"
    networks:
      app_net:
        ipv4_address: 172.29.0.10

  mariadb:
    container_name: mariadb
    image: mariadb:10
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=SuperSecretPassword!
    volumes:
      - mariadb-data:/var/lib/mysql
      - ./mariadb/conf.d/:/etc/mysql/conf.d
    ports:
      - 3306:3306
    networks:
      app_net:
        ipv4_address: 172.29.0.110

  phabricator:
    container_name: phabricator
    build: ./docker-phabricator/
    depends_on:
      - mariadb
    volumes:
      - phabricator:/var/www/html/
      - phabricator-ssh-config:/etc/ssh/
      - /var/repo:/var/repo
    environment:
      - UPGRADE_ON_RESTART=yes
      - PHAB_PHD_USER=phduser
      - PHAB_DIFFUSION_SSH_PORT=2530
      - PHAB_DIFFUSION_SSH_USER=git
      - PHAB_PHABRICATOR_BASE_URI=https://phabricator.example.com/
      - PHAB_MYSQL_PASS=SuperSecretPassword!
      - PHAB_MYSQL_USER=root
      - PHAB_MYSQL_HOST=mariadb
      - PHAB_STORAGE_MYSQL_ENGINE_MAX_SIZE=8388608
    ports:
      - "2530:2530"
    networks:
      app_net:
        ipv4_address: 172.29.0.130

networks:
  app_net:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 172.29.0.0/16
```

## Volumes

- **/var/www/html**: phabricator files and local config
- **/etc/ssh**: holds sshd-config for diffusion and key files (if keys are not on a volume, the fingerprint of the server will be regenerated on each start)
- **/var/repo**: storage for the git repositories (/var/repo itself must have the permission to be writeable for the docker!)

### Nginx example configuration

nginx configuration example for use of the docker-phabricator image.

```Nginx
server {
    root        /www/phabricator/webroot;

    listen       443 ssl http2;
    server_name  phabricator.example.com;
    index index.php index.html index.htm;

    ssl_certificate "/etc/letsencrypt/live/phabricator.example.com/fullchain.pem";
    ssl_certificate_key "/etc/letsencrypt/live/phabricator.example.com/privkey.pem";
    include /etc/nginx/ssl_config;

    location / {
        index index.php;
        rewrite ^/(.*)$ /index.php?__path__=/$1 last;
    }

    location /index.php {
        fastcgi_pass   phabricator:9000;
        fastcgi_index   index.php;

        #required if PHP was built with --enable-force-cgi-redirect
        fastcgi_param  REDIRECT_STATUS    200;

        #variables to make the $_SERVER populate in PHP
        fastcgi_param  SCRIPT_FILENAME    /var/www/html/phabricator/webroot$fastcgi_script_name;
        fastcgi_param  QUERY_STRING       $query_string;
        fastcgi_param  REQUEST_METHOD     $request_method;
        fastcgi_param  CONTENT_TYPE       $content_type;
        fastcgi_param  CONTENT_LENGTH     $content_length;

        fastcgi_param  SCRIPT_NAME        $fastcgi_script_name;

        fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
        fastcgi_param  SERVER_SOFTWARE    nginx/$nginx_version;

        fastcgi_param  REMOTE_ADDR        $remote_addr;
    }
}
```

### MariaDB-Config

Just one file needed for phabricator config, named phabricator.cnf:

```ini
[mysqld]
sql_mode=STRICT_ALL_TABLES
local_infile=0
max_allowed_packet=33554432
```

### Backup you GIT-Repositories

Do not forget to backup your GIT-repositories (/var/repo)!

## Update Phabricator

Just restart the container and the entrypoint will automatically try to pull the latest code. If anything goes wrong, look into the log of the container.

## Known Problems

- Connecting to Diffusion GIT-Server ends with a SEGFAULT in the PHP-script, though everything works fine.