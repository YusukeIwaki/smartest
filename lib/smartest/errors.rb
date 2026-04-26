# frozen_string_literal: true

module Smartest
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

  class AssertionFailed < Error; end
end
