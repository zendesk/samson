# Getting Started

### Docker

```bash
docker-compose up
open http://$DOCKER_HOST_IP:9080
```

### Local
```bash
script/bootstrap # Run the bootstrap script to use the test credentials.
rails s
open http://localhost:3000
```

### Setup
 - Add a new project http://localhost:3000/projects/new
 - name: example-project url: git@github.com:samson-test-org/example-project.git
 - Create a Stage
 - Deploy!

# Permission

Samson assumes the user you are running the service under has permission to perform the various tasks like
cloning repositories. For private repositories especially, this may necessitate uploading SSH keys or keychaining the user/password:
* https://help.github.com/articles/set-up-git/#next-steps-authenticating-with-github-from-git

Otherwise when creating a new project you may get the error "<Repository URL> is not valid or accessible".

# Configuration

## Database

For very small deployments, SQLite is sufficient, however you may want to leverage MySQL or PostgreSQL. 
Set up a production block in database.yml with the settings to connect to your DB then run `RAILS_ENV=production bundle exec rake db:setup`

## Webserver

Configure `config/puma.rb` as you need. See [puma's documentation](https://github.com/puma/puma/) for details. You can start the server using this file by doing `puma -C config/puma.rb`.

## Settings

Set the following variables in your `.env` file or set them as environment variables in the shell you spawn the webserver from:

<table>
  <tbody>
    <tr><th>Key</th><th>Required</th><th>Description</th></tr>
    <tr>
      <td>SECRET_TOKEN</td>
      <td>Yes</td>
      <td>for Rails, generated during script/bootstrap.</td>
    </tr>
    <tr>
      <td>GITHUB_TOKEN</td>
      <td>Yes</td>
      <td>This is a personal access token that Samson uses to access project repositories, commits, files and pull requests.
          <ul>
            <li> Navigate to https://github.com/settings/tokens/new to generate a new personal access token</li>
            <li> Choose scope including repo, read:org, user and then generate the token</li>
            <li> You should now have a personal access token to populate the .env file with</li>
          </ul>
      </td>
    </tr>
    <tr>
      <td>GITHUB_CLIENT_ID<BR>GITHUB_SECRET</td>
      <td></td>
      <td>
        These settings are used if you want to allow users to login/authenticate with Github OAuth
        <ul>
          <li> Navigate to https://github.com/settings/applications/new and register a new OAuth application</li>
          <li> Set the Homepage URL to http://localhost:3000</li>
          <li> Set the Authorization callback URL to http://localhost:3000/auth/github/callback</li>
          <li> You should now have Client ID and Client Secret values to populate the these with</li>
        </ul>
      </td>
    </tr>
    <tr>
      <td>DEFAULT_URL</td>
      <td></td>
      <td>absolute url to samson (used by the mailer), e.g. http://localhost:3000</td>
    </tr>
    <tr>
      <td>GITHUB_ORGANIZATION<BR>GITHUB_ADMIN_TEAM<BR>GITHUB_DEPLOY_TEAM</td>
      <td></td>
      <td>Samson can use an organisation's teams to provide default roles to users authenticating with GitHub. 
        <ul>
          <li>GITHUB_ORGANIZATION is the name of the organisation to read teams from, e.g. zendesk</li>
          <li>Setting GITHUB_ADMIN_TEAM will allow any users part of the that team within the GITHUB_ORGANIZATION organization to have 'ADMINISTRATOR' permissions.</li>
          <li>Setting GITHUB_DEPLOY_TEAM will allow any users part of the that team within the GITHUB_ORGANIZATION organization to have 'DEPLOYER' permissions.</li>
        </ul>
        Other users will get 'VIEWER' permissions by default if part of this organization.
      </td>
    </tr>
    <tr>
      <td>GITHUB_WEB_URL<BR>GITHUB_API_URL</td>
      <td></td>
      <td>Samson can use custom GitHub endpoints if, for example, you are using GitHub enterprise.
        <ul>
          <li>GITHUB_WEB_URL is used for GitHub interface links, e.g. compare screens, OAuth authorization</li>
          <li>GITHUB_API_URL is used for GitHub API access</li>
        </ul>
      </td>
    </tr>
    <tr>
      <td>GOOGLE_CLIENT_ID<BR>GOOGLE_CLIENT_SECRET</td>
      <td></td>
      <td>
        These settings are used if you want to allow users to login/authenticate with Google OAuth
        <ul>
          <li>Navigate to https://console.developers.google.com/project and create a new project</li>
          <li>Enter a name and a unique project id</li>
          <li>Once the project is provisioned, click APIs & auth</li>
          <li>Turn on Contacts API and Google+ API (they are needed by Samson to get email and avatar)</li>
          <li>Click the Credentials link and then create a new Client ID</li>
          <li>Set the Authorized JavaScript Origins to http://localhost:3000</li>
          <li>Set the Authorized Redirect URI to http://localhost:3000/auth/google/callback</li>
          <li>Create the Client ID</li>
        </ul>
        You should now have Client ID and Client secret values to populate the .env file with
      </td>
    </tr>
    <tr>
      <td>NEWRELIC_API_KEY</td>
      <td></td>
      <td>You may fill in using the instructions below if you would like a dynamic chart of response time and throughput during deploys.
          https://docs.newrelic.com/docs/features/getting-started-with-the-new-relic-rest-api#setup</td>
    </tr>
  </tbody>
</table>

For more settings that enable advanced features see the [Extra features page](extra_features.md).

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/zendesk/samson)
