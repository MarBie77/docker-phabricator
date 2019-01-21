# docker-phabricator
Docker image for Phabricator Deployment

## Usage in docker-compose.yml
Nginx and MariaDB-Configs not included.

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

### Known Problems
* Connecting to Diffusion GIT-Server ends with a SEGFAULT in the PHP-script, though everything works fine.