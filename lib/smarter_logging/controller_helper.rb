module SmarterLogging

  module ControllerHelper
    KEYS = [:rqid, :ip, :user_agent]

    def self.included(base)
      base.class_eval do
        before_filter do
          # Get some basic info from the current thread, and add it to the log parameters:
          # The RequestID RQID can be passed-in on subsequent API-calls,
          # so if several APIs call each other, they can be traced with the initial call's RQID
          Thread.current[:rqid] = request.headers['X_RQID'] || ::SmarterLogging::Extensions::String.random(24)
          Thread.current[:ip] = request.remote_ip || request.ip
          Thread.current[:user_agent] = request.user_agent
        end
      end
    end

  end

end
