require 'test_helper'

require 'active_support/core_ext/numeric/time'
require 'timecop'
require 'mocha/minitest'
require 'webmock/minitest'

describe Aws::Google do
  before do
    # Load fixtures instead of actual shared AWS config on filesystem.
    credentials = File.expand_path(File.join(__dir__, 'fixtures', 'aws_credentials'))
    config = File.expand_path(File.join(__dir__, 'fixtures', 'aws_config'))
    Aws.shared_config.fresh(
      config_enabled: true,
      credentials_path: credentials,
      config_path: config
    )
    # Disable instance metadata credentials.
    stub_request(:get, '169.254.169.254/latest/meta-data/iam/security-credentials/')
    stub_request(:put, '169.254.169.254/latest/api/token')
    # Disable environment credentials.
    ENV.stubs(:[]).returns(nil)
  end

  describe 'not configured' do
    before do
      Aws::Google.stubs(:config).returns(nil)
    end

    it 'does nothing' do
      Aws::Google.expects(:new).never
      Aws::STS::Client.new
    end
  end

  describe 'configured' do
    let :config do
      {
        role_arn: 'aws_role',
        client_id: 'client_id',
        client_secret: 'client_secret',
        profile: 'cdo',
        client: Aws::STS::Client.new(stub_responses: true)
      }
    end

    let :credentials do
      {
        access_key_id: 'x',
        secret_access_key: 'y',
        session_token: 'z',
        expiration: 1.hour.from_now
      }
    end

    let :oauth do
      mock.tap do |m|
        m.stubs(:id_token).returns(
          JWT.encode({ email: 'email' }, '')
        )
      end
    end

    let(:system) { @system }

    before do
      Aws::Google.stubs(:config).returns(config)
      config[:client].stub_responses(
        :assume_role_with_web_identity,
        credentials: credentials
      )
      @system = Object.any_instance.stubs(:system).with do |x|
        x.match('which aws') || x.match('aws configure set ')
      end.returns(true)
      @oauth_default = Google::Auth.stubs(:get_application_default).returns(oauth)
    end

    it 'creates credentials from a Google auth token' do
      @oauth_default.once
      system.times(5)

      c = Aws::Google.new(config).credentials
      _(c.credentials.access_key_id).must_equal credentials[:access_key_id]
      _(c.credentials.secret_access_key).must_equal credentials[:secret_access_key]
      _(c.credentials.session_token).must_equal credentials[:session_token]
    end

    it 'refreshes expired Google auth token credentials' do
      m = mock
      m.stubs(:refresh!)
      m.stubs(:id_token).
        returns(JWT.encode({ email: 'email', exp: Time.now.to_i - 1 }, '')).
        then.returns(JWT.encode({ email: 'email' }, ''))
      Google::Auth.stubs(:get_application_default).returns(m)

      system.times(5)

      c = Aws::Google.new(config).credentials
      _(c.credentials.access_key_id).must_equal credentials[:access_key_id]
      _(c.credentials.secret_access_key).must_equal credentials[:secret_access_key]
      _(c.credentials.session_token).must_equal credentials[:session_token]
    end

    it 'refreshes expired credentials' do
      config[:client].stub_responses(
        :assume_role_with_web_identity,
        [
          { credentials: credentials.dup.tap { |c| c[:expiration] = 1.hour.from_now } },
          { credentials: credentials.dup.tap { |c| c[:expiration] = 2.hours.from_now } }
        ]
      )
      provider = Aws::Google.new(config)
      expiration = provider.expiration
      _(expiration).must_equal(provider.expiration)
      Timecop.travel(1.5.hours.from_now) do
        _(expiration).wont_equal(provider.expiration)
      end
    end

    it 'refreshes saved expired credentials' do
      config[:profile] = 'cdo-expired'
      @oauth_default.once
      system.times(5)
      Aws::Google.new(config).credentials
    end

    it 'reuses saved credentials without refreshing' do
      config[:profile] = 'cdo-saved'
      Aws::Google.any_instance.expects(:refresh).never
      Aws::Google.new(config).credentials
    end

    describe 'valid Google auth, no AWS permissions' do
      before do
        config[:client].stub_responses(
          :assume_role_with_web_identity,
          [
            Aws::STS::Errors::AccessDenied.new(nil, nil),
            { credentials: credentials }
          ]
        )
      end

      it 'retries Google auth when invalid credentials are provided' do
        system.times(5)
        @oauth_default.once
        Aws::Google.any_instance.expects(:google_oauth).returns(oauth)
        Aws::Google.new(config).credentials
      end

      it 'raises error on invalid AWS permissions' do
        Google::Auth.expects(:get_application_default).returns(nil)
        Aws::Google.any_instance.expects(:google_oauth).times(2).returns(oauth, nil)
        err = assert_raises(Aws::STS::Errors::AccessDenied) do
          Aws::Google.new(config).credentials
        end
        _(err.message).must_match 'Your Google ID does not have access to the requested AWS Role.'
      end
    end

    describe 'invalid (expired/revoked) Google auth' do
      it 'creates new Google refresh token when expired' do
        token_uri = 'http://example.com/token'
        m = Signet::OAuth2::Client.new(
          token_credential_uri: token_uri
        )
        Google::Auth.stubs(:get_application_default).returns(m)
        token_post = stub_request(:post, token_uri).to_return(
          status: 400,
          body: {
            error: 'invalid_grant',
            error_description: 'Token has been expired or revoked.'
          }.to_json,
          headers: {
            content_type: 'application/json'
          }
        )
        Aws::Google.any_instance.expects(:google_oauth).returns(oauth)
        Aws::Google.new(config).credentials
        assert_requested(token_post)
      end
    end

    describe 'expired Google auth token' do
      before do
        config[:client].stub_responses(
          :assume_role_with_web_identity,
          [
            Aws::STS::Errors::ExpiredTokenException.new(nil, nil),
            { credentials: credentials }
          ]
        )
      end

      it 'refreshes Google auth token when expired' do
        system.times(5)
        @oauth_default.once
        Aws::Google.any_instance.expects(:google_oauth).returns(oauth).once
        Aws::Google.new(config).credentials
      end
    end
  end
end
