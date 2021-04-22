#!/bin/bash
#################################################################################
#   2021-04-22                                                                  #
#   v1.0.2                                                                      #
#   © 2021 by geimist                                                           #
#                                                                               #
#   This script check for new jbarlow83/OCRmyPDF-imgage and adds                #
#   all tesseract languages to it.                                              #
#                                                                               #
#################################################################################


# https://www.scalyr.com/blog/create-docker-image/
# /volume1/homes/admin/script/DEV_ocrmypdf-polyglot_BUILD.sh


docker_hub_user="<user>"
docker_hub_pw="<PW>"

use_apt_cacher=1
apt_cache_dir="/volume1/system/CACHE_apt-cacher-ng"

# --------------------------------------------------------------

FILEPATH="$0"
execute=0
date_start=$(date +%s)

# Timestamp update :latest:
    stored_latest_last_updated="2021-04-22T07:14:44.252812Z"
# Timestamp update newst tag:
    stored_tag_last_updated="2021-04-22T08:06:49.330058Z"
# newst tag:
    stored_tag_newest="v12.0.0b4"

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

# variant 1 -  (active upgrade - deprecated):
docker_run () {
    # start a tmp container / install all languages: 
        { echo "docker run -i --entrypoint bash --name DEVpolyglot jbarlow83/ocrmypdf:$BuildVersion"
          echo "apt-get update && apt-get install -y apt-transport-https"
          echo "apt-get install -y tesseract-ocr-all"
          echo "exit"
        } | bash
    
        # create new image:
            docker commit --change='ENTRYPOINT ["/usr/local/bin/ocrmypdf"]' DEVpolyglot ${docker_hub_user}/ocrmypdf-polyglot:${BuildVersion##*v}
            docker rm DEVpolyglot
}

# variant 2 (with dockerfile - settings of the source image are persisted):
docker_build () {
    # create temporary directory:
        printf "\n ---> erstelle Dockerfile ..."
        work_tmp=$(mktemp -d -t tmp.XXXXXXXXXX)
        trap 'rm -rf "$work_tmp";grep -q "apt-cacher-ng" <<< "$(/usr/local/bin/docker container ls -a)"; [ $? = 0 ] && /usr/local/bin/docker container stop apt-cacher-ng; exit' EXIT
        dockerfile=$work_tmp/dockerfile
        
    # create dockerfile:
        echo "FROM jbarlow83/ocrmypdf:$BuildVersion" > $dockerfile

        # should apt-cacher-ng be used?:
        if [ $use_apt_cacher = 1 ] ; then
            printf "\n                      ➜ use apt-cacher-ng ..."
            if /usr/local/bin/docker container ls -a | grep -q "apt-cacher-ng" ; then
                echo "(is running)"
            else
                echo "(started)"
                # https://registry.hub.docker.com/r/sameersbn/apt-cacher-ng/
                /usr/local/bin/docker run --name apt-cacher-ng --init -d --rm \
                    --publish 3142:3142 \
                    --volume "${apt_cache_dir}":/var/cache/apt-cacher-ng \
                    sameersbn/apt-cacher-ng:latest

                count=0
                until [ "$(docker inspect -f {{.State.Running}} apt-cacher-ng  2>/dev/null)" = "true" ] ; do
                    sleep 0.1;
                    count=$(($count + 1))
                    # check 60 seconds for start of apt-cacher-ng
                    [ $count = 600 ] && echo "                        ERROR! start of apt-cacher-ng failed!" && use_apt_cacher=0 && break
                done
            fi
            [ $use_apt_cacher = 1 ] && echo "RUN echo 'Acquire::HTTP::Proxy \"http://172.17.0.1:3142\";' >> /etc/apt/apt.conf.d/01proxy && echo 'Acquire::HTTPS::Proxy \"false\";' >> /etc/apt/apt.conf.d/01proxy" >> $dockerfile
        fi

#        echo "RUN apt-get update" >> $dockerfile
        echo "RUN apt-get update && apt-get install -y apt-transport-https" >> $dockerfile
        echo "RUN apt-get install -y tesseract-ocr-all" >> $dockerfile

    # pull current image:
        printf "\n ---> hole aktuelles Image [jbarlow83/ocrmypdf:$BuildVersion] ...\n"
        docker pull "jbarlow83/ocrmypdf:$BuildVersion"

    # build image:
        printf "\n ---> baue Image ...\n"
        docker build -f $dockerfile -t ${docker_hub_user}/ocrmypdf-polyglot:${BuildVersion##*v} .

    # delete temp. workdir:
        rm -rf "$work_tmp"
}

# push new image to docker hub:
docker_push () {
    printf "\n ---> LogIn DockerHub ...\n"
    echo "$docker_hub_pw" | docker login --username "$docker_hub_user" --password-stdin
    printf "\n ---> push Image ...\n"
    docker push ${docker_hub_user}/ocrmypdf-polyglot:${BuildVersion##*v}
}

# purge images:
purge_images (){
# stop apt-cache:
    [ $use_apt_cacher = 1 ] && printf "\n ---> clean up images:\n" && /usr/local/bin/docker container stop apt-cacher-ng
# step 1:
    /usr/local/bin/docker image prune -f
# step 2:
    for i in $(/usr/local/bin/docker images --filter "dangling=true" --format "{{.ID}}:{{.Repository}}:{{.Tag}}" | grep "<none>");do
        /usr/local/bin/docker image rm -f $(echo "$i" | awk '-F:' '{print $1}')
    done
}


if [ -z $1 ] ; then
    printf "\n ---> Buildversion:         ➜ auto\n"

    # check for new tag:
    tag_newest=$(curl -s "https://hub.docker.com/v2/repositories/jbarlow83/ocrmypdf/tags/" | jq -r ".results[].name" | egrep "v[[:digit:]]" | head -n1)
    tag_last_updated=$(curl -s "https://hub.docker.com/v2/repositories/jbarlow83/ocrmypdf/tags/" | jq -r '.results[] | select(.name=="'${tag_newest}'") | .last_updated')

    echo -n " ---> check for new tag     ➜ "
    if [[ "$tag_last_updated" != "$stored_tag_last_updated" ]] && [ -n "$tag_last_updated" ]; then
        execute=1
        echo "new release found:"
        echo "     ---> last release:       $stored_latest_last_updated ($stored_tag_newest)"
        echo "     ---> current release:    $tag_last_updated ($tag_newest)"

        BuildVersion=$tag_newest
        docker_build

        if [ $? = 0 ]; then
            docker_push
            if [ $? = 0 ]; then
                synosetkeyvalue $FILEPATH stored_tag_last_updated "$tag_last_updated"
                synosetkeyvalue $FILEPATH stored_tag_newest "$tag_newest"
                echo 2 > /dev/ttyS1 #short beep
            else
                echo "     ---> ! exit with error (docker_push)"
                exit 1
            fi
        else
            echo "     ---> ! exit with error (docker_build)"
            exit 1
        fi
    else
        echo "up to date ($stored_tag_newest)"
    fi

    # get current releases:
    latest_last_updated=$(curl -s "https://hub.docker.com/v2/repositories/jbarlow83/ocrmypdf/tags/" | jq -r '.results[] | select(.name=="latest") | .last_updated')

    echo -n " ---> check for tag: latest ➜ "
    if [[ "$latest_last_updated" != "$stored_latest_last_updated" ]] && [ -n "$latest_last_updated" ]; then
        execute=1
        echo "new release found:"
        echo "     ---> last release:       $stored_latest_last_updated"
        echo "     ---> current release:    $latest_last_updated"

        BuildVersion=latest
        docker_build

        if [ $? = 0 ]; then
            docker_push
            if [ $? = 0 ]; then
                synosetkeyvalue $FILEPATH stored_latest_last_updated "$latest_last_updated"
                echo 2 > /dev/ttyS1 #short beep
            else
                echo "     ---> ! exit with error (docker_push)"
                exit 1
            fi
        else
            echo "     ---> ! exit with error (docker_build)"
            exit 1
        fi
    else
        echo "up to date"
    fi
elif [ $1 = latest ] ; then
    execute=1

    BuildVersion=latest
    printf "\n ---> BuildVersion: $BuildVersion"
    docker_build
    if [ $? = 0 ]; then
        docker_push
        if [ $? = 0 ]; then
            echo 2 > /dev/ttyS1 #short beep
        else
            echo "     ---> ! exit with error (docker_push)"
            exit 1
        fi
    else
        echo "     ---> ! exit with error (docker_build)"
        exit 1
    fi
else
    execute=1

    BuildVersion=$1
    printf "\n ---> BuildVersion: $BuildVersion"
    docker_build
    if [ $? = 0 ]; then
        docker_push
        if [ $? = 0 ]; then
            echo 2 > /dev/ttyS1 #short beep
        else
            echo "     ---> ! exit with error (docker_push)"
            exit 1
        fi
    else
        echo "     ---> ! exit with error (docker_build)"
        exit 1
    fi
fi

if [[ $proxy_state_enabled = no ]] ; then
    printf "\n ---> stop proxy ...    "
    "/volume1/homes/admin/script/_funktionen/set-proxy.sh" -d  > /dev/null  2>&1
fi


if [[ $execute = 1 ]] ; then
    purge_images
fi

# delete empty logs:
LOGDIR="/volume1/system/@Logfiles/OCRmyPDF-polyglot_BUILD/"
for i in $(ls -tr "${LOGDIR}" | egrep -o '^OCRmyPDF-polyglot_BUILD.*.log$'); do
    if [ $( cat "${LOGDIR}$i" | wc -l ) -lt 5 ] ; then
        rm -f "${LOGDIR}$i"
    fi
done

printf "\n ---> duration:             ➜ $(sec_to_time $(expr $(date +%s)-${date_start}))\n"

exit

