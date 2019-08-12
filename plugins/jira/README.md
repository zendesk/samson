# Jira Integration

Transition linked issues from merged PRs on successful deploy.

- set `JIRA_BASE_URL` environment variable for example `https://a.atlassian.net/browse/`
- set `JIRA_USER` environment variable
- set `JIRA_TOKEN` environment variable [Create token](https://id.atlassian.com/manage/api-tokens)
- set jira prefix in project form (FOO-123 -> set to FOO)
- set jira transition id in stage form (check https://a.atlassian.net/rest/api/3/issue/<ISSUE-ID>/transitions)

### TODO
- transition more jira logic from the main app here
