require_relative 'google/version'
require 'aws-sdk-core'
require_relative 'google/credential_provider'

require 'googleauth'
require 'google/api_client/auth/storage'
require 'google/api_client/auth/storages/file_store'

module Aws
  # An auto-refreshing credential provider that works by assuming
  # a role via {Aws::STS::Client#assume_role_with_web_identity},
  # using an ID token derived from a Google refresh token.
  #
  #   role_credentials = Aws::Google.new(
  #     role_arn: aws_role,
  #     google_client_id: client_id,
  #     google_client_secret: client_secret
  #   )
  #
  #   ec2 = Aws::EC2::Client.new(credentials: role_credentials)
  #
  # If you omit `:client` option, a new {Aws::STS::Client} object will be
  # constructed.
  class Google
    include ::Aws::CredentialProvider
    include ::Aws::RefreshingCredentials

    class << self
      attr_accessor :config
    end

    # @option options [required, String] :role_arn
    # @option options [String] :policy
    # @option options [Integer] :duration_seconds
    # @option options [String] :external_id
    # @option options [STS::Client] :client STS::Client to use (default: create new client)
    # @option options [String] :profile AWS Profile to store temporary credentials (default `default`)
    # @option options [String] :domain G Suite domain for account-selection hint
    # @option options [String] :online if `true` only a temporary access token will be provided,
    #                 a long-lived refresh token will not be created and stored on the filesystem.
    # @option options [String] :port port for local server to listen on to capture oauth browser redirect.
    #                 Defaults to 1234. Set to nil or 0 to use an out-of-band authentication process.
    # @option options [::Google::Auth::ClientId] :google_id
    def initialize(options = {})
      @oauth_attempted = false
      @assume_role_params = options.slice(
        *Aws::STS::Client.api.operation(:assume_role_with_web_identity).
          input.shape.member_names
      )

      @profile = options[:profile] || ENV['AWS_DEFAULT_PROFILE'] || 'default'
      @google_id = ::Google::Auth::ClientId.new(
        options[:google_client_id],
        options[:google_client_secret]
      )
      @client = options[:client] || Aws::STS::Client.new(credentials: nil)
      @domain = options[:domain]
      @online = options[:online]
      @port = options[:port] || 1234

      # Use existing AWS credentials stored in the shared config if available.
      # If this is `nil` or expired, #refresh will be called on the first AWS API service call
      # to generate AWS credentials derived from Google authentication.
      @expiration = Aws.shared_config.get('expiration', profile: @profile) rescue nil
      @mutex = Mutex.new
      if near_expiration?
        refresh!
      else
        @credentials = Aws.shared_config.credentials(profile: @profile) rescue nil
      end
    end

    private

    # Use cached Application Default Credentials if available,
    # otherwise fallback to creating new Google credentials through browser login.
    def google_client
      @google_client ||= (::Google::Auth.get_application_default rescue nil) || google_oauth
    end

    # Create an OAuth2 Client using Google's default browser-based OAuth InstalledAppFlow.
    # Store cached credentials to the standard Google Application Default Credentials location.
    # Ref: http://goo.gl/IUuyuX
    # @return [Signet::OAuth2::Client]
    def google_oauth
      return nil if @oauth_attempted
      @oauth_attempted = true

      path = "#{ENV['HOME']}/.config/#{::Google::Auth::CredentialsLoader::WELL_KNOWN_PATH}"
      FileUtils.mkdir_p(File.dirname(path))
      storage = GoogleStorage.new(::Google::APIClient::FileStore.new(path))

      options = {
        client_id: @google_id.id,
        client_secret: @google_id.secret,
        scope: %w[openid email]
      }
      uri_options = {include_granted_scopes: true}
      uri_options[:hd] = @domain if @domain
      uri_options[:access_type] = 'online' if @online

      credentials = ::Google::Auth::UserRefreshCredentials.new(options)
      credentials.code = get_oauth_code(credentials, uri_options)
      credentials.fetch_access_token!
      credentials.tap(&storage.method(:write_credentials))
    end

    def silence_output
      outs = [$stdout, $stderr]
      clones = outs.map(&:clone)
      outs.each { |io| io.reopen '/dev/null'}
      yield
    ensure
      outs.each_with_index { |io, i| io.reopen(clones[i]) }
    end

    def get_oauth_code(client, options)
      raise 'fallback' unless @port && !@port.zero?

      require 'launchy'
      require 'webrick'
      code = nil
      server = WEBrick::HTTPServer.new(
        Port: @port,
        Logger: WEBrick::Log.new(STDOUT, 0),
        AccessLog: []
      )
      server.mount_proc '/' do |req, res|
        code = req.query['code']
        res.status = 202
        res.body = 'Login successful, you may close this browser window.'
        server.stop
      end
      trap('INT') { server.shutdown }
      client.redirect_uri = "http://localhost:#{@port}"
      silence_output do
        launchy = Launchy.open(client.authorization_uri(options).to_s)
        server_thread = Thread.new do
          begin
            server.start
          ensure server.shutdown
          end
        end
        while server_thread.alive?
          raise 'fallback' if !launchy.alive? && !launchy.value.success?

          sleep 0.1
        end
      end
      code || raise('fallback')
    rescue StandardError
      trap('INT', 'DEFAULT')
      # Fallback to out-of-band authentication if browser launch failed.
      client.redirect_uri = 'oob'
      return ENV['OAUTH_CODE'] if ENV['OAUTH_CODE']

      raise RuntimeError, 'Open the following URL in a browser to get a code,' \
             "export to $OAUTH_CODE and rerun:\n#{client.authorization_uri(options)}", []
    end

    def refresh
      assume_role = begin
        client = google_client
        return unless client

        begin
          tries ||= 2
          id_token = client.id_token
          # Decode the JWT id_token to use the Google email as the AWS role session name.
          token_params = JWT.decode(id_token, nil, false).first
        rescue JWT::DecodeError, JWT::ExpiredSignature
          # Refresh and retry once if token is expired or invalid.
          client.refresh!
          raise if (tries -= 1).zero?
          retry
        end

        @client.assume_role_with_web_identity(
          @assume_role_params.merge(
            web_identity_token: id_token,
            role_session_name: token_params['email']
          )
        )
      rescue Signet::AuthorizationError, Aws::STS::Errors::ExpiredTokenException
        retry if (@google_client = google_oauth)
        raise
      rescue Aws::STS::Errors::AccessDenied => e
        retry if (@google_client = google_oauth)
        raise e, "\nYour Google ID does not have access to the requested AWS Role. Ask your administrator to provide access.
Role: #{@assume_role_params[:role_arn]}
Email: #{token_params['email']}
Google ID: #{token_params['sub']}", []
      end

      c = assume_role.credentials
      @credentials = Aws::Credentials.new(
        c.access_key_id,
        c.secret_access_key,
        c.session_token
      )
      @expiration = c.expiration.to_i
      write_credentials
    end

    # Write credentials and expiration to AWS credentials file.
    def write_credentials
      # AWS CLI is needed because writing AWS credentials is not supported by the AWS Ruby SDK.
      return unless system('which aws >/dev/null 2>&1')
      %w[
        access_key_id
        secret_access_key
        session_token
      ].map {|x| ["aws_#{x}", @credentials.send(x)]}.
        to_h.
        merge(expiration: @expiration).each do |key, value|
        system("aws configure set #{key} #{value} --profile #{@profile}")
      end
    end
  end

  # Patch Aws::SharedConfig to allow fetching arbitrary keys from the shared config.
  module SharedConfigGetKey
    def get(key, opts = {})
      profile = opts.delete(:profile) || @profile_name
      if @parsed_config && (prof_config = @parsed_config[profile])
        prof_config[key]
      end
    end
  end
  Aws::SharedConfig.prepend SharedConfigGetKey

  # Extend ::Google::APIClient::Storage to write {type: 'authorized_user'} to credentials,
  # as required by Google's default credentials loader.
  class GoogleStorage < ::Google::APIClient::Storage
    def credentials_hash
      super.merge(type: 'authorized_user')
    end
  end
end
