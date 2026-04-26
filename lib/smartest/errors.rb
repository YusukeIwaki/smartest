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

  class InvalidFixtureParameterError < Error; end

  class AssertionFailed < Error; end
end
