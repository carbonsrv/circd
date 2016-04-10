# CIRCd makefile

docker:
	docker build -t "carbonsrv/circd" .

docker-run:
	docker run --rm -it -p 6667:6667 carbonsrv/circd

all: docker

