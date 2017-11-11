# Gcloud Plugin

## Image tagging

Tag gcloud images with the stage permalink they deployed to, so developers can pull down the "producion" image.

## Image building

When a deploy is requested on a project with 'builds disabled' that has builds from `gcr`,
trigger a build. This only works if something is notifying samson about new GCR builds.

## Setup

 - enable [cloudbuild api](https://console.cloud.google.com/apis/api/cloudbuild.googleapis.com/overview)
 - create a gcloud service account with admin access to cloudbuild
 - download credentials for that account
 - run `gcloud auth activate-service-account --key-file <YOUR-KEY>` on the samson host
 - run `gcloud config set account $(jq -r .client_email < <YOUR-KEY>)` on the samson host

## ENV Vars

  - `GCLOUD_IMG_TAGGER` - set to `true` to enable tagging on deploy
  - `GCLOUD_IMG_TAGGER_OPTS` - specify options that are passed to the `gcloud` command
  - `GCLOUD_BUILDER_PROJECT_ID` - project id to use when building gcloud images via build_with_gcb
