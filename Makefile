NAME = inception

COMPOSE = docker compose -f src/docker-compose.yml

all: up

up:
	@mkdir -p $(shell grep DATA_PATH src/.env | cut -d '=' -f2)/mariadb
	@mkdir -p $(shell grep DATA_PATH src/.env | cut -d '=' -f2)/wordpress
	$(COMPOSE) up --build -docker

down:
	$(COMPOSE) down

clean: down
	docker system prune -af

fclean: clean
# 	@sudo rm -rf $(shell grep DATA_PATH src/.env | cut -d '=' -f2)/mariadb
# 	@sudo rm -rf $(shell grep DATA_PATH src/.env | cut -d '=' -f2)/wordpress
	podman unshare rm -rf $(DATA_PATH)/mariadb
	podman unshare rm -rf $(DATA_PATH)/wordpress
	docker volume prune -af
	docker volume prune -f

re: fclean all

.PHONY: all up down clean fclean re