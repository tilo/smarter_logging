module SmarterLogging

  module ControllerHelper
    KEYS = [:rqid, :ip, :user_agent]

    # returns the request ID from the header named in SmarterLogging.request_id_header, or a new random one
    # Rack stores a request header 'X-RQID' in the env as 'HTTP_X_RQID'
    def self.request_id(request)
      env_key = 'HTTP_' + SmarterLogging.request_id_header.to_s.upcase.tr('-', '_')
      rqid = request.env[env_key]
      (rqid.nil? || rqid.empty?) ? SecureRandom.hex(24) : rqid
    end

    def self.included(base)
      base.class_eval do
        before_action do
          # Get some basic info from the current thread, and add it to the log parameters:
          # The RequestID RQID can be passed-in on subsequent API-calls,
          # so if several APIs call each other, they can be traced with the initial call's RQID
          Thread.current[:rqid] = SmarterLogging::ControllerHelper.request_id(request)
          Thread.current[:ip] = request.remote_ip || request.ip
          Thread.current[:user_agent] = request.user_agent
        end
      end
    end

  end

end
