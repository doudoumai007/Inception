NAME = inception

COMPOSE = docker compose -f srcs/docker-compose.yml

DATA_PATH = /home/peiyli/data

all: up

up:
	@mkdir -p $(shell grep DATA_PATH srcs/.env | cut -d '=' -f2)/mariadb
	@mkdir -p $(shell grep DATA_PATH srcs/.env | cut -d '=' -f2)/wordpress
	$(COMPOSE) up --build -d

down:
	$(COMPOSE) down

clean: down
	docker system prune -af

fclean: clean
	@sudo rm -rf $(shell grep DATA_PATH srcs/.env | cut -d '=' -f2)/mariadb
	@sudo rm -rf $(shell grep DATA_PATH srcs/.env | cut -d '=' -f2)/wordpress
	docker volume prune -f
	docker network prune -f

re: fclean all

.PHONY: all up down clean fclean re