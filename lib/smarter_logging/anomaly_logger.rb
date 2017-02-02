module SmarterLogging

  class AnomalyLogger < BaseLogger

    def log(unique_identifier, data, &block)
      data = {:anomaly => unique_identifier}.merge( data )
      _log_wrapper(data, &block)
    end

    def _log(data)
      # If activity logging broke, make sure we log it as an anomaly:
      data[:anomaly] = data.delete(:activity) if data[:activity]
      super
    end
  end

end
