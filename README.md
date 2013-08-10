## Zendesk Pusher

To run:

```
bundle install
npm install express redis
cp .env.example .env
# fill in .env with a the secret of a "deployment" OAuth client
foreman start
```

Site runs at `localhost:8080`.
