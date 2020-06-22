# Secrets

Samson can manage secrets for commands, environment variables or kubernetes deploys under `/secrets`.

Lookup logic is in [lib/samson/secrets/key_resolver.rb](/lib/samson/secrets/key_resolver.rb).

Simplest usage is with `secret://some_key` in a command, the secret will be looked up in the secret store and resolved to the most specific secret,
for example `some_key` might be resolved to `production/my-project/global/some_key` (depending on the environment / project / deploy-group).

### Kubernetes + Vault

When the kubernetes plugin is enabled, secrets can be looked up via an [secret puller init container](https://github.com/zendesk/samson_secret_puller)
by setting annotations on the deployed resources (needs vault backend).

### Sharing

If `SECRET_STORAGE_SHARING_GRANTS` environment variable is enabled, global (= cross-project) secrets need a sharing grant to be used in each project.
This is useful to avoid over-sharing sensitive information and avoiding collision between similar keys (like db_password/aws_access_key,
that have different values for different projects).

### Visible

Some secrets are only in the secret store to keep them together with other configuration (for example username and password).
For these secrets the `visible` flag can be used to keep them visible for everyone.

### Deprecated

Secrets can be `deprecated` to make them not usable for new deployments, and then deleted once they are sure to be unused.

### Resolving secret paths via API

Secrets can be resolved to their full path (but not their value) in the context of a projects deploy group with the `/secrets/resolve.json` endpoint.

In the below example we have a secret configured for key `a` in the deploy group `group1`, but no secret configured for key `b`.

The endpoint supports both GET and POST:

```
$ curl -s -H "Content-Type: application/json" -H "Authorization: Bearer $SAMSON_ACCESS_TOKEN" $SAMSON_BASE_URL/secrets/resolve.json?project_id=2&deploy_group=group1&keys[]=a&keys[]=b
{
  "a": "global/example-kubernetes/global/a",
  "b": null
}

