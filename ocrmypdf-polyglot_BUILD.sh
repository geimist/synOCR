#!/bin/bash
#################################################################################
#   2021-04-17                                                                  #
#   v1.0.0                                                                      #
#   © 2021 by geimist                                                           #
#                                                                               #
#   This script check for new jbarlow83/OCRmyPDF-imgage and adds                #
#   all tesseract languages to it.                                              #
#                                                                               #
#################################################################################


# https://www.scalyr.com/blog/create-docker-image/


docker_hub_user="<user>"
docker_hub_pw="<PW>"

use_apt_cacher=1
apt_cache_dir="/volume1/system/CACHE_apt-cacher-ng"

# --------------------------------------------------------------
FILEPATH="$0"
execute=0
date_start=$(date +%s)

# Timestamp update :latest:
    stored_latest_last_updated="2021-04-16T08:25:35.854736Z"
# Timestamp update newst tag:
    stored_tag_last_updated="2021-04-14T08:27:58.336929Z"
# newst tag:
    stored_tag_newest="v12.0.0b2"

sec_to_time() 
{
# this function converts a second value to hh:mm:ss
# call: sec_to_time "string"
# https://blog.jkip.de/in-bash-sekunden-umrechnen-in-stunden-minuten-und-sekunden/
# --------------------------------------------------------------
    local seconds=$1
    local sign=""
    if [[ ${seconds:0:1} == "-" ]]; then
        seconds=${seconds:1}
        sign="-"
    fi
    local hours=$(( seconds / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))
    seconds=$(( seconds % 60 ))
    printf "%s%02d:%02d:%02d" "$sign" $hours $minutes $seconds
}

# Variante 1 - veraltet::
docker_run () {
    # Variante 1 (aktive Erweiterung):
    # start einen tmp Container / installiere alle Sprachen: 
        { echo "docker run -i --entrypoint bash --name DEVpolyglot jbarlow83/ocrmypdf:$BuildVersion"
          echo "apt-get update && apt-get install -y apt-transport-https"
          echo "apt-get install -y tesseract-ocr-all"
          echo "exit"
        } | bash
    
        # erstelle neues Image:
            docker commit --change='ENTRYPOINT ["/usr/local/bin/ocrmypdf"]' DEVpolyglot geimist/ocrmypdf-polyglot:${BuildVersion##*v}
            docker rm DEVpolyglot
}

# Variante 2 (mit Dockerfile):
docker_build () {
    # Variante 2 (mit Dockerfile - Einstellungen des Quellimages bleiben erhalten):
    # temporäres Verzeichnis erstellen:
        printf "\n    erstelle Dockerfile ..."
        work_tmp=$(mktemp -d -t tmp.XXXXXXXXXX)
        trap 'rm -rf "$work_tmp"; exit' EXIT
        dockerfile=$work_tmp/dockerfile
        
    # erstelle Dockerfile:
        echo "FROM jbarlow83/ocrmypdf:$BuildVersion" > $dockerfile
#       echo "RUN apt-get update && apt-get install -y apt-transport-https" >> $dockerfile

        # soll apt-cacher-ng genutzt werden?:
        if [ $use_apt_cacher = 1 ] ; then
            echo -n "                      ➜ nutze apt-cacher-ng ..."
            if ! /usr/local/bin/docker container ls -a | grep -q "apt-cacher-ng" ; then
                echo "(is running)"
            else
                echo "(started)"
                # https://registry.hub.docker.com/r/sameersbn/apt-cacher-ng/
                /usr/local/bin/docker run --name apt-cacher-ng --init -d -rm \
                    --publish 3142:3142 \
                    --volume "${apt_cache_dir}":/var/cache/apt-cacher-ng \
                    sameersbn/apt-cacher-ng:latest

    #            until [ "`docker inspect -f {{.State.Running}} apt-cacher-ng`"=="true" ]; do
    #                sleep 0.1;
    #            done
            fi
            echo "RUN echo 'Acquire::HTTP::Proxy \"http://172.17.0.1:3142\";' >> /etc/apt/apt.conf.d/01proxy && echo 'Acquire::HTTPS::Proxy \"false\";' >> /etc/apt/apt.conf.d/01proxy" >> $dockerfile
        fi

        echo "RUN apt-get update" >> $dockerfile
        echo "RUN apt-get install -y tesseract-ocr-all" >> $dockerfile

    # hole aktuelles Image:
        echo "    hole aktuelles Image [jbarlow83/ocrmypdf:$BuildVersion] ..."
        docker pull "jbarlow83/ocrmypdf:$BuildVersion"

    # baue Image:
        echo "    baue Image ..."
        docker build -f $dockerfile -t geimist/ocrmypdf-polyglot:${BuildVersion##*v} .

    # temporäres Arbeitsverzeichnis löschen:
        rm -rf "$work_tmp"
}

# lade neues Image in DockerHub:
docker_push () {
    echo "   LogIn DockerHub ..."
    echo "$docker_hub_pw" | docker login --username "$docker_hub_user" --password-stdin
    echo "    push Image ..."
    docker push geimist/ocrmypdf-polyglot:${BuildVersion##*v}
}

# purge images:
purge_images (){
# stop apt-cache:
    [ $use_apt_cacher = 1 ] && printf "\n    clean up images:\n" && /usr/local/bin/docker container stop apt-cacher-ng
# step 1:
    /usr/local/bin/docker image prune -f
# step 2:
    for i in $(/usr/local/bin/docker images --filter "dangling=true" --format "{{.ID}}:{{.Repository}}:{{.Tag}}" | grep "<none>");do
        /usr/local/bin/docker image rm -f $(echo "$i" | awk '-F:' '{print $1}')
    done
}


if [ -z $1 ] ; then
    echo "Buildversion:         ➜ auto"

    # check for new tag:
#   tag_last_updated=$(curl -s "https://hub.docker.com/v2/repositories/jbarlow83/ocrmypdf/tags/?page=2&page_size=1&ordering=last_updated" | jq -r ".results[0].last_updated")
#   tag_newest=$(curl -s "https://hub.docker.com/v2/repositories/jbarlow83/ocrmypdf/tags/?page=2&page_size=1&ordering=last_updated" | jq -r ".results[0].name")
    tag_newest=$(curl -s "https://hub.docker.com/v2/repositories/jbarlow83/ocrmypdf/tags/" | jq -r ".results[].name" | egrep "v[[:digit:]]" | sort -r | head -n1)
    tag_last_updated=$(curl -s "https://hub.docker.com/v2/repositories/jbarlow83/ocrmypdf/tags/" | jq -r '.results[] | select(.name=="'${tag_newest}'") | .last_updated')

    echo -n "check for new tag     ➜ "
    if [[ "$tag_last_updated" != "$stored_tag_last_updated" ]] && [ -n "$tag_last_updated" ]; then
        execute=1
        echo "new release found:"
        echo "    last release:       $stored_latest_last_updated ($stored_tag_newest)"
        echo "    current release:    $tag_last_updated ($tag_newest)"

        BuildVersion=$tag_newest
        docker_build

        if [ $? = 0 ]; then
            docker_push
            if [ $? = 0 ]; then
                synosetkeyvalue $FILEPATH stored_tag_last_updated "$tag_last_updated"
                synosetkeyvalue $FILEPATH stored_tag_newest "$tag_newest"
                echo 2 > /dev/ttyS1 #short beep
            else
                echo "    ! exit with error (docker_push)"
                exit 1
            fi
        else
            echo "    ! exit with error (docker_build)"
            exit 1
        fi
    else
        echo "up to date ($stored_tag_newest)"
    fi

    # get current releases:
#   latest_last_updated=$(curl -s "https://hub.docker.com/v2/repositories/jbarlow83/ocrmypdf/tags/?page=1&page_size=1&ordering=last_updated" | jq -r ".results[0].last_updated")
    latest_last_updated=$(curl -s "https://hub.docker.com/v2/repositories/jbarlow83/ocrmypdf/tags/" | jq -r '.results[] | select(.name=="latest") | .last_updated')

    echo -n "check for tag: latest ➜ "
    if [[ "$latest_last_updated" != "$stored_latest_last_updated" ]] && [ -n "$latest_last_updated" ]; then
        execute=1
        echo "new release found:"
        echo "    last release:       $stored_latest_last_updated"
        echo "    current release:    $latest_last_updated"

        BuildVersion=latest
        docker_build

        if [ $? = 0 ]; then
            docker_push
            if [ $? = 0 ]; then
                synosetkeyvalue $FILEPATH stored_latest_last_updated "$latest_last_updated"
                echo 2 > /dev/ttyS1 #short beep
            else
                echo "    ! exit with error (docker_push)"
                exit 1
            fi
        else
            echo "    ! exit with error (docker_build)"
            exit 1
        fi
    else
        echo "up to date"
    fi
elif [ $1 = latest ] ; then
    execute=1

    BuildVersion=latest
    echo "BuildVersion: $BuildVersion"
    docker_build
    if [ $? = 0 ]; then
        docker_push
        if [ $? = 0 ]; then
            echo 2 > /dev/ttyS1 #short beep
        else
            echo "    ! exit with error (docker_push)"
            exit 1
        fi
    else
        echo "    ! exit with error (docker_build)"
        exit 1
    fi
else
    execute=1

    BuildVersion=$1
    echo "BuildVersion: $BuildVersion"
    docker_build
    if [ $? = 0 ]; then
        docker_push
        if [ $? = 0 ]; then
            echo 2 > /dev/ttyS1 #short beep
        else
            echo "    ! exit with error (docker_push)"
            exit 1
        fi
    else
        echo "    ! exit with error (docker_build)"
        exit 1
    fi
fi

if [[ $proxy_state_enabled = no ]] ; then
    echo "    stop proxy ...    "
    "/volume1/homes/admin/script/_funktionen/set-proxy.sh" -d  > /dev/null  2>&1
fi


if [[ $execute = 1 ]] ; then
    purge_images
fi

# Delete empty logs:
LOGDIR="/volume1/system/@Logfiles/OCRmyPDF-polyglot_BUILD/"
for i in $(ls -tr "${LOGDIR}" | egrep -o '^OCRmyPDF-polyglot_BUILD.*.log$'); do
    if [ $( cat "${LOGDIR}$i" | wc -l ) -lt 5 ] ; then
        rm -f "${LOGDIR}$i"
    fi
done

echo "duration:             ➜ $(sec_to_time $(expr $(date +%s)-${date_start}))"

exit
