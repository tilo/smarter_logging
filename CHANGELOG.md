# SmarterLogging Change Log

## 1.1.0 (unreleased)

### New feature

- The request header that carries the request ID (RQID) is now configurable: `SmarterLogging.request_id_header = 'X-Request-Id'`. The default is `'X-RQID'`. ([#2](https://github.com/tilo/smarter_logging/issues/2))

### Bug fix

- **Security:** values of keys listed in `Rails.application.config.filter_parameters` are now filtered with the same rules as Rails (`ActiveSupport::ParameterFilter`, or `ActionDispatch::Http::ParameterFilter` on Rails < 6.0). Before, a key was only filtered when its name was exactly equal to an entry. With the Rails 7+ default `filter_parameters` (`:passw`, `:secret`, `:token`, ...), `password=...` and `api_key=...` were written in clear text. Matching is now partial and case-insensitive, and Regexp and Proc entries work.
- Fixed reading the request ID from the incoming request. `request.headers['X_RQID']` never found the header, because Rails only adds the `HTTP_` prefix for header names without an underscore, and Rack stores the header as `HTTP_X_RQID`. So every request got a new random RQID, and RQIDs passed between services were lost. An empty header value is treated as missing. ([#2](https://github.com/tilo/smarter_logging/issues/2))
- Fixed `NoMethodError: undefined method 'before_filter'` on Rails 5.1 and newer when a controller includes `SmarterLogging::ControllerHelper`. It now uses `before_action`, which exists since Rails 4.0. Rails 3.x is no longer supported.
- Fixed `NoMethodError: undefined method '=~'` on Ruby 3.2 and newer when a value passed to `SmarterLogging.log_activity` or `SmarterLogging.log_anomaly` is not a String (for example an Integer, Float, Date or Time). On Ruby 2.7 to 3.1 the same values printed `warning: deprecated Object#=~ is called on Integer; it always returns nil`. ([#5](https://github.com/tilo/smarter_logging/issues/5))
- Fixed the `error` value when a block passed to `log_activity` / `log_anomaly` raises an exception. It was empty (`error=`) because of `.join[' : ']`; it is now written as `error="ArgumentError : bad input"`.
- Fixed `NoMethodError: undefined method '[]' for nil` when the data contains an exception object which was never raised, so its `backtrace` is nil. The `backtrace` key is then not written.
- Fixed `NameError: uninitialized constant SmarterLogging::BaseLogger::FilUtils` when a logger is created without Rails (typo for `FileUtils`).
- Fixed `Errno::EEXIST` when a logger is created without Rails and `./log` already exists, for example when the second logger is created. `FileUtils.mkdir` is now `FileUtils.mkdir_p`.
- Fixed `NameError: uninitialized constant SmarterLogging::BaseLogger::Rails` when logging without Rails. Without Rails, the `env` key is not written and no keys are filtered. `base_logger.rb` now does `require 'logger'` itself, because without Rails nothing else loads `Logger`.

### Dependencies

- Added a runtime dependency on the `logger` gem. On Ruby 3.4 `require 'logger'` from the standard library prints a warning, and from Ruby 3.5 on `logger` is no longer a default gem.
- Added a development dependency on `activesupport` (>= 6.0), used by the tests for `filter_parameters`.

### Other

- Added `changelog_uri` to the gemspec metadata, so rubygems.org links to this file.

### Behavior change

- A value is now quoted when its `to_s` contains whitespace, also when the value is not a String. Before, only String values were quoted. Example: a Time value is now written as `started_at="2014-09-15 10:00:00 UTC"` instead of `started_at=2014-09-15 10:00:00 UTC`. The same applies to Arrays, Hashes and other objects whose text contains a space.
- A value which contains a `"` is now quoted too. Inside a quoted value, `\`, `"`, newline and carriage return are now escaped as `\\`, `\"`, `\n` and `\r`. Before, a newline in a value split the log entry into two lines, and a `"` in a value made the line impossible to parse. Example: `msg="say \"hi\" now"`. A value without whitespace and without `"` is written unchanged, for example `path=C:\tmp`.
- When an exception in an `activity` block is written to the anomaly log, `anomaly=` is now the first key after the standard keys (`time`, `env`, `rqid`, `ip`, `user_agent`), the same as in all other anomaly log lines. Before, it was written after the caller's keys.
