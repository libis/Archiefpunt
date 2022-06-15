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

if [ -z $SERVICE ]; then
   echo "Please set SERVICE in .env"
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
   ARCH=${uname -m}
   echo "Using linux/$ARCH"
   PLATFORM="linux/$ARCH"
fi

function create_config_tgz {
  if [ -f "./config.tgz" ]; then
    echo "Remove previous config.tgz package"
    rm -f ./config.tgz
  fi
  if [ -d "./config" ]; then
    echo "Creating config.tgz package"
    tar zcvf ./config.tgz ./config/*
  fi
}

function build {
   create_config_tgz
   echo "Building $SERVICE for $PLATFORM"
   docker buildx build --platform=$PLATFORM -f Dockerfile --tag $NAMESPACE/$SERVICE:$VERSION .
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
*)
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
