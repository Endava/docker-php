#!/usr/bin/env bash

set -e

PHP_VERSION=`docker run --rm -it $1 php -r 'echo PHP_VERSION;'`

if [ -z "$PHP_VERSION" ]
then
  echo "Cannot find PHP version in docker image $1"
  exit 1;
fi

DOCKER_IMAGE_NAME=$2:$PHP_VERSION
QUAY_DOCKER_IMAGE_NAME=quay.io/$DOCKER_IMAGE_NAME
TARGET_PLATFORMS=linux/arm64/v8,linux/amd64

if [ ! -z "$2" ]
then
  TARGET_PLATFORMS=$2
fi

# we have to do it like this, because of https://github.com/docker/buildx/issues/59#issuecomment-1168619521
echo "Build and Push ${DOCKER_IMAGE_NAME}"
docker buildx create --node buildx --name buildx --use
docker buildx build --push --platform $TARGET_PLATFORMS -f Dockerfile -t $DOCKER_IMAGE_NAME
echo "Build and Push ${QUAY_DOCKER_IMAGE_NAME}"
docker buildx build --push --platform $TARGET_PLATFORMS -f Dockerfile -t $QUAY_DOCKER_IMAGE_NAME
