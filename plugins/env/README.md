# Env Plugin

Plugin to manage ENV settings for projects/stages/deploys and write .env files during deploy.

## Stage ENV Vars

Can be used to have 1-off settings that differ from the project.

## Deploy ENV Vars

Can be used to have generic stages to run one-off jobs or other tasks that need to be parameterized on each run.

## API

Includes `/projects/:permalink/environment?deploy_group=permalink` endpoint that returns the `.env` content
for a project and deploy_group.

For details, see `app/models/environment_variable.rb`

## External service to manage environment variable groups

Run a service that writes config to an s3 bucket, 1 file per environment variable group.
The config file format should be either `JSON or YAML` and environment variables should be grouped by `deploy group` permalink.
```bash
# cat https://zendesk-config.s3.amazonaws.com/samson/env_groups/pod.yml?versionId=123H
---
pod1:
  name: pod1
  env: development
pod2:
  name: pod2
  env: test
```

To enable reading environment variable groups from an S3 bucket,
set samson environment variables `EXTERNAL_ENV_GROUP_S3_BUCKET` and `EXTERNAL_ENV_GROUP_S3_REGION`.
To support reading from a replicated S3 bucket on failure, also set `EXTERNAL_ENV_GROUP_S3_DR_BUCKET`
and `EXTERNAL_ENV_GROUP_S3_DR_REGION` environment variables.
set samson environment variable `EXTERNAL_ENV_GROUP_HELP_TEXT` for help text in UI.
Database environment variable groups config will override returned group env variables.
