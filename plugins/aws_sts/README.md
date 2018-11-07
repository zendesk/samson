# AWS STS Plugin

Inject temporary AWS Role credentials into a deploy environment using [AWS STS](https://docs.aws.amazon.com/STS/latest/APIReference/Welcome.html) and [Assume role](https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRole.html).

## Overview

The plugin uses the assume role feature of STS and exposes the generated credentials
as environment variables:
  - STS_AWS_ACCESS_KEY_ID
  - STS_AWS_SECRET_ACCESS_KEY
  - STS_AWS_SESSION_TOKEN

The plugin authenticates with AWS using the following samson environment variables:
  - SAMSON_STS_AWS_ACCESS_KEY_ID
  - SAMSON_STS_AWS_SECRET_ACCESS_KEY
  - SAMSON_STS_AWS_REGION

Specify the Amazon Resource Name (ARN) of the role to assume in the stage's settings page.
