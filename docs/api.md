# API

Many endpoints offer a `.json` response, open PRs for missing ones.

Api authentication is done via OAuth tokens and scopes, see [lib/warden/strategies/doorkeeper_strategy.rb]() for details.

Scopes are default="all" ... locks="allowed to read+write locks".

Users can create their own personal access tokens or use an OAuth flow to request access for registered OAuth applications.

### Api clients

To use a token via an api clients, send it as `Authorization: Bearer` header.
`curl -H "Authorization: Bearer TOKEN-GOES-HERE" http://samson-example.com/projects.json`

### Personal Access Tokens

If no OAuth application exists, create one under `/oauth/applications` and name it "Personal Access Tokens".
Then users can click on their profile and "Access Tokens" to create tokens for use with API clients.
