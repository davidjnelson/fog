require 'fog/aws'

module Fog
  module AWS
    class AutoScaling < Fog::Service
      extend Fog::AWS::CredentialFetcher::ServiceMethods

      class IdentifierTaken < Fog::Errors::Error; end
      class ResourceInUse < Fog::Errors::Error; end
      class ValidationError < Fog::Errors::Error; end

      requires :aws_access_key_id, :aws_secret_access_key
      recognizes :host, :path, :port, :scheme, :persistent, :region, :use_iam_profile, :aws_session_token, :aws_credentials_expire_at, :instrumentor, :instrumentor_name

      request_path 'fog/aws/requests/auto_scaling'
      request :create_auto_scaling_group
      request :create_launch_configuration
      request :delete_auto_scaling_group
      request :delete_launch_configuration
      request :delete_policy
      request :delete_scheduled_action
      request :describe_adjustment_types
      request :describe_auto_scaling_groups
      request :describe_auto_scaling_instances
      request :describe_launch_configurations
      request :describe_metric_collection_types
      request :describe_policies
      request :describe_scaling_activities
      request :describe_scaling_process_types
      request :describe_scheduled_actions
      request :disable_metrics_collection
      request :enable_metrics_collection
      request :execute_policy
      request :put_scaling_policy
      request :put_scheduled_update_group_action
      request :put_notification_configuration
      request :resume_processes
      request :set_desired_capacity
      request :set_instance_health
      request :suspend_processes
      request :terminate_instance_in_auto_scaling_group
      request :update_auto_scaling_group

      model_path 'fog/aws/models/auto_scaling'
      model      :activity
      collection :activities
      model      :configuration
      collection :configurations
      model      :group
      collection :groups
      model      :instance
      collection :instances
      model      :policy
      collection :policies

      class Real
        include Fog::AWS::CredentialFetcher::ConnectionMethods
        # Initialize connection to AutoScaling
        #
        # ==== Notes
        # options parameter must include values for :aws_access_key_id and
        # :aws_secret_access_key in order to create a connection
        #
        # ==== Examples
        #   as = AutoScaling.new(
        #    :aws_access_key_id => your_aws_access_key_id,
        #    :aws_secret_access_key => your_aws_secret_access_key
        #   )
        #
        # ==== Parameters
        # * options<~Hash> - config arguments for connection.  Defaults to {}.
        #
        # ==== Returns
        # * AutoScaling object with connection to AWS.
        def initialize(options={})
          require 'fog/core/parser'

          @use_iam_profile = options[:use_iam_profile]
          setup_credentials(options)

          @connection_options = options[:connection_options] || {}

          @instrumentor           = options[:instrumentor]
          @instrumentor_name      = options[:instrumentor_name] || 'fog.aws.auto_scaling'
          
          options[:region] ||= 'us-east-1'
          @host = options[:host] || "autoscaling.#{options[:region]}.amazonaws.com"
          @path       = options[:path]        || '/'
          @port       = options[:port]        || 443
          @persistent = options[:persistent]  || false
          @scheme     = options[:scheme]      || 'https'
          @connection = Fog::Connection.new("#{@scheme}://#{@host}:#{@port}#{@path}", @persistent, @connection_options)
        end

        def reload
          @connection.reset
        end

        private

        def request(params)
          refresh_credentials_if_expired

          idempotent  = params.delete(:idempotent)
          parser      = params.delete(:parser)

          body = AWS.signed_params(
            params,
            {
              :aws_access_key_id  => @aws_access_key_id,
              :aws_session_token  => @aws_session_token,
              :hmac               => @hmac,
              :host               => @host,
              :path               => @path,
              :port               => @port,
              :version            => '2011-01-01'
            }
          )

          if @instrumentor
            @instrumentor.instrument("#{@instrumentor_name}.request", params) do
              _request(body, idempotent, parser)
            end
          else
            _request(body, idempotent, parser)
          end
        end

        def _request(body, idempotent, parser)
          begin
            response = @connection.request({
              :body       => body,
              :expects    => 200,
              :idempotent => idempotent,
              :headers    => { 'Content-Type' => 'application/x-www-form-urlencoded' },
              :host       => @host,
              :method     => 'POST',
              :parser     => parser
            })
          rescue Excon::Errors::HTTPStatusError => error
            if match = error.message.match(/<Code>(.*)<\/Code>.*<Message>(.*)<\/Message>/)
              case match[1]
              when 'AlreadyExists'
                #raise Fog::AWS::AutoScaling::IdentifierTaken.new(match[2])
                raise Fog::AWS::AutoScaling::IdentifierTaken.slurp(error, match[2])
              when 'ResourceInUse'
                raise Fog::AWS::AutoScaling::ResourceInUse.slurp(error, match[2])
              when 'ValidationError'
                raise Fog::AWS::AutoScaling::ValidationError.slurp(error, match[2])
              else
                raise Fog::Compute::AWS::Error.slurp(error, "#{match[1]} => #{match[2]}")
              end
            else
             raise
            end
          end

          response
        end

        def setup_credentials(options)
          @aws_access_key_id      = options[:aws_access_key_id]
          @aws_secret_access_key  = options[:aws_secret_access_key]
          @aws_session_token      = options[:aws_session_token]
          @aws_credentials_expire_at = options[:aws_credentials_expire_at]

          @hmac       = Fog::HMAC.new('sha256', @aws_secret_access_key)
        end
      end


      class Mock

        def self.data
          @data ||= Hash.new do |hash, region|
            hash[region] = Hash.new do |region_hash, key|
              region_hash[key] = {
                :adjustment_types => [
                  'ChangeInCapacity',
                  'ExactCapacity',
                  'PercentChangeInCapacity'
                ],
                :auto_scaling_groups => {},
                :scaling_policies => {},
                :health_states => ['Healthy', 'Unhealthy'],
                :launch_configurations => {},
                :metric_collection_types => {
                  :granularities => [ '1Minute' ],
                  :metrics => [
                    'GroupMinSize',
                    'GroupMaxSize',
                    'GroupDesiredCapacity',
                    'GroupInServiceInstances',
                    'GroupPendingInstances',
                    'GroupTerminatingInstances',
                    'GroupTotalInstances'
                  ],
                },
                :process_types => [
                  'AZRebalance',
                  'AlarmNotification',
                  'HealthCheck',
                  'Launch',
                  'ReplaceUnhealthy',
                  'ScheduledActions',
                  'Terminate'
                ]
              }
            end
          end
        end

        def self.reset
          @data = nil
        end

        def initialize(options={})
          @use_iam_profile = options[:use_iam_profile]
          setup_credentials(options)
          @region = options[:region] || 'us-east-1'

          unless ['ap-northeast-1', 'ap-southeast-1', 'eu-west-1', 'sa-east-1', 'us-east-1', 'us-west-1', 'us-west-2'].include?(@region)
            raise ArgumentError, "Unknown region: #{@region.inspect}"
          end

        end

        def setup_credentials(options)
          @aws_access_key_id      = options[:aws_access_key_id]
        end

        def data
          self.class.data[@region][@aws_access_key_id]
        end

        def reset_data
          self.class.data[@region].delete(@aws_access_key_id)
        end

      end

    end
  end
end
