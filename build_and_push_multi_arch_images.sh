#!/usr/bin/env bash

set -e

DOCKER_IMAGE_NAME=$1
TARGET_PLATFORMS=linux/arm64/v8,linux/amd64

if [ ! -z "$2" ]
then
  TARGET_PLATFORMS=$2
fi

# we have to do it like this, because of https://github.com/docker/buildx/issues/59#issuecomment-1168619521
echo "Build and Push ${DOCKER_IMAGE_NAME}"
docker buildx create --node buildx --name buildx --use --driver docker-container
docker buildx build --progress plain --push --platform $TARGET_PLATFORMS -f Dockerfile -t $DOCKER_IMAGE_NAME .
if [ ! -z "$QUAY_DOCKER_IMAGE_NAME" ]
then
  echo "Build and Push ${QUAY_DOCKER_IMAGE_NAME}"
  docker buildx build --progress plain --push --platform $TARGET_PLATFORMS -f Dockerfile -t $QUAY_DOCKER_IMAGE_NAME .
fi

if [ ! -z "$GHCR_DOCKER_IMAGE_NAME" ]
then
  echo "Build and Push ${GHCR_DOCKER_IMAGE_NAME}"
  docker buildx build --progress plain --push --platform $TARGET_PLATFORMS -f Dockerfile -t $GHCR_DOCKER_IMAGE_NAME .
fi
for SUFFIX in unit fpm apache2 frankenphp
do
  cat Dockerfile > Dockerfile-${SUFFIX}
  echo "" >> Dockerfile-${SUFFIX}
  cat files/$SUFFIX/$SUFFIX.Dockerfile.snippet.txt >> Dockerfile-${SUFFIX}

  echo "Build and Push ${DOCKER_IMAGE_NAME}-${SUFFIX}"
  docker buildx build --progress plain --push --platform $TARGET_PLATFORMS -f Dockerfile-${SUFFIX} -t $DOCKER_IMAGE_NAME-${SUFFIX} .
  if [ ! -z "$QUAY_DOCKER_IMAGE_NAME" ]
  then
    echo "Build and Push ${QUAY_DOCKER_IMAGE_NAME}-${SUFFIX}"
    docker buildx build --progress plain --push --platform $TARGET_PLATFORMS -f Dockerfile-${SUFFIX} -t $QUAY_DOCKER_IMAGE_NAME-${SUFFIX} .
  fi
  if [ ! -z "$GHCR_DOCKER_IMAGE_NAME" ]
  then
    echo "Build and Push ${GHCR_DOCKER_IMAGE_NAME}-${SUFFIX}"
    docker buildx build --progress plain --push --platform $TARGET_PLATFORMS -f Dockerfile-${SUFFIX} -t $GHCR_DOCKER_IMAGE_NAME-${SUFFIX} .
  fi
  rm Dockerfile-${SUFFIX}
done
