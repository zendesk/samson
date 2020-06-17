# Secrets

Samson can manage secrets for commands, environment variables or kubernetes deploys under `/secrets`.

Lookup logic is in [lib/samson/secrets/key_resolver.rb](/lib/samson/secrets/key_resolver.rb).

Most usage is with `secret://some_key` that will be looked up in the secret store and resolved to the most specific secret,
for example `some_key` might be resolved to `production/my-project/global/some_key`.

### Sharing

If `SECRET_STORAGE_SHARING_GRANTS` is enabled then global (cross-project) secrets need a sharing grant to be shared.
This is useful to avoid over-sharing sensitive information and avoiding collision between similar keys, like db_password/aws_access_key,
that mean different things for different apps.

### Visible

Some secrets are not really secret or are only in the secret store to keep them together with other configuration.
For these the `visible` flag can be used to keep them visible for everyone.

### Deprecated

Secrets can be `deprecated` first and deleted when all use outside of samson (vault backend or accessing secrets via api client) has stopped.

### Resolving secrets via API

Secrets can be resolved to their full path in the context of a projects deploy group with the `/secrets/resolve.json` endpoint.

In the below example we have a secret configured for key `a` in the deploy group `group1`, but no secret configured for key `b`.

The endpoint supports both GET and POST:

```
$ curl -s -H "Content-Type: application/json" -H "Authorization: Bearer $SAMSON_ACCESS_TOKEN" $SAMSON_BASE_URL/secrets/resolve.json?project_id=2&deploy_group=group1&keys[]=a&keys[]=b
{
  "a": "global/example-kubernetes/global/a",
  "b": null
}

