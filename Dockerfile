FROM madworx/qemu:latest

MAINTAINER Martin Kjellstrand [https://github.com/madworx]

ENV SYSTEM_MEMORY=2G \
    SYSTEM_CPUS=4 \
    SSH_PUBKEY="" \
    SSH_PORT=22 \
    USER_ID="" \
    USER_NAME=""

ARG AIX_MIRROR=ftp://ftp.software.ibm.com/software/server/diags
ARG AIX_PY=https://worthdoingbadly.com/assets/blog/aixqemu/patch_cd72220.py
ARG AIX_VERSION=7.2
ARG AIX_ARCH=amd64
ARG AIX_SETS="CD72220.iso"
ARG AIX_PKGSRC_PACKAGES="bash"

ENV AIX_ARCH=$AIX_ARCH \
    AIX_VERSION=$AIX_VERSION  \
    PYTHON_VERSION=2.7.17

EXPOSE ${SSH_PORT}
EXPOSE 4444

RUN apk add --no-cache curl unfs3 python37
RUN pkg add python37

RUN set -ex \
	\
	&& wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
	&& wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
	&& gpg --batch --verify python.tar.xz.asc python.tar.xz \
	&& { command -v gpgconf > /dev/null && gpgconf --kill all || :; } \
	&& rm -rf "$GNUPGHOME" python.tar.xz.asc \
	&& mkdir -p /usr/src/python \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz \
	\
	&& cd /usr/src/python \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure \
		--build="$gnuArch" \
		--enable-shared \
		--enable-unicode=ucs4 \
	&& make -j "$(nproc)" \
	&& make install \
	&& ldconfig \
	\
	&& find /usr/local -depth \
		\( \
			\( -type d -a \( -name test -o -name tests \) \) \
			-o \
			\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
		\) -exec rm -rf '{}' + \
	&& rm -rf /usr/src/python \
	\
	&& python2 --version

#
# Download sets:
#
RUN cd /tmp \
    && echo -n "Downloading sets from [${AIX_MIRROR}]:" \
    && for set in ${AIX_SETS} ; do \
        echo -n " ${set}" ; \
        urls="${urls} -O ${AIX_MIRROR}/${set}" ; \
       done \
    && echo "." \
    && curl --fail-early --retry-connrefused --retry 20 ${urls}

#
# Download patch_cd72220.py file:
#
RUN cd /tmp \
    && curl --retry-connrefused --retry 20 -O "${AIX_PY}" \
    && python patch_cd72220.py CD72220.iso ModdedCD.iso

#
# Verify checksum, unpack (and remove) sets:
#
RUN mkdir /aix \
    && cd /aix \
    && for set in ${AIX_SETS} ; do \
           cp /tmp/ModdedCD.iso . || exit 1 ; \
           rm /tmp/${set} ; \
           rm /tmp/ModdedCD.iso ; \
       done

RUN ssh-keygen -f /root/.ssh/id_rsa -N ''

#
# Copy required files:
#
COPY scripts/ /scripts/
COPY docker-entrypoint.sh /
COPY pxeboot_ia32_com0.bin /aix/
COPY add-ssh-key.sh /usr/bin/add-ssh-key
COPY aix.sh /usr/bin/aix

#
# Run the pre-first-boot setup script:
#
RUN /scripts/system-setup.pre.aix

#
# Make one run of /docker-entrypoint.sh, to allow the AIX system to
# configure itself:
#
RUN mv /aix/etc/rc.conf /aix/etc/rc.conf.orig \
    && cp /scripts/configure-system.aix/aix/etc/rc.conf \
    && /docker-entrypoint.sh \
    && mv /aix/etc/rc.conf.orig /aix/etc/rc.conf \
    && test -f /aix/all-ok \
    && rm /aix/all-ok

#
# Run the post-first-boot setup script:
#
RUN /scripts/system-setup.post.aixs

ENTRYPOINT [ "/docker-entrypoint.sh" ]

HEALTHCHECK --timeout=10s --interval=15s \
            --retries=20 --start-period=30s \
            CMD ssh root@localhost -p 22 \
                -oConnectTimeout=5 \
                /bin/echo ok > /dev/null 2>&1
