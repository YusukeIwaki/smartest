# frozen_string_literal: true

require_relative "smartest/version"
require_relative "smartest/errors"
require_relative "smartest/parameter_extractor"
require_relative "smartest/test_case"
require_relative "smartest/test_registry"
require_relative "smartest/fixture_definition"
require_relative "smartest/fixture"
require_relative "smartest/fixture_class_registry"
require_relative "smartest/matcher_registry"
require_relative "smartest/helper_registry"
require_relative "smartest/fixture_set"
require_relative "smartest/suite"
require_relative "smartest/suite_run"
require_relative "smartest/test_run_state"
require_relative "smartest/test_run"
require_relative "smartest/hook_contexts"
require_relative "smartest/expectations"
require_relative "smartest/expectation_target"
require_relative "smartest/matchers"
require_relative "smartest/execution_context"
require_relative "smartest/dsl"
require_relative "smartest/test_result"
require_relative "smartest/reporter"
require_relative "smartest/runner"
require_relative "smartest/init_generator"
require_relative "smartest/init_browser_generator"
require_relative "smartest/cli_arguments"

module Smartest
  class << self
    def suite
      @suite ||= Suite.new
    end

    def reset!
      @suite = Suite.new
    end

    def disable_autorun!
      @autorun_disabled = true
    end

    def autorun_disabled?
      @autorun_disabled == true
    end

    def register_autorun!
      return if autorun_disabled?
      return if @autorun_registered

      @autorun_registered = true

      at_exit do
        exit Runner.new.run if $ERROR_INFO.nil?
      end
    end

    def fatal_exception?(error)
      error.is_a?(SystemExit) ||
        error.is_a?(Interrupt) ||
        error.is_a?(SignalException) ||
        error.is_a?(NoMemoryError)
    end
  end
end
