# frozen_string_literal: true

module Smartest
  class Reporter
    PASS_MARK = "\u2713"
    FAIL_MARK = "\u2717"
    SKIP_MARK = "-"
    PENDING_MARK = "*"

    def initialize(io = $stdout, profile_count: nil)
      @io = io
      @profile_count = profile_count
    end

    def start(count)
      @io.puts "Running #{count} #{count == 1 ? 'test' : 'tests'}"
      @io.puts
    end

    def record(result)
      @io.puts record_line(result)
    end

    def finish(results, suite_teardown_errors: [], suite_errors: [])
      failures = results.select(&:failed?)
      skipped = results.select(&:skipped?)
      pending = results.select(&:pending?)

      report_failures(failures) if failures.any?
      report_suite_errors(suite_errors) if suite_errors.any?
      report_suite_teardown_errors(suite_teardown_errors) if suite_teardown_errors.any?
      report_profile(results) if @profile_count && @profile_count.positive?

      @io.puts
      summary = "#{results.count} #{results.count == 1 ? 'test' : 'tests'}, #{results.count(&:passed?)} passed, #{failures.count} failed"
      summary = "#{summary}, #{skipped.count} skipped" if skipped.any?
      summary = "#{summary}, #{pending.count} pending" if pending.any?
      if suite_errors.any?
        suite_label = suite_errors.count == 1 ? "suite failure" : "suite failures"
        summary = "#{summary}, #{suite_errors.count} #{suite_label}"
      end
      if suite_teardown_errors.any?
        teardown_label = suite_teardown_errors.count == 1 ? "suite teardown" : "suite teardowns"
        summary = "#{summary}, #{suite_teardown_errors.count} #{teardown_label} failed"
      end
      @io.puts summary
    end

    private

    def record_line(result)
      case result.status
      when :passed
        "#{PASS_MARK} #{result.test_case.name}"
      when :failed
        "#{FAIL_MARK} #{result.test_case.name}"
      when :skipped
        "#{SKIP_MARK} #{result.test_case.name} (skipped: #{result.reason})"
      when :pending
        "#{PENDING_MARK} #{result.test_case.name} (pending: #{result.reason})"
      else
        "#{FAIL_MARK} #{result.test_case.name}"
      end
    end

    def report_failures(failures)
      @io.puts
      @io.puts "Failures:"
      @io.puts

      failures.each_with_index do |result, index|
        @io.puts "#{index + 1}) #{result.test_case.name}"
        report_location(result.test_case.location)
        report_error(result.error) if result.error
        result.teardown_errors.each { |error| report_teardown_error(error) }
        @io.puts
      end
    end

    def report_suite_errors(errors)
      @io.puts
      @io.puts "Suite failures:"
      @io.puts

      errors.each_with_index do |error, index|
        @io.puts "#{index + 1}) suite"
        report_error(error)
        @io.puts
      end
    end

    def report_suite_teardown_errors(errors)
      @io.puts
      @io.puts "Suite teardown failures:"
      @io.puts

      errors.each_with_index do |error, index|
        @io.puts "#{index + 1}) suite teardown"
        report_teardown_error(error)
        @io.puts
      end
    end

    def report_profile(results)
      timed = results.select { |result| result.duration }
      return if timed.empty?

      count = [@profile_count, timed.length].min
      slowest = timed.sort_by { |result| -result.duration }.first(count)
      total_duration = timed.sum(&:duration)
      slowest_duration = slowest.sum(&:duration)
      percent = total_duration.positive? ? (slowest_duration / total_duration) * 100 : 0.0

      @io.puts
      @io.puts "Top #{count} slowest #{count == 1 ? 'test' : 'tests'} " \
               "(#{format_duration(slowest_duration)} seconds, #{format('%.1f', percent)}% of total time):"

      slowest.each do |result|
        @io.puts "  #{result.test_case.name}"
        location_suffix = profile_location_suffix(result.test_case.location)
        @io.puts "    #{format_duration(result.duration)} seconds#{location_suffix}"
      end
    end

    def profile_location_suffix(location)
      return "" unless location

      " #{location.path}:#{location.lineno}"
    end

    def format_duration(seconds)
      format("%.5f", seconds)
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

    def report_teardown_error(error)
      @io.puts "   teardown failed: #{error.class}: #{error.message}"
      report_backtrace(error)
    end

    def report_backtrace(error)
      backtrace_line = error.backtrace&.first
      @io.puts "   #{backtrace_line}" if backtrace_line
    end
  end
end
