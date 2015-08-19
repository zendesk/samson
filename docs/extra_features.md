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
