#!/bin/bash

set -e

DOCKER_IMAGE_NAME=$1
PHP_VERSION=$2
TARGET_PLATFORMS=linux/arm64/v8,linux/amd64

if [ ! -z "$3" ]
then
  TARGET_PLATFORMS=$3
fi

docker buildx create --node buildx --name buildx --use

# we have to do it like this, because of https://github.com/docker/buildx/issues/59#issuecomment-1168619521
for TARGET_PLATFORM in `echo $TARGET_PLATFORMS | tr -s ',' ' '`
do
  TARGET_PLATFORM_SUFFIX=`echo $TARGET_PLATFORM | tr -s '/' '-'`
  docker buildx build --pull --load --platform $TARGET_PLATFORM -f Dockerfile -t ${DOCKER_IMAGE_NAME}-${TARGET_PLATFORM_SUFFIX} --build-arg PHP_VERSION=$PHP_VERSION .
done



