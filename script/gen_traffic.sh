# Generate some traffic on staging samson
# set ENV `STAGING_SAMSON_TOKEN`


while true; do
  echo "sending requests"


  curl -H "Authorization: Bearer $STAGING_SAMSON_TOKEN" https://samsontest.zende.sk/projects/webhooktest-fb255b1a.json
  curl -H "Authorization: Bearer $STAGING_SAMSON_TOKEN" https://samsontest.zende.sk/deploys.json
  curl -H "Authorization: Bearer $STAGING_SAMSON_TOKEN" https://samsontest.zende.sk/builds.json
  echo ""
  sleep 5
done
