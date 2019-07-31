echo "Getting list of jira tickets"
# We use the public endpoint to get the full page of the changeset
url=https://samson.zende.sk/projects/472/deploys/${DEPLOY_ID}/changeset

# Couldn't figure out how to authenticate so created a token and used it here
page=$(curl --header "Authorization: Bearer <token>" $url)

# We then parse the whole html page to extract only the name of the issues
# this is the more painful part of the script and will greatly benefits from reusing 
# existing models
for issueId in $(echo "$page" | sed 's/.*https:\/\/zendesk\.atlassian\.net\/browse\/\(EXPOLY-[0123456789]*\).*/\1/' | grep '^EXPOLY-' ); do 
	echo "Transitioning ${issueId}"

    # This is the call to actually transition the issue
	jiraUrl=https://zendesk.atlassian.net/rest/api/3/issue/${issueId}/transitions

    # We can finally use Oauth2 with Jira rest API so it's fairly easy but there is a 
    # jira-ruby gem we could use as well
	curl -X POST --user acalmette@zendesk.com:<token> --header "Content-Type: application/json" --header "Accept: application/json" --data "{\"transition\":{\"id\":\"${TRANSITION_ID}\"}}" $jiraUrl
    # We do not fail deploy on failed transitioning but errors are displayed issue by issue
	echo "Done!"
done
