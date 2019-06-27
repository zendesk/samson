
# API

Many endpoints offer a `.json` response, open PRs for missing ones.

Api authentication is done via OAuth tokens and scopes, see [/lib/warden/strategies/doorkeeper_strategy.rb](/lib/warden/strategies/doorkeeper_strategy.rb) for details.

Scopes are default="all" ... locks="allowed to read+write locks".

Users can create their own personal access tokens or use an OAuth flow to request access for registered OAuth applications.

### Api clients

To use a token via an api clients, send it as `Authorization: Bearer` header.
`curl -H "Authorization: Bearer TOKEN-GOES-HERE" http://samson-example.com/projects.json`

### Personal Access Tokens

If no OAuth application exists, create one under `/oauth/applications` and name it "Personal Access Tokens".
Then users can click on their profile and "Access Tokens" to create tokens for use with API clients.

### Render as JSON

Many JSON endpoints have the option to append associated records or some custom inline data along with original JSON response, by requesting the endpoint with some extra parameter.

#### ?includes

The parameter `includes` will add requested associated record values and their associated ids along with the original JSON response.
If you are requesting for many associated records, it should be separated by `comma's ,`

`http://samson-example.com/projects/zendesk.json?includes=environment_variable_groups,environment_variables_with_scope`

If the requested associated records are not permitted, then the response will raise an error with a message.

#### ?inlines

The parameter `inlines` will append additional allowed custom method values with original JSON response

`http://samson-example.com/environment_variables.json?inlines=parent_name,scope_name`
