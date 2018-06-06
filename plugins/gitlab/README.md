Gitlab integration.

 - Must configure GITLAB_TOKEN. See https://docs.gitlab.com/ee/api/#authentication. Specifically,
   personal access token or impersonation token.
 - Configure GITLAB_WEB_URL and GITLAB_STATUS_URL in .env if self-hosted.
 - Default is "GITLAB_WEB_URL/api/v4".  Configure GITLAB_API_URL if you use a different version.
   See config/application.rb.
