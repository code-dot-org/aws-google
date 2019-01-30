module Aws
  class Google
    # Inserts GoogleCredentials into the default AWS credential provider chain.
    # Google credentials will only be used if Aws::Google.config is set before initialization.
    module CredentialProvider
      # Insert google_credentials as the second-to-last credentials provider
      # (in front of instance profile, which makes an http request).
      def providers
        super.insert(-2, [:google_credentials, {}])
      end

      def google_credentials(options)
        (config = Google.config) && Google.new(options.merge(config))
      end
    end
    ::Aws::CredentialProviderChain.prepend CredentialProvider
  end
end
