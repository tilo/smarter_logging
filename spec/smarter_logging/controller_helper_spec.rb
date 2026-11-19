require 'spec_helper'

# Issue #2: make the request ID header (X-RQID) configurable.
# Also: `request.headers['X_RQID']` never found the header, because Rails only adds the `HTTP_` prefix
# for names without an underscore, and Rack stores the header as `HTTP_X_RQID`.
RSpec.describe SmarterLogging::ControllerHelper do
  def request_with(env)
    double('request', env: env)
  end

  after do
    SmarterLogging.request_id_header = 'X-RQID'
  end

  # A plain Ruby class with the two parts of a Rails controller which ControllerHelper uses:
  # the class method `before_action` with a block, and the instance method `request`.
  # Rails runs a before_action block with instance_exec on the controller.
  describe 'included in a controller' do
    let(:controller_class) do
      Class.new do
        def self.before_actions
          @before_actions ||= []
        end

        def self.before_action(&block)
          before_actions << block
        end

        attr_accessor :request

        def run_before_actions
          self.class.before_actions.each { |block| instance_exec(&block) }
        end

        include SmarterLogging::ControllerHelper
      end
    end

    def run_with(request)
      controller = controller_class.new
      controller.request = request
      controller.run_before_actions
    end

    after do
      SmarterLogging::ControllerHelper::KEYS.each { |key| Thread.current[key] = nil }
    end

    it 'registers one before_action' do
      expect(controller_class.before_actions.size).to eq(1)
    end

    it 'sets Thread.current[:rqid], [:ip] and [:user_agent] from the request' do
      run_with(double('request', env: { 'HTTP_X_RQID' => 'abc123' }, remote_ip: '10.0.0.1', ip: '192.168.0.1', user_agent: 'Mozilla 5.0'))
      expect(Thread.current[:rqid]).to eq('abc123')
      expect(Thread.current[:ip]).to eq('10.0.0.1')
      expect(Thread.current[:user_agent]).to eq('Mozilla 5.0')
    end

    it 'uses request.ip when request.remote_ip is nil' do
      run_with(double('request', env: {}, remote_ip: nil, ip: '192.168.0.1', user_agent: nil))
      expect(Thread.current[:ip]).to eq('192.168.0.1')
    end

    it 'sets a new 48-character hex rqid when the request has no request ID header' do
      run_with(double('request', env: {}, remote_ip: '10.0.0.1', ip: '10.0.0.1', user_agent: nil))
      expect(Thread.current[:rqid]).to match(/\A\h{48}\z/)
    end
  end

  it 'uses X-RQID as the default request ID header' do
    expect(SmarterLogging.request_id_header).to eq('X-RQID')
  end

  describe '.request_id' do
    it 'returns the value of the X-RQID header (Rack env key HTTP_X_RQID)' do
      expect(SmarterLogging::ControllerHelper.request_id(request_with('HTTP_X_RQID' => 'abc123'))).to eq('abc123')
    end

    it 'generates a new 48-character hex request ID when the header is missing' do
      expect(SmarterLogging::ControllerHelper.request_id(request_with({}))).to match(/\A\h{48}\z/)
    end

    it 'generates a new 48-character hex request ID when the header is empty' do
      expect(SmarterLogging::ControllerHelper.request_id(request_with('HTTP_X_RQID' => ''))).to match(/\A\h{48}\z/)
    end

    it 'generates a different request ID for each request without the header' do
      first = SmarterLogging::ControllerHelper.request_id(request_with({}))
      second = SmarterLogging::ControllerHelper.request_id(request_with({}))
      expect(first).not_to eq(second)
    end

    context 'with SmarterLogging.request_id_header = "X-Request-Id"' do
      before do
        SmarterLogging.request_id_header = 'X-Request-Id'
      end

      it 'returns the value of the configured header (Rack env key HTTP_X_REQUEST_ID)' do
        expect(SmarterLogging::ControllerHelper.request_id(request_with('HTTP_X_REQUEST_ID' => 'req-42'))).to eq('req-42')
      end

      it 'ignores the X-RQID header' do
        expect(SmarterLogging::ControllerHelper.request_id(request_with('HTTP_X_RQID' => 'abc123'))).to match(/\A\h{48}\z/)
      end
    end

    it 'accepts a header name in lower case' do
      SmarterLogging.request_id_header = 'x-request-id'
      expect(SmarterLogging::ControllerHelper.request_id(request_with('HTTP_X_REQUEST_ID' => 'req-42'))).to eq('req-42')
    end

    it 'accepts a header name with underscores' do
      SmarterLogging.request_id_header = 'X_REQUEST_ID'
      expect(SmarterLogging::ControllerHelper.request_id(request_with('HTTP_X_REQUEST_ID' => 'req-42'))).to eq('req-42')
    end
  end
end
