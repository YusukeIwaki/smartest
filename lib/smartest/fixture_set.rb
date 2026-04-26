# frozen_string_literal: true

module Smartest
  class FixtureSet
    def initialize(fixture_classes, context:, scope: :test, parent: nil)
      @fixture_classes = fixture_classes.to_a
      @context = context
      @scope = normalize_scope(scope)
      @parent = parent
      @cache = {}
      @setup_errors = {}
      @cleanups = []
      @resolving = []

      build_fixture_index
    end

    def resolve_keywords(names)
      names.to_h do |name|
        symbol_name = name.to_sym
        [symbol_name, resolve(symbol_name)]
      end
    end

    def resolve(name)
      symbol_name = name.to_sym

      if @resolving.include?(symbol_name)
        cycle_start = @resolving.index(symbol_name)
        raise CircularFixtureDependencyError, @resolving[cycle_start..] + [symbol_name]
      end

      definition = @definitions[symbol_name]
      raise FixtureNotFoundError, symbol_name unless definition

      return resolve_from_parent(symbol_name, definition) unless definition.scope == @scope
      return @cache[symbol_name] if @cache.key?(symbol_name)
      raise @setup_errors[symbol_name] if @setup_errors.key?(symbol_name)

      @resolving << symbol_name
      dependencies = resolve_keywords(definition.dependencies)
      @cache[symbol_name] = @instances[symbol_name].instance_exec(**dependencies, &definition.block)
    rescue Exception => error
      raise if Smartest.fatal_exception?(error)

      @setup_errors[symbol_name] = error if definition&.scope == @scope
      raise
    ensure
      @resolving.pop if @resolving.last == symbol_name
    end

    def add_cleanup(&block)
      raise ArgumentError, "cleanup block is required" unless block

      @cleanups << block
    end

    def run_cleanups
      errors = []

      @cleanups.reverse_each do |cleanup|
        cleanup.call
      rescue Exception => error
        raise if Smartest.fatal_exception?(error)

        errors << error
      end

      errors
    end

    private

    def normalize_scope(scope)
      symbol_scope = scope.to_sym
      return symbol_scope if FixtureDefinition::VALID_SCOPES.include?(symbol_scope)

      raise InvalidFixtureScopeError, scope
    rescue NoMethodError
      raise InvalidFixtureScopeError, scope
    end

    def resolve_from_parent(name, definition)
      return @parent.resolve(name) if @parent && definition.scope == :suite

      raise InvalidFixtureScopeDependencyError.new(
        dependent_name: @resolving.last,
        dependent_scope: @scope,
        dependency_name: name,
        dependency_scope: definition.scope
      )
    end

    def build_fixture_index
      definitions_by_name = Hash.new { |hash, key| hash[key] = [] }
      instances_by_class = {}

      @fixture_classes.each do |fixture_class|
        instances_by_class[fixture_class] = fixture_class.new(fixture_set: self, context: @context)

        fixture_class.fixture_definitions.each_value do |definition|
          definitions_by_name[definition.name] << [fixture_class, definition]
        end
      end

      duplicate = definitions_by_name.find { |_name, entries| entries.length > 1 }
      raise DuplicateFixtureError.new(duplicate.first, duplicate.last.map(&:first)) if duplicate

      @definitions = {}
      @instances = {}

      definitions_by_name.each do |name, entries|
        fixture_class, definition = entries.first
        @definitions[name] = definition
        @instances[name] = instances_by_class[fixture_class]
      end
    end
  end
end
