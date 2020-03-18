DOCKER_USER:=connesc
DOCKER_ORGANIZATION=connesc
DOCKER_NAME:=archlinux
DOCKER_ARCH:=arm64
DOCKER_MANIFEST_ARCHS:=amd64 arm64

DOCKER_IMAGE:=$(DOCKER_ORGANIZATION)/$(DOCKER_NAME)
DOCKER_TAG:=$(DOCKER_IMAGE):$(DOCKER_ARCH)

DOCKER_MANIFEST:=$(DOCKER_IMAGE):latest
DOCKER_MANIFEST_TAGS:=$(DOCKER_MANIFEST_ARCHS:%=$(DOCKER_IMAGE):%)

rootfs:
	$(eval TMPDIR := $(shell mktemp -d))
	env -i pacstrap -C /usr/share/devtools/pacman-extra.conf -c -d -G -M $(TMPDIR) $(shell cat packages)
	cp --recursive --preserve=timestamps --backup --suffix=.pacnew rootfs/* $(TMPDIR)/
	arch-chroot $(TMPDIR) locale-gen
	arch-chroot $(TMPDIR) pacman-key --init
	arch-chroot $(TMPDIR) pacman-key --populate archlinuxarm
	tar --numeric-owner --xattrs --acls --exclude-from=exclude -C $(TMPDIR) -c . -f archlinux.tar
	rm -rf $(TMPDIR)

docker-image: rootfs
	docker build -t $(DOCKER_TAG) .

docker-image-test: docker-image
	# FIXME: /etc/mtab is hidden by docker so the stricter -Qkk fails
	docker run --rm $(DOCKER_TAG) sh -c "/usr/bin/pacman -Sy && /usr/bin/pacman -Qqk"
	docker run --rm $(DOCKER_TAG) sh -c "/usr/bin/pacman -Syu --noconfirm docker && docker -v"
	# Ensure that the image does not include a private key
	! docker run --rm $(DOCKER_TAG) pacman-key --lsign-key pierre@archlinux.de
	docker run --rm $(DOCKER_TAG) sh -c "/usr/bin/id -u http"
	docker run --rm $(DOCKER_TAG) sh -c "/usr/bin/pacman -Syu --noconfirm grep && locale | grep -q UTF-8"

ci-test:
	docker run --rm --privileged --tmpfs=/tmp:exec --tmpfs=/run/shm -v /run/docker.sock:/run/docker.sock \
		-v $(PWD):/app -w /app $(DOCKER_TAG) \
		sh -c 'pacman -Syu --noconfirm make devtools docker && make docker-image-test'

docker-push:
	#docker login -u $(DOCKER_USER)
	docker push $(DOCKER_TAG)

docker-manifest:
	docker manifest create -a $(DOCKER_MANIFEST) $(DOCKER_MANIFEST_TAGS)
	for ARCH in $(DOCKER_MANIFEST_ARCHS); do docker manifest annotate --arch $${ARCH} $(DOCKER_MANIFEST) $(DOCKER_IMAGE):$${ARCH}; done

docker-manifest-push:
	#docker login -u $(DOCKER_USER)
	docker push $(DOCKER_MANIFEST)

.PHONY: rootfs docker-image docker-image-test ci-test docker-push docker-manifest docker-manifest-push
