require 'smarter_logging/version'

require 'smarter_logging/base_logger'
require 'smarter_logging/anomaly_logger'
require 'smarter_logging/activity_logger'
require 'smarter_logging/controller_helper'

require 'smarter_logging/railtie' if defined?(Rails)

require 'securerandom'

module SmarterLogging
  class << self
    # name of the HTTP request header which carries the request ID (RQID) from a calling service
    attr_accessor :request_id_header
  end
  self.request_id_header = 'X-RQID'
end
