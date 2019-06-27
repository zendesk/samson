# Gcloud Plugin

## Image tagging

Tag gcloud images with the stage permalink they deployed to, so developers can pull down the a specific stage's image.
If the stage is a production stage, the image is also tagged with 'production'.

## Image building

Check the "build with GCR" checkbox on the project edit page.
Images will be built using `gcloud container build submit`, which can be slow for large projects.
If the file upload takes too long or you have a custom cloudbuild.yaml, use build triggers instead and
notify samson of the finished builds via the build api.

## Image scanning

If a project opts in to "Show GCR Vulnerabilities", show GCR build vulnerabilities scan result on the build page and during deploy.
If the stage opts in to "Block deploy of vulnerable images", then deploys will fail when vulnerabilities are found.

Note: because of a bug in gcloud api vulnerability scans results are only available 10 minutes after the build completes.

## Setup

 - enable [cloudbuild api](https://console.cloud.google.com/apis/api/cloudbuild.googleapis.com/overview)
 - create a gcloud service account with "Cloud Container Builder" and "Storage Object Creator"
 - download credentials for that account
 - run `gcloud auth activate-service-account --key-file <YOUR-KEY>` on the samson host
 - run `gcloud config set account $(jq -r .client_email < <YOUR-KEY>)` on the samson host

## ENV Vars

  - `GCLOUD_PROJECT` - project to use
  - `GCLOUD_ACCOUNT` - account to use
  - `GCLOUD_OPTIONS` - additional commandline options
  - `GCLOUD_IMAGE_TAGGER` - set to `true` to enable tagging on deploy
  - `GCLOUD_IMAGE_SCANNER` - set to `true` to enable build scanning 
  - `GCLOUD_GKE_CLUSTERS_FOLDER` - set to folder where gke clusters config should be stored to enable gke cluster UI
