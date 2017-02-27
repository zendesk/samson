# Continuous Integration support

Samson can be integrated with CI services through web-hooks. Web-hooks are just URLs that add to your
favourite CI service to allow it to tell Samson that a new release or deploy should be triggered.

Each project has it's own set of web-hook URLs. You can find a list of them for the various CI services Samson supports on the
'webhooks' tab when you navigate to your project within Samson.

There are 2 uses of web-hooks in Samson:
* Create a release for the project within Samson. I.e., Increment a version number, and tag the repo within GitHub so you can deploy tags instead of 'master'.
* Automatically trigger a deploy to your target hosts.

You can combine those 2 above as well.

## Workflow Summary

-> Push a change to a branch in GitHub (e.g. master)
-> CI validates the change
-> CI makes webhook call back to Samson
-> Samson receives webhook call
-> Samson checks if validation is passed
-> Deploy if passed / do nothing if failed

## Supported CI Services

* Travis
    * You can add a webhook notification to the .travis.yml file per project
* Semaphore
    * Semaphore has webhook per project settings
    * Add webhook link to your semaphore project
* Tddium
    * Tddium only has webhook per organisation setting
    * However you can have multiple webhooks per organisation
    * Add all webhooks to your organisation
    * Samson will match url to see if the webhook call is for the correct project
* Jenkins
    * Setup using the [Notification Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Notification+Plugin)
* Buildkite
    * You can add a webhook per project under settings/notifications
    * You can add any value to the 'Token' field, as it is not used
* GitHub
    * You may add a webhook for push events
    * To verify Github hooks, add a secret value as `GITHUB_HOOK_SECRET` to the environment and the same secret value in the **Secret** field in the Github webhook.

Note: to skip a deploy, add "[deploy skip]" to your commit message, and Samson will ignore the webhook from CI.

#### Continuous Delivery & Releases

In addition to automatically deploying passing commits to various stages, you
can also create an automated continuous delivery pipeline. By setting a *release
branch*, each new passing commit on that branch will cause a new release, with a
automatically incrementing version number. The commit will be tagged with the
version number, e.g. `v42`, and the release will appear in Samson.

Any stage can be configured to automatically deploy new releases. For instance,
you might want each new release to be deployed to your staging environment
automatically.
