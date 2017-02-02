# Docker Builder for Binaries

This plugin is useful when your projects are based on compiled languages and you don't want to base
your deployment docker images on images that have all the tools/libs/compilers installed.

Advantages to separating your docker images include:
- Smaller deployment docker images.
- Better security in your docker images to not be able to recompile code.

## Getting Started

This plugin makes a few assumptions:
- You have 2 dockerfiles:
 - `Dockerfile` used to generate your main deployment docker image
 - `Dockerfile.build` used to create a temporary image to build any binaries you want to package into the former.
- You have a build script `build.sh` that can be executed to compile the needed binaries
  - This is packaged inside the Dockerfile.build image and executed
    - make sure that this file has execute permissions (`chmod +x build.sh`)
  - After binaries are compiled the build.sh script finishes by tar'ing all necessary files into an 'artifacts.tar' file.

If you want to share caches between builds, e.g. all your projects are Java and use Maven to build, then sharing the .m2 
directory will be a huge time saving tactic to share all downloaded dependencies.

If the directory '/opt/samson_build_cache' exists on the Docker host, it will mount it to '/build/cache' inside the 
docker build image. That way you could then instruct Maven to use '/build/cache/.m2' as the cache directory for all your 
projects.

You can also provide a script named 'pre_binary_build.sh' to be ran before the docker binary plugin starts building the image.

The build container will also receive all global (`All` selected in the env var's combo box) environment variables that are configured for a project, assuming the `env` plugin is enabled.

## Example Setup

'Dockerfile' contents
```
# We only need the JRE base image now
FROM java:8u45-jre

# These jars will be built in the other Dockerfile.build image and then copied into here.
ADD target/scala-2.11/myproject-*.jar
```


'Dockerfile.build' contents
```
FROM scala_sbt:2.11.7

# create cache directory in case it couldn't be mounted correctly
RUN mkdir -p /build/cache
# '/app' will be the main directory in this image
RUN mkdir -p /app/src

# Add the scala build config files
ADD project /app/project
# Add the source directory into this image 
ADD src/main /app/src/main
# Add our main build script into the image
ADD build.sh /app/build.sh

WORKDIR /app
```

'build.sh' contents:
```
#!/usr/bin/env bash
sbt -ivy /build/cache/.ivy2 clean compile assembly
cd /app && tar -cvf /app/artifacts.tar target/scala-2.11/*.jar
```
