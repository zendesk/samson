## Zendesk Pusher
#### When the alcohol won't cut it anymore

Run with `thin start -R config.ru`

Interesting things right now:

* Create a task (one-off command): /tasks/new
* Create a job (multiple tasks): /jobs/new
* Execute a job: /jobs/:id (linked from /jobs)
* Stream a job (e.g. with curl): /jobs/:id/stream

[![Build Status](https://magnum.travis-ci.com/zendesk/zendesk_deploy_service.png?token=tT5LJyhhszj8vXK8jzQA&branch=master)](https://magnum.travis-ci.com/zendesk/zendesk_deploy_service)
