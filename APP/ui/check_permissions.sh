#!/bin/bash

#####################################################################################
#   description:    - runs on DSM7 and above                                        #
#                   - create group docker                                           #
#                   - set docker and admin permission to user synOCR                #
#   path:           /usr/syno/synoman/webman/3rdparty/synOCR/check_permissions.sh   #
#   © 2023 by geimist                                                               #
#####################################################################################

echo -n "    ➜ check docker group and permissions: "
if ! grep -q ^docker: /etc/group ; then
    echo "create group docker ..."
    /usr/syno/sbin/synogroup --add docker
    chown root:docker /var/run/docker.sock
    /usr/syno/sbin/synogroup --member docker synOCR
elif ! grep ^docker: /etc/group | grep -q synOCR ; then
    echo "added user synOCR to group docker ..."
    sed -i "/^docker:/ s/$/,synOCR/" /etc/group
else
    echo "ok [$(grep ^docker: /etc/group)]"
fi

echo -n "    ➜ check admin permissions: "
if ! grep ^administrators /etc/group | grep -q synOCR ; then
    echo "added user synOCR to group administrators ..."
    sed -i "/^administrators:/ s/$/,synOCR/" /etc/group
else
    echo "ok"
fi
