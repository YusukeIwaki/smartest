# frozen_string_literal: true

module Smartest
  class Reporter
    PASS_MARK = "\u2713"
    FAIL_MARK = "\u2717"

    def initialize(io = $stdout)
      @io = io
    end

    def start(count)
      @io.puts "Running #{count} #{count == 1 ? 'test' : 'tests'}"
      @io.puts
    end

    def record(result)
      mark = result.passed? ? PASS_MARK : FAIL_MARK
      @io.puts "#{mark} #{result.test_case.name}"
    end

    def finish(results)
      failures = results.select(&:failed?)

      report_failures(failures) if failures.any?

      @io.puts
      @io.puts "#{results.count} #{results.count == 1 ? 'test' : 'tests'}, #{results.count(&:passed?)} passed, #{failures.count} failed"
    end

    private

    def report_failures(failures)
      @io.puts
      @io.puts "Failures:"
      @io.puts

      failures.each_with_index do |result, index|
        @io.puts "#{index + 1}) #{result.test_case.name}"
        report_location(result.test_case.location)
        report_error(result.error) if result.error
        result.cleanup_errors.each { |error| report_cleanup_error(error) }
        @io.puts
      end
    end

    def report_location(location)
      return unless location

      @io.puts "   #{location.path}:#{location.lineno}"
    end

    def report_error(error)
      if error.is_a?(AssertionFailed)
        @io.puts "   #{error.message}"
      else
        @io.puts "   #{error.class}: #{error.message}"
      end

      report_backtrace(error)
    end

    def report_cleanup_error(error)
      @io.puts "   cleanup failed: #{error.class}: #{error.message}"
      report_backtrace(error)
    end

    def report_backtrace(error)
      backtrace_line = error.backtrace&.first
      @io.puts "   #{backtrace_line}" if backtrace_line
    end
  end
end
