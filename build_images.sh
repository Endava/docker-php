#!/bin/bash

set -e

DOCKER_IMAGE_NAME=$1
TARGET_PLATFORMS=linux/arm64/v8,linux/amd64

if [ ! -z "$2" ]
then
  TARGET_PLATFORMS=$2
fi

docker buildx create --node buildx --name buildx --use

# we have to do it like this, because of https://github.com/docker/buildx/issues/59#issuecomment-1168619521
for TARGET_PLATFORM in `echo $TARGET_PLATFORMS | tr -s ',' ' '`
do
  TARGET_PLATFORM_SUFFIX=`echo $TARGET_PLATFORM | tr -s '/' '-'`
  docker buildx build --pull --load --platform $TARGET_PLATFORM -f Dockerfile -t ${DOCKER_IMAGE_NAME}-${TARGET_PLATFORM_SUFFIX} .

  for SUFFIX in unit fpm apache2
  do
    cat Dockerfile > Dockerfile-${SUFFIX}
    echo "" >> Dockerfile-${SUFFIX}
    cat files/$SUFFIX/$SUFFIX.Dockerfile.snippet.txt >> Dockerfile-${SUFFIX}

    docker buildx build --pull --load --platform $TARGET_PLATFORM -f Dockerfile-${SUFFIX} -t ${DOCKER_IMAGE_NAME}-${SUFFIX}-${TARGET_PLATFORM_SUFFIX} .
    rm Dockerfile-${SUFFIX}
  done
done