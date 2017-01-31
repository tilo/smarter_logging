module SmarterLogging

  class ActivityLogger < BaseLogger
    attr_accessor :anomaly_logger # to keep a reference to the anomaly logger

    def log(unique_identifier, data, &block)
      data = {:activity => unique_identifier}.merge( data )
      _log_wrapper(data, &block)
    end

  end

end
