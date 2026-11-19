require 'fileutils'
require 'logger'

module SmarterLogging
  class BaseLogger
    # characters which are escaped inside a quoted value, so each log entry stays on one line and can be parsed
    ESCAPES = { '\\' => '\\\\', '"' => '\\"', "\n" => '\\n', "\r" => '\\r' }.freeze

    def initialize(log_filename)
      if defined?(Rails)
        log_filename = "#{Rails.root}/log/#{log_filename}"
      else
        FileUtils.mkdir_p './log'
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
        data[:error] = [exception.class, exception.message].join(' : ')
        data[:backtrace] = exception.backtrace[0..5].join(' | ') if exception.backtrace
      end

      extra_data = {
        :time => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
      }
      extra_data[:env] = Rails.env if defined?(Rails)
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
      result = []
      filter(data).each do |k,v|
        if v.to_s =~ /[\s"]/  # quote values with whitespace or double quotes
          v = "\"#{v.to_s.gsub(/[\\"\n\r]/, ESCAPES)}\""
        end

        result << "#{k}=#{v}"
      end
      result.join(' ')
    end

    # replace values of keys listed in Rails.application.config.filter_parameters with '[FILTERED]',
    # using the same matching rules as Rails (partial, case-insensitive matches; Regexps; Procs)
    def filter(data)
      return data unless defined?(Rails)

      filters = Rails.application.config.filter_parameters
      if defined?(ActiveSupport::ParameterFilter)
        ActiveSupport::ParameterFilter.new(filters).filter(data)
      else # Rails < 6.0
        ActionDispatch::Http::ParameterFilter.new(filters).filter(data)
      end
    end

  end

end
