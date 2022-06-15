#!/bin/bash

if [ ! -f ".env" ]; then
  echo "Please create an .env file with a SERVICE, REGISTRY, NAMESPACE, VERSION and PLATFORM parameter"
  echo "
         SERVICE=my-api
         REGISTRY=registry.docker.libis.be
         NAMESPACE=my-project
         PLATFORM=linux/amd64"
  exit 1
fi

source .env

if [ -z $REGISTRY ]; then
  echo "Please set REGISTRY in .env"
  exit 1
fi

if [[ -z $SERVICE && -z $1 ]]; then
  echo "Please set SERVICE in .env or command line"
  exit 1
fi

if [ -z $NAMESPACE ]; then
  echo "Please set NAMESPACE in .env"
  exit 1
fi

if [ -z $VERSION ]; then
  echo "Please set VERSION in .env"
  echo 'Using "latest"'
  VERSION=latest
fi

if [ -z $PLATFORM ]; then
  echo "Please set $PLATFORM in .env can be one of linux/amd64, linux/arm64"
  ARCH=${uname-m}
  echo "Using linux/$ARCH"
  PLATFORM="linux/$ARCH"
fi

if [ -z $SOLIS ]; then
  echo "Please set SOLIS version in .env"
  exit 1
else
  SOLIS_VERSION=$SOLIS
fi

function build {
  echo "Building $SERVICE for $PLATFORM"
  if [ -f "./service.tgz" ]; then
    rm -f ./service.tgz
  fi

  if [ -d "$SERVICE" ]; then
    cd $SERVICE
    tar --exclude='./config' --exclude='./Gemfile' --exclude='./Gemfile.lock' -zcvf ../service.tgz ./*
    cd -

    docker buildx build --platform=$PLATFORM -f Dockerfile.service --tag $REGISTRY/$NAMESPACE/$SERVICE:$VERSION --push .

    if [ -f "./service.tgz" ]; then
      rm -f ./service.tgz
    fi
  else
    echo "$SERVICE not found"
    exit 1
  fi
}

function build_base {
  echo "Building $SERVICE for $PLATFORM using SOLIS v$SOLIS_VERSION"
  echo "Will push to $REGISTRY/$NAMESPACE/$SERVICE:$VERSION"
  docker buildx build --build-arg SOLIS_VERSION=$SOLIS --platform=$PLATFORM -f Dockerfile.base --tag $REGISTRY/$NAMESPACE/$SERVICE:$VERSION --push .
}

function push {
  echo "Pushing $SERVICE"
  docker tag $NAMESPACE/$SERVICE:$VERSION $REGISTRY/$NAMESPACE/$SERVICE:$VERSION
  docker push $REGISTRY/$NAMESPACE/$SERVICE:$VERSION
}

case $1 in
"push")
  build
  push
  ;;
"base")
  SERVICE=$1
  build_base
  ;;
*)
  SERVICE=$1
  build
  ;;
esac

echo
echo
if [ -z "$DEBUG" ]; then
  echo "docker run -p 9292:9292 $NAMESPACE/$SERVICE:$VERSION"
else
  echo "docker run -p 1234:1234 -p 9292:9292 -e DEBUG=1 $NAMESPACE/$SERVICE:$VERSION"
fi
