# frozen_string_literal: true

module Smartest
  module StatusReason
    DEFAULT_REASON = "No reason given"

    def self.normalize(reason)
      text = reason.to_s
      text.empty? ? DEFAULT_REASON : text
    end
  end

  class Error < StandardError; end

  class FixtureNotFoundError < Error
    def initialize(name)
      super("fixture not found: #{name}")
    end
  end

  class DuplicateFixtureError < Error
    def initialize(name, fixture_classes)
      class_names = fixture_classes.map { |klass| klass.name || klass.inspect }

      super(<<~MESSAGE.chomp)
        duplicate fixture: #{name}
        defined in:
        #{class_names.map { |class_name| "  #{class_name}" }.join("\n")}
      MESSAGE
    end
  end

  class CircularFixtureDependencyError < Error
    def initialize(path)
      super("circular fixture dependency: #{path.join(' -> ')}")
    end
  end

  class InvalidFixtureScopeError < Error
    def initialize(scope)
      super("invalid fixture scope: #{scope.inspect}; supported scopes: test, suite")
    end
  end

  class InvalidFixtureScopeDependencyError < Error
    def initialize(dependent_name:, dependent_scope:, dependency_name:, dependency_scope:)
      message =
        if dependent_name
          "#{dependent_scope}-scoped fixture #{dependent_name} cannot depend on #{dependency_scope}-scoped fixture #{dependency_name}"
        else
          "cannot resolve #{dependency_scope}-scoped fixture #{dependency_name} from #{dependent_scope} fixture scope"
        end

      super(message)
    end
  end

  class InvalidFixtureParameterError < Error; end

  class AroundSuiteRunError < Error; end

  class AroundTestFixtureScopeError < Error
    def initialize(fixture_class, fixture_names)
      class_name = fixture_class.name || fixture_class.inspect
      names = fixture_names.map { |fixture_name| ":#{fixture_name}" }.join(", ")

      super(
        "#{class_name} cannot be registered from around_test because it defines suite-scoped fixtures: #{names}. " \
        "Register fixture classes with suite_fixture from around_suite instead."
      )
    end
  end

  class AroundTestRunError < Error; end

  class AssertionFailed < Error; end

  class Skipped < Error
    attr_reader :reason

    def initialize(reason = nil)
      @reason = StatusReason.normalize(reason)
      super(@reason)
    end
  end

  class PendingPassedError < AssertionFailed
    def initialize(reason = nil)
      super("expected pending test to fail, but it passed: #{StatusReason.normalize(reason)}")
    end
  end
end
