# Aws::Google [![Build Status](https://travis-ci.com/code-dot-org/aws-google.svg?branch=master)](https://travis-ci.com/code-dot-org/aws-google)

Use Google OAuth as an AWS Credential Provider.

## Installation

Add this line to your application's `Gemfile`:

```ruby
gem 'aws-google'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install aws-google

## Usage

### Create a Google Client ID
Visit the [Google API Console](https://console.developers.google.com/) to create/obtain [OAuth 2.0 Client ID credentials](https://support.google.com/cloud/answer/6158849) (client ID and client secret) for an application in your Google account.

### Create an AWS IAM Role
Create an AWS IAM Role with the desired IAM policies attached, and a ['trust policy'][1] ([`AssumeRolePolicyDocument`][2]) allowing the [`sts:AssumeRoleWithWebIdentity`][3] action with [Web Identity Federation condition keys][4] authorizing
your Google Client ID (`accounts.google.com:aud`) and a specific set of Google Account IDs (`accounts.google.com:sub`):

[1]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_terms-and-concepts.html#term_trust-policy "IAM Trust Policy"
[2]: https://docs.aws.amazon.com/IAM/latest/APIReference/API_CreateRole.html "Create Role API"
[3]: https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRoleWithWebIdentity.html "Assume Role With Identity API"
[4]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_iam-condition-keys.html#condition-keys-wif "IAM Condition Keys"

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "accounts.google.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "accounts.google.com:aud": "123456789012-abcdefghijklmnopqrstuvwzyz0123456.apps.googleusercontent.com",
          "accounts.google.com:sub": [
            "000000000000000000000",
            "111111111111111111111"
          ]
        }
      }
    }
  ]
}
```

### Method 1: `Aws::Google`
In your Ruby code, construct an `Aws::Google` object by passing the AWS `role_arn`, Google `client_id` and `client_secret`, either as constructor arguments or via the `Aws::Google.config` global defaults:

```ruby
require 'aws/google'

options = {
  aws_role: 'arn:aws:iam::[AccountID]:role/[Role]',
  client_id: '123456789012-abcdefghijklmnopqrstuvwzyz0123456.apps.googleusercontent.com',
  client_secret: '01234567890abcdefghijklmn'
}

# Pass constructor arguments:
credentials = Aws::Google.new(options)
puts Aws::STS::Client.new(credentials: credentials).get_caller_identity

# Set global defaults:
Aws::Google.config = options
puts Aws::STS::Client.new.get_caller_identity
```

### Method 2: AWS Shared Config
- Or, add the properties to your AWS config profile ([`~/.aws/config`](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html#cli-configure-files-where)) to use Google as the AWS credential provider without any changes to your application code:

```ini
[my_profile]
google =
    role_arn = arn:aws:iam::[AccountID]:role/[Role]
    client_id = 123456789012-abcdefghijklmnopqrstuvwzyz0123456.apps.googleusercontent.com
    client_secret = 01234567890abcdefghijklmn
credential_process = aws-google
```

The extra `credential_process` config line tells AWS to [Source Credentials with an External Process](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sourcing-external.html), in this case the `aws-google` executable script installed by this gem, which allows you to seamlessly use the same Google login configuration from non-Ruby SDKs (like the CLI).

## Development

Prerequisites:

* Ruby 3.0.5

You can have Ruby installed locally, or use Docker and mount this repository into a Ruby container. By using Docker you can avoid conflicts with differing Ruby versions or other installed gems. To run and 'bash' into a Ruby container, install Docker and run the following. See [docker-compose.yml](docker-compose.yml) for details.

```
docker compose build
docker compose run ruby
```

With either option, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/code-dot-org/aws-google.

## License

The gem is available as open source under the terms of the [Apache 2.0 License](http://opensource.org/licenses/apache-2.0).
