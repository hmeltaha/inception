
COMPOSE = docker compose -f srcs/docker-compose.yml --env-file srcs/.env

all: up

up:
	mkdir -p /home/hmeltaha/data/mariadb
	mkdir -p /home/hmeltaha/data/wordpress
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

logs:
	$(COMPOSE) logs -f

clean:
	$(COMPOSE) down --remove-orphans

fclean:
	$(COMPOSE) down --rmi all --volumes --remove-orphans

re: fclean all

.PHONY: all up down stop start logs clean fclean re
