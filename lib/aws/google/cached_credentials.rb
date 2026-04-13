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
        return unless near_expiration?(SYNC_EXPIRATION_LENGTH)

        @mutex.synchronize do
          if near_expiration?(SYNC_EXPIRATION_LENGTH)
            refresh
            with_write_lock { write_credentials }
          end
        end
      end

      # Write credentials and expiration to AWS credentials file.
      def write_credentials
        # Ensure the AWS CLI is available before attempting to write credentials.
        return unless system('which aws >/dev/null 2>&1')

        # Manually map the credentials to the keys used by AWS CLI
        credentials_map = {
          'aws_access_key_id' => @credentials.access_key_id,
          'aws_secret_access_key' => @credentials.secret_access_key,
          'aws_session_token' => @credentials.session_token,
          'expiration' => @expiration
        }

        # Use the AWS CLI to set the credentials in the session profile
        credentials_map.each do |key, value|
          system("aws configure set #{key} #{value} --profile #{@session_profile}")
        end
      end

      private

      def now_monotonic
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      # Lock file ~/.aws/aws-google.mutex to prevent multiple simultaneous calls from
      # different processes from corrupting ~/.aws/config and ~/.aws/credentials
      def with_write_lock(try_again: true, &block)
        lock_path = aws_google_lock_path
        start_time = now_monotonic

        # jitter timeout so when we break the lock, if we started with 10 other parallel processes
        # there's much higher chance that somebody re-creates a new lock distinctly first, and we all
        # continue about our merry way, vs "aws-google suddenly no works w/o reboot". Messy but pragmatic.
        timeout = rand(45.0..60.0)

        # Open aws-google.mutex for read/write
        File.open(lock_path, File::RDWR | File::CREAT) do |lock|
          # Keep trying to exclusively file lock it every 0.1s until we succeed
          until lock.flock(File::LOCK_EX | File::LOCK_NB)
            if now_monotonic - start_time >= timeout
              # Crap, this shouldn't happen with a kernel lock, but it seems somebody is holding it for >45s?
              raise "aws-google is wedged, try deleting #{lock_path}." unless try_again
              warn "WARNING: timed out after #{timeout}s waiting for: #{lock_path}, breaking lock and trying again"
              File.unlink(lock_path)
              return with_write_lock(try_again: false, &block)
            end
            sleep 0.1
          end

          block.call
        end
      end

      def aws_google_lock_path
        dot_aws_dir = File.dirname(
          Aws.shared_config.config_path ||
          Aws.shared_config.credentials_path ||
          File.expand_path('~/.aws/config')
        )
        File.join(dot_aws_dir, 'aws-google.mutex')
      end
    end
  end
end
