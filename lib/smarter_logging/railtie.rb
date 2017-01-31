module SmarterLogging
  mattr_accessor :anomaly_logger
  mattr_accessor :activity_logger

  class Railtie < Rails::Railtie
    initializer 'smarter_logging.configure_rails_initialization' do |app|
      app.config.anomaly_logger = SmarterLogging.anomaly_logger = SmarterLogging::AnomalyLogger.new('anomaly.log')
      # make sure the activity logger has a reference to the anomaly logger, in case errors need to be logged:
      act_logger = SmarterLogging::ActivityLogger.new('activity.log')
      act_logger.anomaly_logger = SmarterLogging.anomaly_logger

      app.config.activity_logger = SmarterLogging.activity_logger = act_logger
    end
  end

  # after including SmarterLogging, you can simply use these convenience methods:

  def self.log_activity(unique_identifier, data, &block)
    activity_logger.log(unique_identifier, data, &block)
  end

  def self.log_anomaly(unique_identifier, data, &block)
    anomaly_logger.log(unique_identifier, data, &block)
  end

end

