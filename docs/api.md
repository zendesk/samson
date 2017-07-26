# API

Many endpoints offer a `.json` response, open PRs for missing ones, there is also a deprecated & dedicated `/api` endpoint.

Api authentication is done via OAuth tokens and scopes.

Scopes are default=all ... api=/api/* ... locks=read+write locks.

Users can create their own personal access tokens or use an OAuth flow to request access for registered OAuth applications.

### Api clients

To use a token via an api clients, send it as `Authorization: Bearer` header.
`curl -H "Authorization: Bearer TOKEN-GOES-HERE" http://samson-example.com/projects.json`

### Personal Access Tokens

If no OAuth application exists, create one under `/oauth/applications` and name it "Personal Access Tokens".
Then users can click on their profile and "Access Tokens" to create tokens for use with API clients.
