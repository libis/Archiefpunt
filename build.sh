#!/bin/bash
PROJECT_ROOT=$(pwd)

echo "Project ROOT: $PROJECT_ROOT"
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

function delete_service_package {
    if [ -f "$PROJECT_ROOT/build/service.tgz" ]; then
      echo "Removing ./build/service.tgz"
      rm -f $PROJECT_ROOT/build/service.tgz
    fi
}

function make_service_package {
  if [ -d "$PROJECT_ROOT/services/$SERVICE" ]; then
    echo "Making $SERVICE"
    delete_service_package
    cd $PROJECT_ROOT/services/$SERVICE
    tar --exclude='./config' --exclude='./Gemfile' --exclude='./Gemfile.lock' -zcvf $PROJECT_ROOT/build/service.tgz ./*
    cd $PROJECT_ROOT
  else
      echo "$SERVICE not found"
      exit 1
  fi
}

function delete_config_package {
    if [ -f "$PROJECT_ROOT/build/config.tgz" ]; then
      echo "Removing config.tgz"
      rm -f $PROJECT_ROOT/build/config.tgz
    fi
}

function make_config_package {
  delete_config_package
  tar -zcvf $PROJECT_ROOT/build/config.tgz ./config
}

function build {
  echo "Building $SERVICE for $PLATFORM"

  if [ -d "services/$SERVICE" ]; then
    make_service_package

    cd $PROJECT_ROOT/build
    docker buildx build --platform=$PLATFORM --build-arg SERVICE=$SERVICE --build-arg VERSION=$VERSION -f Dockerfile.service --tag $REGISTRY/$NAMESPACE/$SERVICE:$VERSION --push .
    cd $PROJECT_ROOT

    delete_service_package
  else
    echo "$SERVICE not found"
    exit 1
  fi
}

function build_base {
  echo "Building $SERVICE for $PLATFORM using SOLIS v$SOLIS_VERSION"
  echo "Will push to $REGISTRY/$NAMESPACE/$SERVICE:$VERSION"
  make_config_package

  cd $PROJECT_ROOT/build
  docker buildx build --build-arg SOLIS_VERSION=$SOLIS --platform=$PLATFORM -f Dockerfile.base --tag $REGISTRY/$NAMESPACE/$SERVICE:$VERSION --push .
  cd $PROJECT_ROOT

  delete_config_package
}

case $1 in
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
  echo "docker run -p 9292:9292 $REGISTRY/$NAMESPACE/$SERVICE:$VERSION"
else
  echo "docker run -p 1234:1234 -p 9292:9292 -e DEBUG=1 $REGISTRY/$NAMESPACE/$SERVICE:$VERSION"
fi
