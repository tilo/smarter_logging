require 'spec_helper'
require 'logger'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'rbconfig'

RSpec.describe SmarterLogging::BaseLogger, 'without Rails' do
  around do |example|
    Dir.mktmpdir('smarter_logging') do |dir|
      Dir.chdir(dir) { example.run }
    end
  end

  before do
    hide_const('Rails')
    SmarterLogging::ControllerHelper::KEYS.each { |key| Thread.current[key] = nil }
  end

  it 'writes a log line without the env key, and does not filter any key' do
    logger = SmarterLogging::ActivityLogger.new('activity.log')
    expect { logger.log(:test_activity, user_id: 42, password: 'secret') }.not_to raise_error
    expect(File.readlines('./log/activity.log').last.chomp).to match(/\Atime=\S+ activity=test_activity user_id=42 password=secret\z/)
  end

  # runs in a separate Ruby process, because in this process Logger is already loaded
  it 'loads Logger itself: require "smarter_logging" and logging work in a plain Ruby process' do
    lib = File.expand_path('../../lib', __dir__)
    script = "require 'smarter_logging'; SmarterLogging::ActivityLogger.new('activity.log').log(:test_activity, user_id: 42)"
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, '-I', lib, '-e', script)
    expect(status.success?).to be(true), stderr
    expect(stderr).not_to include('smarter_logging')
    expect(File.readlines('./log/activity.log').last.chomp).to match(/\Atime=\S+ activity=test_activity user_id=42\z/)
  end

  it 'creates ./log and opens the log file in it' do
    expect { SmarterLogging::BaseLogger.new('activity.log') }.not_to raise_error
    expect(File.exist?('./log/activity.log')).to be true
  end

  it 'works when ./log already exists, for example when a second logger is created' do
    SmarterLogging::BaseLogger.new('activity.log')
    expect { SmarterLogging::BaseLogger.new('anomaly.log') }.not_to raise_error
    expect(File.exist?('./log/anomaly.log')).to be true
  end
end
