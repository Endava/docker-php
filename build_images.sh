#!/bin/bash

set -e

DOCKER_IMAGE_NAME=$1
ALPINE_VERSION=$2
PHP_VERSION=$3
DOCKER_FILE_FOLDER=`echo "$PHP_VERSION" | cut -f 1-2 -d '.'`
PHP_PACKAGE_BASENAME=$4
UNIT_VERSION=$5
APACHE2_VERSION=$6
TARGET_PLATFORMS=linux/arm64/v8,linux/amd64

if [ ! -z "$7" ]
then
  TARGET_PLATFORMS=$7
fi

cp -rf ./unit-default.json $DOCKER_FILE_FOLDER/
cp -rf ./apache2-default.conf $DOCKER_FILE_FOLDER/
cp -rf ./php.ini $DOCKER_FILE_FOLDER/

docker buildx create --node buildx --name buildx --use

# we have to do it like this, because of https://github.com/docker/buildx/issues/59#issuecomment-1168619521
for TARGET_PLATFORM in `echo $TARGET_PLATFORMS | tr -s ',' ' '`
do
  TARGET_PLATFORM_SUFFIX=`echo $TARGET_PLATFORM | tr -s '/' '-'`
  docker buildx build --load --platform $TARGET_PLATFORM -f $DOCKER_FILE_FOLDER/Dockerfile -t ${DOCKER_IMAGE_NAME}-${TARGET_PLATFORM_SUFFIX} --build-arg PHP_VERSION=$PHP_VERSION --build-arg PHP_PACKAGE_BASENAME=$PHP_PACKAGE_BASENAME --build-arg UNIT_VERSION=$UNIT_VERSION --build-arg APACHE2_VERSION=$APACHE2_VERSION .
done




