AIX_VERSION := ${AIX_VERSION}
SHELL := /bin/bash

NETBSD_SETS := "base etc man misc modules text kern-GENERIC"

#
# Please note: Squashing images requires --experimental to be provided to dockerd.
#

all:	build

test:	tests

tests:
	DOCKER_IMAGE="madworx/aix:$(AIX_VERSION)-x86_64" bats tests/*.bats

build:
	docker build --no-cache --build-arg=AIX_VERSION=$(AIX_VERSION) \
	  $$([[ "$${AIX_VERSION}" < "7" ]] && echo "--build-arg=AIX_MIRROR=http://ftp.AIX.org/pub/AIX-archive") \
	  -t `echo "madworx/aix:$(AIX_VERSION)-x86_64" | tr '[:upper:]' '[:lower:]'` . || exit 1 ; \

run:
	echo "Starting AIX container(s)..."
	port=2221 ; for v in $(VERSIONS) ; do \
		docker stop aix-$$v >/dev/null 2>&1 || true ; \
		docker rm aix-$$v >/dev/null 2>&1 || true ; \
		let "port++" ; \
		docker run \
			-d \
			-e "SSH_PUBKEY=\"`ssh-add -L`\"" \
			-e "USER_ID=$${UID}" \
			-e "USER_NAME=$${USER}" \
			-p $$port:22 \
			-v $${HOME}:/aix/home/$${USER} \
			--privileged \
			--hostname qemu-aix-$$v-`uname -m` \
			--name aix-$$v \
			madworx/aix:$$v-`uname -m` ; \
	done

push:
	docker push `echo "madworx/aix:$(AIX_VERSION)-x86_64" | tr '[:upper:]' '[:lower:]'`

shell:
	docker exec -it AIX-7.1.2 /usr/bin/aix /bin/sh

check:
	port=2221 ; for v in $(VERSIONS) ; do \
		let "port++" ; \
		ssh localhost -p $${port} uname -a ; \
	done

.PHONY: tests test
