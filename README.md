# SmarterLogging

SmarterLogging helps you log mission critical data in key=value and single-line format, so it can be easily analyzed.
The format lends itself to being easily importable by SumoLogic and Splunk.

The main idea is to have dedicated log files for `activities` which happen during normal operations, as well as `anomalies` which happen when something unexpected happens.

Each log line starts with a UTC timestamp in [ISO8601 format](https://en.wikipedia.org/wiki/ISO_8601), and contains space-separated key=value pairs. If a value contains spaces, it is quoted: `key="value"`.
The advantage of ISO6801 timestamps is that they are both standardized / easy to parse, as well as human readable.

      time=2017-01-30T21:21:04.013Z activity=some_unique_name key1=value1 key2="value 2"
      
The only place where this gem is opinionated is that UTC time is used for logging.

**Tip:** If you are currently not using UTC time in your application, you should seriously consider doing that - it makes it much easier analyzing logs and errors when dealing with clients which can be anywhere in the world.

Key goals:

* get average call durations
* get activity and anomaly logs
* help forensics on any calls / trace incidents 
* quickly identify top anomalies
* get timings for blocks of code

## Installation

Add this line to your application's Gemfile:


    gem 'smarter_logging'


And then execute:

    $ bundle

Or install it yourself as:

    $ gem install smarter_logging

## Usage

When included in a Rails project, two default loggers are defined: 

    SmarterLogging.anomaly_logger
    SmarterLogging.activity_logger

Each of them provides a `log()` method. 

As a shortcut, you can `include SmarterLogging` and do this:

    SmarterLogging.log_anomaly(unique_key, params)
    SmarterLogging.log_activity(unique_key, params)

You can either use the above two functioncalls throughout your code, or include the module `SmarterLogging` and use the methods directly throughout your code.

## Examples

**Tip:** make sure that you use a globally unique naming convention for your anomaly and activity names -- this way you can pin-point what went wrong, and where it went wrong.

### Logging Anomalies
 Anomaly logs are meant to be used for errors, exceptions and caught unexpected behavior.

      include SmarterLogging
             # you can use a single-line log statement, with a hash of all key=value pairs
      log_anomaly( :invalid_parameter , {key1: 'value 1', key2: 'value 2'}     
      
      # or you can use a block - this will add a key `duration` to the log line.


      if parameters_valid?(params)
      
        # do something useful
        
        log_activity( :user_parameters, params )
        
      else 
        log_anomaly( :user_invalid_parameters ) do |logdata|		    
           log_data.merge( invalid_parameter_hash )

			 # some other code      	  	
			 
        end
      end

      
      
### Logging Activities

Anomaly logs are meant to be used for reporting on expected behavior.

      include SmarterLogging
      
      # you can use a single-line log statement, with a hash of all key=value pairs
      log_activity( :user_signed_up, {user_id: current_user.id} )
      => time=2017-01-30T23:15:20.689Z env=development activity=user_signed_up user_id=123
      
      # or you can use a block - this will add a key `duration` to the log line.
      log_activity( :user_updated ) do |logdata|
	     begin
	     
          # update some values in user record here
          
          logdata[:result] = :sucess
                   rescue => e
    	    log_data[:error_message] = e.message
      	  	
           logdata[:result] = :failure
        end
      end

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Tilo Sloboda/smarter_logging. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

