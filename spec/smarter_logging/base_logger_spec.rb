require 'spec_helper'
require 'logger'
require 'date'
require 'tmpdir'
require 'fileutils'
require 'active_support'
require 'active_support/parameter_filter'

# Issue #5: BaseLogger#reformat used `v =~ /\s/` on every value.
# For non-String values that calls Object#=~, which prints a deprecation warning on Ruby 2.7–3.1
# and was removed in Ruby 3.2 (NoMethodError).
RSpec.describe SmarterLogging::BaseLogger do
  let(:rails_root) { Dir.mktmpdir('smarter_logging') }
  let(:log_file) { File.join(rails_root, 'log', 'activity.log') }
  let(:logger) { SmarterLogging::ActivityLogger.new('activity.log') }
  let(:filter_parameters) { [:password] }

  def last_log_line
    File.readlines(log_file).last.chomp
  end

  before do
    FileUtils.mkdir_p(File.join(rails_root, 'log'))
    config = double('config', filter_parameters: filter_parameters)
    application = double('application', config: config)
    stub_const('Rails', double('Rails', root: rails_root, env: 'test', application: application))
    SmarterLogging::ControllerHelper::KEYS.each { |key| Thread.current[key] = nil }
  end

  after do
    FileUtils.rm_rf(rails_root)
  end

  around do |example|
    deprecated = Warning[:deprecated]
    Warning[:deprecated] = true  # Ruby 2.7.2+ hides deprecation warnings by default
    example.run
    Warning[:deprecated] = deprecated
  end

  describe 'non-String values' do
    {
      'Integer' => 42,
      'Float'   => 1.5,
      'Symbol'  => :jfk,
      'Date'    => Date.new(2014, 9, 15),
      'Time'    => Time.utc(2014, 9, 15, 10, 0, 0),
      'nil'     => nil,
    }.each do |type, value|
      it "does not raise for a #{type} value" do
        expect { logger.log(:test_activity, value: value) }.not_to raise_error
      end

      it "does not print a Ruby warning for a #{type} value" do
        expect { logger.log(:test_activity, value: value) }.not_to output.to_stderr
      end
    end

    it 'writes an Integer value unquoted' do
      logger.log(:schedule_uploaded, user_id: 42)
      expect(last_log_line).to end_with(' activity=schedule_uploaded user_id=42')
    end

    it 'writes a Float value unquoted' do
      logger.log(:test_activity, duration: 1.5)
      expect(last_log_line).to end_with(' duration=1.5')
    end

    it 'writes a Symbol value unquoted' do
      logger.log(:test_activity, format: :ics)
      expect(last_log_line).to end_with(' format=ics')
    end

    it 'writes a Date value unquoted' do
      logger.log(:airport_unknown_iata, date: Date.new(2014, 9, 15))
      expect(last_log_line).to end_with(' date=2014-09-15')
    end

    it 'quotes a Time value, because its text contains spaces' do
      logger.log(:schedule_uploaded, user_id: 42, started_at: Time.utc(2014, 9, 15, 10, 0, 0))
      expect(last_log_line).to end_with(' user_id=42 started_at="2014-09-15 10:00:00 UTC"')
    end

    it 'quotes an Array value, because its text contains spaces' do
      logger.log(:test_activity, ids: [1, 2])
      expect(last_log_line).to end_with(' ids="[1, 2]"')
    end

    it 'quotes a Hash value, because its text contains spaces' do
      value = { a: 1, b: 2 }
      logger.log(:test_activity, options: value)
      expect(last_log_line).to end_with(" options=\"#{value}\"")  # Hash#to_s differs between Ruby versions
    end

    it 'writes a nil value as an empty value' do
      logger.log(:airport_unknown_iata, user_id: nil)
      expect(last_log_line).to end_with(' user_id=')
    end
  end

  describe 'String values' do
    it 'quotes a String value that contains a space' do
      logger.log(:test_activity, msg: 'hello world')
      expect(last_log_line).to end_with(' msg="hello world"')
    end

    it 'does not quote a String value without a space' do
      logger.log(:airport_unknown_iata, iata: 'JFK')
      expect(last_log_line).to end_with(' iata=JFK')
    end

    it 'quotes a String value that contains a tab' do
      logger.log(:test_activity, msg: "hello\tworld")
      expect(last_log_line).to end_with(" msg=\"hello\tworld\"")
    end

    # inside a quoted value, \ " newline and carriage return are escaped, so each log entry stays one line and can be parsed
    it 'quotes a value with double quotes and spaces, and escapes the double quotes' do
      logger.log(:test_activity, msg: 'say "hi" now')
      expect(last_log_line).to end_with(' msg="say \"hi\" now"')
    end

    it 'quotes a value with a double quote and no space, and escapes the double quote' do
      logger.log(:test_activity, msg: 'a"b')
      expect(last_log_line).to end_with(' msg="a\"b"')
    end

    it 'writes a newline in a value as \n, so the log entry stays on one line' do
      logger.log(:test_activity, msg: "line 1\nline 2", user_id: 42)
      expect(File.readlines(log_file).last.chomp).to end_with(' msg="line 1\nline 2" user_id=42')
    end

    it 'writes a carriage return in a value as \r' do
      logger.log(:test_activity, msg: "line 1\r\nline 2")
      expect(last_log_line).to end_with(' msg="line 1\r\nline 2"')
    end

    it 'escapes a backslash inside a quoted value' do
      logger.log(:test_activity, path: 'C:\my dir')
      expect(last_log_line).to end_with(' path="C:\\\\my dir"')
    end

    it 'does not quote or escape a backslash in a value without whitespace or double quote' do
      logger.log(:test_activity, path: 'C:\tmp')
      expect(last_log_line).to end_with(' path=C:\tmp')
    end

    it 'writes an empty String value as an empty value' do
      logger.log(:test_activity, msg: '')
      expect(last_log_line).to end_with(' msg=')
    end
  end

  describe 'exception raised in the block' do
    it 'writes the exception class and message as error="Class : message"' do
      expect { logger.log(:test_activity, user_id: 42) { raise ArgumentError, 'bad input' } }.to raise_error(ArgumentError, 'bad input')
      expect(last_log_line).to include(' error="ArgumentError : bad input" ')
    end

    it 'writes the first lines of the backtrace, separated by " | "' do
      expect { logger.log(:test_activity, user_id: 42) { raise ArgumentError, 'bad input' } }.to raise_error(ArgumentError)
      expect(last_log_line).to match(/ backtrace="[^"]*base_logger_spec\.rb:\d+[^"]*"/)
    end

    it 'writes success=false and a duration' do
      expect { logger.log(:test_activity, user_id: 42) { raise ArgumentError, 'bad input' } }.to raise_error(ArgumentError)
      expect(last_log_line).to match(/ user_id=42 duration=\d+\.\d+ success=false /)
    end

    context 'when the activity logger has an anomaly logger' do
      let(:anomaly_log_file) { File.join(rails_root, 'log', 'anomaly.log') }

      before do
        logger.anomaly_logger = SmarterLogging::AnomalyLogger.new('anomaly.log')
      end

      it 'writes the line to the anomaly log only, with anomaly= instead of activity=' do
        expect { logger.log(:test_activity, user_id: 42) { raise ArgumentError, 'bad input' } }.to raise_error(ArgumentError, 'bad input')
        anomaly_line = File.readlines(anomaly_log_file).last.chomp
        expect(anomaly_line).to match(/ env=test anomaly=test_activity user_id=42 duration=\d+\.\d+ error="ArgumentError : bad input" backtrace="/)
        expect(File.readlines(log_file).grep(/activity=/)).to be_empty
      end
    end

    it 'does not raise for an exception object in the data which was never raised (backtrace is nil)' do
      expect { logger.log(:test_activity, exception: ArgumentError.new('bad input')) }.not_to raise_error
      expect(last_log_line).to include(' error="ArgumentError : bad input"')
    end
  end

  describe 'block without exception' do
    it 'returns the value of the block, and writes a duration' do
      result = logger.log(:test_activity, user_id: 42) { :block_result }
      expect(result).to eq(:block_result)
      expect(last_log_line).to match(/ user_id=42 duration=\d+\.\d+\z/)
    end
  end

  describe 'AnomalyLogger' do
    let(:anomaly_log_file) { File.join(rails_root, 'log', 'anomaly.log') }

    it 'writes anomaly= as the first key after time and env' do
      SmarterLogging::AnomalyLogger.new('anomaly.log').log(:airport_unknown_iata, iata: 'XXX')
      expect(File.readlines(anomaly_log_file).last.chomp).to match(/\Atime=\S+ env=test anomaly=airport_unknown_iata iata=XXX\z/)
    end
  end

  describe 'standard keys' do
    it 'starts each line with time in ISO 8601 UTC format, then env' do
      logger.log(:test_activity, user_id: 42)
      expect(last_log_line).to match(/\Atime=\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z env=test activity=test_activity user_id=42\z/)
    end

    it 'writes rqid, ip and user_agent from Thread.current, after env' do
      Thread.current[:rqid] = 'abc123'
      Thread.current[:ip] = '10.0.0.1'
      Thread.current[:user_agent] = 'Mozilla 5.0'
      logger.log(:test_activity, user_id: 42)
      expect(last_log_line).to match(/ env=test rqid=abc123 ip=10\.0\.0\.1 user_agent="Mozilla 5\.0" activity=test_activity user_id=42\z/)
    end
  end

  describe 'filter_parameters' do
    it 'writes [FILTERED] for a key listed in Rails.application.config.filter_parameters' do
      logger.log(:test_activity, password: 'secret value', user_id: 42)
      expect(last_log_line).to end_with(' password=[FILTERED] user_id=42')
    end

    # filter_parameters must be matched the same way Rails matches them (ActiveSupport::ParameterFilter):
    # Symbols and Strings match as case-insensitive substrings, Regexps match as Regexps.
    context 'with the Rails 7+ default filter_parameters' do
      let(:filter_parameters) { [:passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc] }

      it 'filters a key which contains a filter as a substring' do
        logger.log(:test_activity, password: 'abc', api_key: 'xyz', user_id: 42)
        expect(last_log_line).to end_with(' password=[FILTERED] api_key=[FILTERED] user_id=42')
      end

      it 'filters a String key' do
        logger.log(:test_activity, 'password' => 'abc', user_id: 42)
        expect(last_log_line).to end_with(' password=[FILTERED] user_id=42')
      end

      it 'filters independent of upper and lower case' do
        logger.log(:test_activity, PASSWORD: 'abc', user_id: 42)
        expect(last_log_line).to end_with(' PASSWORD=[FILTERED] user_id=42')
      end
    end

    context 'with a Regexp in filter_parameters' do
      let(:filter_parameters) { [/\Apin\z/] }

      it 'filters a key which matches the Regexp, and no other key' do
        logger.log(:test_activity, pin: '1234', spinner: 'on')
        expect(last_log_line).to end_with(' pin=[FILTERED] spinner=on')
      end
    end

    context 'with empty filter_parameters' do
      let(:filter_parameters) { [] }

      it 'does not filter any key' do
        logger.log(:test_activity, password: 'abc')
        expect(last_log_line).to end_with(' password=abc')
      end
    end

    context 'on Rails < 6.0, where only ActionDispatch::Http::ParameterFilter exists' do
      before do
        stub_const('ActionDispatch::Http::ParameterFilter', ActiveSupport::ParameterFilter)
        hide_const('ActiveSupport::ParameterFilter')
      end

      it 'filters with ActionDispatch::Http::ParameterFilter' do
        logger.log(:test_activity, password: 'abc', user_id: 42)
        expect(last_log_line).to end_with(' password=[FILTERED] user_id=42')
      end
    end
  end
end
