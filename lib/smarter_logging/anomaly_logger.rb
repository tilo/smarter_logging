module SmarterLogging

  class AnomalyLogger < BaseLogger

    def log(unique_identifier, data, &block)
      data = {:anomaly => unique_identifier}.merge( data )
      _log_wrapper(data, &block)
    end

    def _log(data)
      # If activity logging broke, make sure we log it as an anomaly:
      # (keep anomaly= in the position of activity=, right after the standard keys)
      data = {:anomaly => data.delete(:activity)}.merge( data ) if data[:activity]
      super
    end
  end

end
