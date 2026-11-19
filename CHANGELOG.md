# SmarterLogging Change Log

## 1.1.0 (2026-11-19)

### New feature

- The request ID header is configurable: `SmarterLogging.request_id_header = 'X-Request-Id'`. Default: `'X-RQID'`. ([#2](https://github.com/tilo/smarter_logging/issues/2))

### Bug fixes

- **Security:** `filter_parameters` are now matched like Rails does (partial, case-insensitive, Regexp and Proc entries). With the Rails 7+ defaults, keys like `password` and `api_key` were not filtered before.
- Fixed `NoMethodError` on Ruby 3.2+ when logging non-String values such as Integer, Float, Date or Time. ([#5](https://github.com/tilo/smarter_logging/issues/5))
- The request ID from an incoming `X-RQID` header is now used. Before, every request got a new request ID. ([#2](https://github.com/tilo/smarter_logging/issues/2))
- Fixed `NoMethodError` on Rails 5.1+ when a controller includes `SmarterLogging::ControllerHelper`.
- `error=` now contains the exception class and message, e.g. `error="ArgumentError : bad input"`. Before, it was empty.
- Fixed `NoMethodError` when the logged data contains an exception that was never raised.
- Creating loggers and logging now work without Rails. The `env` key is then not written.

### Changes in the log output

- Values are quoted when they contain whitespace or `"`, for all types, e.g. `started_at="2014-09-15 10:00:00 UTC"`. Before, only Strings with whitespace were quoted.
- Inside quoted values, `\`, `"`, newline and carriage return are escaped as `\\`, `\"`, `\n` and `\r`, e.g. `msg="say \"hi\" now"`. Each log entry is now always one line.
- When an exception in an activity block is logged to the anomaly log, `anomaly=` now comes right after the standard keys.

### Compatibility

- Rails 3.x is no longer supported.
- Added a dependency on the `logger` gem.
