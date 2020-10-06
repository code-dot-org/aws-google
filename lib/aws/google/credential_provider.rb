module Aws
  class Google
    # Inserts GoogleCredentials into the default AWS credential provider chain.
    # Google credentials will only be used if Aws::Google.config is set before initialization.
    module CredentialProvider
      # Insert google_credentials as the third-to-last credentials provider
      # (in front of process credentials and instance_profile credentials).
      def providers
        super.insert(-3, [:google_credentials, {}])
      end

      def google_credentials(options)
        profile_name = determine_profile_name(options)
        if Aws.shared_config.config_enabled?
          Aws.shared_config.google_credentials_from_config(profile: profile_name)
        end
      rescue Errors::NoSuchProfileError
        nil
      end
    end
    ::Aws::CredentialProviderChain.prepend CredentialProvider

    module GoogleSharedCredentials
      def google_credentials_from_config(opts = {})
        p = opts[:profile] || @profile_name
        if @config_enabled && @parsed_config
          entry = @parsed_config.fetch(p, {})
          if (google_opts = entry['google'])
            Google.new(google_opts.transform_keys(&:to_sym))
          end
        end
      end
    end
    ::Aws::SharedConfig.prepend GoogleSharedCredentials
  end
end
