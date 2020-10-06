module Aws
  class Google
    Aws::SharedConfig.config_reader :expiration

    # Mixin module extending `RefreshingCredentials` that caches temporary credentials
    # in the credentials file, so a single session can be reused across multiple processes.
    # The temporary credentials are saved to a separate profile with a '_session' suffix.
    module CachedCredentials
      include RefreshingCredentials

      # @option options [String] :profile AWS Profile to store temporary credentials (default `default`)
      def initialize(options = {})
        # Use existing AWS credentials stored in the shared session config if available.
        # If this is `nil` or expired, #refresh will be called on the first AWS API service call
        # to generate AWS credentials derived from Google authentication.
        @mutex = Mutex.new

        @profile = options[:profile] || ENV['AWS_PROFILE'] || ENV['AWS_DEFAULT_PROFILE'] || 'default'
        @session_profile = @profile + '_session'
        @expiration = Aws.shared_config.expiration(profile: @session_profile) rescue nil
        @credentials = Aws.shared_config.credentials(profile: @session_profile) rescue nil
        refresh_if_near_expiration
      end

      def refresh_if_near_expiration
        if near_expiration?
          @mutex.synchronize do
            if near_expiration?
              refresh
              write_credentials
            end
          end
        end
      end

      # Write credentials and expiration to AWS credentials file.
      def write_credentials
        # AWS CLI is needed because writing AWS credentials is not supported by the AWS Ruby SDK.
        return unless system('which aws >/dev/null 2>&1')
        Aws::SharedCredentials::KEY_MAP.transform_values(&@credentials.method(:send)).
          merge(expiration: @expiration).each do |key, value|
          system("aws configure set #{key} #{value} --profile #{@session_profile}")
        end
      end
    end
  end
end
