Example `build.sh` that uses a secondary `Dockerfile.build` to generate artifacts the main `Dockerfile`
cannot produce without adding secrets or installing dev-tools that increase the image size.

```Bash
# This script prepares the target folder with compiled classes that the main Dockerfile needs to build the main image
# This can be used both locally and on samson.
test -n "$ARTIFACTORY_USERNAME" && test -n "$ARTIFACTORY_KEY" && \ # make sure we have all env vars we need
    set -x && \ # show what we run so it is easy to debug
    rm -rf target build_container_id && \ # cleanup before we start
    docker build -t app_binary_builder -f Dockerfile.build . && \
    docker run --cidfile build_container_id -e ARTIFACTORY_USERNAME -e ARTIFACTORY_KEY app_binary_builder command_goes_here && \
    docker cp $(cat build_container_id):/app/target . && \ # copy generated artifacts to disk
    touch done

docker rm $(cat build_container_id) && docker rmi app_binary_builder && rm done # cleanup and fail when something went wrong
```
