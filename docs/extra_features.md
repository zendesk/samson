# Extra Features

We have other features that are turned off by default and require setting an environment variable to enable:

## Environment and Deploy Group managing

Enable by setting DEPLOY_GROUP_FEATURE=1

Now you will see extra items in the Admin menu:
* Admin -> Environments
** This page allows you to create your deploy environments like 'Production', 'Staging', 'Master', etc...
* Admin -> Deploy Groups
** This allows you to model the individual target hosts/groups within the above environments.

When you set those up, you can now edit the Stages within the Projects and tag the appropriate deploy-groups that those 
stages deploy to.

Now you can use $DEPLOY_GROUPS within the stage commands to target the deploy-groups you've checked the boxes for.
E.g., in the stage commands you can execute: 'echo "Deploying to $DEPLOY_GROUPS"'

Also you get another main menu item 'Environments'. Navigating to there will show you which versions for your projects are 
currently deployed to for the various environments and deploy-groups you configured.

Admin screens  | Dashboard screens
------------- | -------------
<img src="/docs/images/deploy_group_admin2.png?raw=true" width="300" /> | <img src="/docs/images/deploy_group_dash1.png?raw=true" width="300" />
<img src="/docs/images/deploy_group_admin.png?raw=true" width="300"> | <img src="/docs/images/deploy_group_dash2.png?raw=true" width="300">

## Auto JIRA issue key detection

Enable by setting JIRA_BASE_URL to a default JIRA instance e.g., `JIRA_BASE_URL=http://jira.example.com/browse/`

This would enable the auto-detection of JIRA issue keys (e.g., KEY-123, SAMSON-456) in the titles and bodies of the pull requests associated with a deploy. The auto-detected JIRA issues will be displayed and linked in the "JIRA Issues" tab of a deploy.

Full absolute JIRA URLs will still be detected when JIRA_BASE_URL is set, and they will take precedence over generated ones (i.e., if JIRA_BASE_URL is https://a.atlassian.net/browse/ and both "KEY-123" and "http://z.atlassian.net/browse/KEY-123" appear in a pull request's title and body, only "http://z.atlassian.net/browse/KEY-123" would appear in the "JIRA Issues" tab). Use full URLs if you need to reference issues of non-default JIRA instances.

## Request additional access rights via email

Add a link to the "You are not authorized..." popup which the user can click to request additional access rights.

<img src="/docs/images/request_access_popup.png?raw=true" width="600" />

The link will also be available on the user's profile page.

<img src="/docs/images/request_access_profile.png?raw=true" width="600" />

The access request requires a manager email and a reason for the additional access rights.

<img src="/docs/images/request_access_page.png?raw=true" width="600" />

The recipients and subject prefix of the email are configurable, use REQUEST_ACCESS_EMAIL_ADDRESS_LIST and REQUEST_ACCESS_EMAIL_PREFIX environment variables to tweak the message.

The receiving end can be a Samson admin distribution list, a JIRA email trigger which will automatically set up an access ticket, or whatever you fancy.

The feature is enabled by setting REQUEST_ACCESS_FEATURE=1

## Stagger Job Execution

Samson can experience a spike in load if multiple deploys are kicked off at once, for example on restart
if multiple deploys were queued during the restart process, or in in the 'mass rollout' operation (available if the
deploy groups feature is enabled). This can be alleviated by setting the environment variable JOB_STAGGER_INTERVAL
to a non-zero value, which will enable Samson's job staggering feature: queueing jobs to be executed and dequeueing 
them at a rate of the set value in seconds. 

ex. `JOB_STAGGER_INTERVAL=10` -> one job will start every 10 seconds
