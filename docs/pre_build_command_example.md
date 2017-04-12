Example `build_binary.sh` that uses a secondary `Dockerfile.build` to generate artifacts the main `Dockerfile`
cannot produce without adding secrets or installing dev-tools that increase the image size.

Add `sh build_binary.sh` to your stage command or as the pre-build-command
to make these artifacts available during deploy/build.

```Bash
#!/bin/sh
# Prepares the local folder with artifacts that the main Dockerfile needs
# Can be used both locally and on Samson via a command or as pre-build command
image_name="build_binary_my_app_$$"
container_id_file="build_binary_id"
artifact_path="/app/target"

# Stop the build process if any step fails
if rm -rf $(basename "$artifact_path") $container_id_file &&
   docker build -t $image_name -f Dockerfile.build . &&
   docker run --cidfile $container_id_file $image_name &&
   container_id=$(cat $container_id_file) &&
   docker cp "${container_id}:${artifact_path}/." .
then
   echo "Docker build process complete"
else
   echo "Docker build process failed"
   exit_status=1
fi

# Cleanup
docker rmi -f $image_name && rm $container_id_file

exit $exit_status
```
