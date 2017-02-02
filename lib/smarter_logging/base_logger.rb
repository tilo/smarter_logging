require 'fileutils'

module SmarterLogging
  class BaseLogger

    def initialize(log_filename)
      if defined?(Rails)
        log_filename = "#{Rails.root}/log/#{log_filename}"
      else
        FilUtils.mkdir './log'
        log_filename = "./log/#{log_filename}"
      end
      @logger = Logger.new(log_filename)
      @logger.formatter = nil if @logger.respond_to?(:formatter)
    end

    # this wrapper around _log() handles blocks and errors which could handle in a block
    # if there is an exception during evaluation of the block, we log it as an anomaly and re-raise the exception
    def _log_wrapper(data={}, &block)
      had_anomaly = false
      if block_given?
        begin
          start = Time.now.utc  # to measure duration of the block
          result = yield(data)
          data[:duration] = ((Time.now.utc - start) * 1000).to_f.round(3) # in ms
          result

        rescue => e
          data[:exception] = e
          data[:duration] = ((Time.now.utc - start) * 1000).to_f.round(3) # in ms

          # we should log this to the anomaly logger also if one is defined
          if @anomaly_logger
            @anomaly_logger._log( data )
            had_anomaly = true
          else
            data[:success] = false
          end
          raise # re-raise
        ensure
          # log it, even if there is no anomaly logger
          _log( data ) unless had_anomaly  # if it was logged as an anomaly, don't log again
        end

      else # without a block, just call the lowest-level logging
        _log( data )
      end
    end

    # lowest-level logging method:
    def _log(data)
      if exception = data.delete(:exception)
        data[:error] = [exception.class, exception.message].join[' : ']
        data[:backtrace] = exception.backtrace[0..5].join(' | ')
      end

      extra_data = {
        :time => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
        :env => Rails.env,
      }
      SmarterLogging::ControllerHelper::KEYS.each do |key|
        extra_data[key] = Thread.current[key] if Thread.current[key]
      end

      data = extra_data.merge( data )
      # using low-level logging:
      @logger << reformat( data ) + "\n"
    end

    private
    # reformat incoming values, and make sure they are not listed in the Rails Filter Parameters
    def reformat(data)
      filtered_keys = Rails.application.config.filter_parameters.map{|x| x.to_s}
      result = []
      data.each do |k,v|
        if filtered_keys.include?(k.to_s)
          v = '[FILTERED]'
        elsif v =~ /\s/  # quote values with spaces
          v = "\"#{v}\""
        end

        result << "#{k}=#{v}"
      end
      result.join(' ')
    end

  end

end
