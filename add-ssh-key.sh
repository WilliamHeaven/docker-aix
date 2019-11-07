#!/bin/bash

## Usage: ${PROGNAME} [-u|--user <username>] <public key 1>    \\
##        ${PROGPADD}                        [<public key 2>   \\
##        ${PROGPADD}                        [<public key 3....
##
## Arguments:
## 
##    -u, --user <username>   Add SSH keys for given <username>.
##                            (Default: '${keyuser}'.)
##
##    <public key N>          Public SSH key to add to .authorized_keys.
##
## 
## Usage examples:
##
##    \$ ssh-add -L | xargs -d'\n' ${PROGNAME} -u \$(whoami)
##    \$ ${PROGNAME} "\$(cat ~/.ssh/id_rsa.pub)"
##
##  In docker context:
##
##    \$ ssh-add -L | xargs -d'\n' docker exec aix-7.2 ${PROGNAME} -u \$(whoami)
##    \$ docker exec aix-7.2 ${PROGNAME} "\$(cat ~/.ssh/id_rsa.pub)"
## 
## Blame (most) bugs on: Martin Kjellstrand <martin.kjellstrand@madworx.se>.

: "${keyuser:=root}"

program_path="$0"
usage() {
    export PROGNAME="${program_path##*/}"
    export PROGPADD="${PROGNAME//?/ }"
    export PROGPADD
    (echo "cat <<EOT"
     sed -n 's/^## \?//p' < "${program_path}"
     echo "EOT") > /tmp/.help.$$ ; . /tmp/.help.$$ ; rm /tmp/.help.$$
}

# Parse command line options:
while [ "$#" -gt 0 ] ; do
    case "$1" in
        -u|--user) keyuser="$2" ; shift 2 ;;
        -h|--help) usage ; exit 0 ;;
        -*) echo "Error: Unknown option '$1'." 1>&2 ; usage ; exit 1 ;;
        *) break ;;
    esac
done

userhome=$(awk -F: "\$1==\"${keyuser}\" { print \$6 }" /aix/etc/passwd)

for key in "$@" ; do
    echo "Adding SSH key '${key}' to ${userhome}."
    [ -d "/aix/${keyuser}/.ssh" ] || mkdir -p "/aix/${userhome}/.ssh "
    echo "${key}" >> "/aix/${userhome}/.ssh/authorized_keys"
done
