#! /bin/bash

#
# The variables given below will be set in the target AIX operating
# system  (by  way of  /aix/etc/startup.vars,  which  is invoked  from
# /etc/rc.local).
#
EXPORT_VARS="SSH_PUBKEY SSH_PORT AIX_ARCH AIX_VERSION PKG_PATH USER_ID USER_NAME"

#
# Generate /etc/startup.vars file before booting into AIX:
#
echo '### THIS FILE IS AUTO-GENERATED UPON BOOT. DO NOT EDIT! ###' > /aix/etc/startup.vars
for var in ${EXPORT_VARS} ; do
    echo "${var}='${!var}'" >> /aix/etc/startup.vars
    echo "export ${var}" >> /aix/etc/startup.vars
done

#
# Fix AIX /etc/resolv.conf:
#
# (This assumes that  our local resolv.conf doesn't  contain any wonky
# Linux-specific options)
#
cp /etc/resolv.conf /aix/etc/resolv.conf

#
# If we have SSH_PUBKEY set, add that key to authorized_keys.
#
[ -z "${SSH_PUBKEY}" ] || add-ssh-key "${SSH_PUBKEY}"


#
# Start userspace NFS server on Linux end.
#
rpcbind -h 127.0.0.1
unfsd   -l 127.0.0.1

# Parse command line arguments:
QUIET=0
if [ ! -z "$*" ] ; then
    while [ "$#" -gt 0 ] ; do
        case "$1" in
            -q) QUIET=$(($QUIET+1)) ; shift ;;
            -*) echo "Unknown option \`$1'." ; exit 1 ;;
            *) QUIET=$(($QUIET+1)) ; break ;;
        esac
    done
fi

#
# If we have KVM available, enable it:
#
if dd if=/dev/kvm count=0 >/dev/null 2>&1 ; then
    echo "KVM Hardware acceleration will be used."
    ENABLE_KVM="-enable-kvm"
else
    if [ "${QUIET}" -lt 2 ] ; then
        echo "Warning: Lacking KVM support - slower(!) emulation will be used." 1>&2
        sleep 1
    fi
    ENABLE_KVM=""
fi


#
# Shut down gracefully by connecting to the QEMU monitor and issue the
# shutdown command there.
#
trap "{ echo \"Shutting down gracefully...\" 1>&2 ; \
        echo -e \"system_powerdown\\n\\n\" | nc localhost 4444 ; \
        wait ; \
        echo \"Will now exit entrypoint.\" 1>&2 ; \
        exit 0 ; }" TERM

#
# Boot up AIX by starting QEMU.
#
(
    qemu-system-ppc64 -cpu POWER9 -machine pseries -m 2G -serial mon:stdio \
		-cdrom ModdedCD.iso \
		-d guest_errors \
		-prom-env "input-device=/vdevice/vty@71000000" \
		-prom-env "output-device=/vdevice/vty@71000000" \
		-prom-env "boot-command=dev / 0 0 s\" ibm,aix-diagnostics\" property boot cdrom:\ppc\chrp\bootfile.exe -s verbose"  \
		-monitor telnet:0.0.0.0:4444,server,nowait \
		-netdev user,id=mynet0,net=192.168.76.0/24,dhcpstart=192.168.76.9,hostfwd=tcp::${SSH_PORT}-:22,tftp=/aix,bootfile=pxeboot_ia32_com0.bin,rootpath=/aix -device e1000,netdev=mynet0 
) &

if [ ! -z "$*" ] ; then
    /usr/bin/aix $*
    exit $?
fi

wait
