## Zendesk Pusher

To run:

```
bundle install
cp .env.example .env
# fill in .env with a the secret of a "deployment" OAuth client
foreman start
```

Site runs at `localhost:8080`.

Currently `sdavidovitz` is hardcoded as the deploy user, you may want
to change it to your own for testing. See app/jobs/deploy.rb.
