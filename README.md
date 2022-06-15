# Archiefpunt

## BUILD
Every build is *automatically* pushed into the Libis Docker registry.
The build script is using ```buildx``` instead of the ```build``` command. This makes it possible to create builds for multiple CPU environments.  

### .env
This is the environment file that contains variables used in the ```build.sh``` script.

```shell
REGISTRY=registry.docker.libis.be
NAMESPACE=archiefpunt
PLATFORM=linux/amd64,linux/arm64
SOLIS=0.43.0
```

### Base image
This is a base image build using the ```Dockerfile.base``` build file. It contains a Ruby interpreter, gems, user/group, default folders like cache, config
```shell
./build.sh base
```


### Service image
Is build using ```Dockerfile.service```
```shell
./build data|logic|search|...
```