require 'smarter_logging/version'

require 'smarter_logging/base_logger'
require 'smarter_logging/anomaly_logger'
require 'smarter_logging/activity_logger'
require 'smarter_logging/controller_helper'

require 'smarter_logging/railtie' if defined?(Rails)

require 'securerandom'

module SmarterLogging
  # Your code goes here...
end
