# CIRCd makefile

run:
	carbon circd.lua settings.lua

# Docker
docker:
	docker build -t "carbonsrv/circd" .

docker-run:
	docker run --rm -it -p 6667:6667 -v "`pwd`:/conf" carbonsrv/circd || true

all: run

