# Project parameters
PROJECT_NAME 		  ?= todobackend
ORG_NAME 			    ?= raj
REPO_NAME 			  ?= todobackend
DOCKER_REGISTERY 	?= docker.io

# Project variables and constants
APP_SERVICE_NAME 	:= app
DEV_COMPOSE_FILE 	:= docker/dev/docker-compose.yml
REL_COMPOSE_FILE 	:= docker/release/docker-compose.yml
DEV_PROJECT 		  := $(PROJECT_NAME)dev
REL_PROJECT 		  := $(PROJECT_NAME)$(BUILD_ID)

# Constants
YELLOW := "\e[1;33m"
NC := "\e[0m"

# Functions
INFO := @bash -c '\
	printf $(YELLOW); \
	echo "=> $$1"; \
	printf $(NC)' VALUE

INSPECT := $$(docker-compose -p $$1 -f $$2 ps -q $$3 | xargs -I ARGS docker inspect -f "{{ .State.ExitCode }}" ARGS)

CHECK := @bash -c '\
	if [[ $(INSPECT) -ne 0 ]]; \
	then exit $(INSPECT); fi' VALUE

# App container ID and image ID
APP_CONTAINER_ID := $$(docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) ps -q $(APP_SERVICE_NAME))
APP_IMAGE_ID := $$(docker inspect -f '{{ .Image}}' $(APP_CONTAINER_ID))

.PHONY: test build release clean tag

test:
	${INFO} "Beginning test phase..."
	${INFO} "Pulling latest images..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) pull	
	${INFO} "Building images..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) build --pull test 
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) build cache
	${INFO} "Ensuring database is ready..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) run --rm agent
	${INFO} "Running tests..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) up test
	${INFO} "Exporting test reports..."
	@ docker cp $$(docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) ps -q test):/reports/. reports
	${CHECK} $(DEV_PROJECT) $(DEV_COMPOSE_FILE) test
	${INFO} "Test phase completed!"

build:
	${INFO} "Starting build phase..."
	${INFO} "Building images..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) build builder
	${INFO} "Building application artifacts..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) up builder
	${CHECK} $(DEV_PROJECT) $(DEV_COMPOSE_FILE) builder
	${INFO} "Copying application artifacts..."
	@ docker cp $$(docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) ps -q test):/wheelhouse/. target
	${INFO} "Build phase completed!"

release:
	${INFO} "Starting release phase..."	
	${INFO} "Pulling latest images..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) pull test		
	${INFO} "Building images..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) build	app
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) build	webroot
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) build --pull nginx 
	${INFO} "Ensuring database is ready..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) run --rm agent
	${INFO} "Collecting and loading static files..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) run --rm app manage.py collectstatic --no-input
	${INFO} "Migrating database schema..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) run --rm app manage.py migrate --no-input
	${INFO} "Running tests..."
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) up test
	${INFO} "Exporting test reports..."
	@ docker cp $$(docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) ps -q test):/reports/. reports
	${CHECK} $(REL_PROJECT) $(REL_COMPOSE_FILE) test
	${INFO} "Release phase completed!"

clean:
	${INFO} "Destroying development environment..."
	@ docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) down -v
	@ docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) down -v
	${INFO} "Clean completed successfully!"

tag:
	${INFO} "Tagging container: $(APP_CONTAINER_ID) of image: $(APP_IMAGE_ID)"
	@ $(foreach tag, $(TAG_ARGS), docker tag $(APP_IMAGE_ID) $(DOCKER_REGISTERY)/$(ORG_NAME)/$(REPO_NAME):$(tag);)

ifeq (tag, $(firstword $(MAKECMDGOALS)))
  TAG_ARGS := $(wordlist 2, $(words $(MAKECMDGOALS)), $(MAKECMDGOALS))	
  ifeq ($(TAG_ARGS), )
    $(error You must specify a tag)
  endif
  $(eval $(TAG_ARGS):;@:)
endif