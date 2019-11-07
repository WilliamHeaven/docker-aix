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

RUN apk add --no-cache curl unfs3 python

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
RUN cp /scripts/configure-system.aix /aix/etc/rc.conf \
    && /docker-entrypoint.sh \
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
