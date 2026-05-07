# frozen_string_literal: true

require "digest"

module Smartest
  class SimpleStub
    STORAGE_KEY = :__smartest_simple_stub

    class AlreadyAppliedError < Smartest::Error; end
    class NotAppliedError < Smartest::Error; end

    class FiberLocalStore
      class << self
        def current
          Thread.current[SimpleStub::STORAGE_KEY] ||= new
        end

        def current_if_defined
          Thread.current[SimpleStub::STORAGE_KEY]
        end

        def clear_current_if_empty
          store = Thread.current[SimpleStub::STORAGE_KEY]
          Thread.current[SimpleStub::STORAGE_KEY] = nil if store&.empty?
        end
      end

      private_class_method :new

      def initialize
        @stubs = {}
      end

      def fetch(key, default = nil)
        @stubs.fetch(key, default)
      end

      def set(key, implementation)
        @stubs[key] = implementation
      end

      def delete(key)
        @stubs.delete(key)
      end

      def key?(key)
        @stubs.key?(key)
      end

      def empty?
        @stubs.empty?
      end

      def clear
        @stubs.clear
      end

      def to_h
        @stubs.dup
      end

      alias [] fetch
      alias []= set
    end

    class SharedStore
      def initialize
        @mutex = Mutex.new
        @stubs = {}
      end

      def fetch(key, default = nil)
        @mutex.synchronize { @stubs.fetch(key, default) }
      end

      def set(key, implementation)
        @mutex.synchronize { @stubs[key] = implementation }
      end

      def delete(key)
        @mutex.synchronize { @stubs.delete(key) }
      end

      def key?(key)
        @mutex.synchronize { @stubs.key?(key) }
      end

      def empty?
        @mutex.synchronize { @stubs.empty? }
      end

      def clear
        @mutex.synchronize { @stubs.clear }
      end

      def to_h
        @mutex.synchronize { @stubs.dup }
      end

      alias [] fetch
      alias []= set
    end

    class << self
      def implementation_for(klass_key, method_name)
        lookup_store&.fetch(stub_key(klass_key, method_name), nil)
      end

      def active_stubs
        current_store
      end

      def clear_active_stubs_if_empty
        return if process_store

        FiberLocalStore.clear_current_if_empty
      end

      def current_stubs
        store = lookup_store
        store&.empty? ? nil : store
      end

      def current_store
        process_store || FiberLocalStore.current
      end

      def with_process_store(store)
        unless store.respond_to?(:fetch) && store.respond_to?(:set) && store.respond_to?(:delete)
          raise ArgumentError, "store must respond to fetch, set, and delete"
        end

        previous_store = nil
        process_store_mutex.synchronize do
          previous_store = @process_store
          @process_store = store
        end

        yield
      ensure
        process_store_mutex.synchronize { @process_store = previous_store }
        store.clear if store.respond_to?(:clear)
      end

      def ensure_dispatcher_method(klass, klass_key, method_name)
        dispatcher_mutex.synchronize do
          mod = dispatcher_module_for(klass, klass_key)
          next if mod.method_defined?(method_name) || mod.private_method_defined?(method_name)

          mod.define_method(method_name) do |*args, **kwargs, &block|
            implementation = SimpleStub.implementation_for(klass_key, method_name)

            if implementation
              SimpleStub.call_implementation(self, implementation, args, kwargs, block)
            elsif kwargs.empty?
              super(*args, &block)
            else
              super(*args, **kwargs, &block)
            end
          end
        end
      end

      def stub_key(klass_key, method_name)
        [klass_key, method_name]
      end

      def call_implementation(receiver, implementation, args, kwargs, block)
        return call_implementation_with_block(receiver, implementation, args, kwargs, block) if block

        if kwargs.empty?
          receiver.instance_exec(*args, &implementation)
        else
          receiver.instance_exec(*args, **kwargs, &implementation)
        end
      end

      def call_implementation_with_block(receiver, implementation, args, kwargs, block)
        method_name = next_call_method_name
        singleton_class = receiver.singleton_class
        singleton_class.__send__(:define_method, method_name, &implementation)

        if kwargs.empty?
          receiver.__send__(method_name, *args, &block)
        else
          receiver.__send__(method_name, *args, **kwargs, &block)
        end
      ensure
        if singleton_class &&
            (singleton_class.method_defined?(method_name) || singleton_class.private_method_defined?(method_name))
          singleton_class.__send__(:remove_method, method_name)
        end
      end

      private

      def process_store
        process_store_mutex.synchronize { @process_store }
      end

      def lookup_store
        process_store || FiberLocalStore.current_if_defined
      end

      def process_store_mutex
        @process_store_mutex ||= Mutex.new
      end

      def dispatcher_module_for(klass, klass_key)
        const_name = dispatcher_module_name(klass_key)

        if const_defined?(const_name, false)
          const_get(const_name, false)
        else
          Module.new.tap do |mod|
            const_set(const_name, mod)
            klass.prepend(mod)
          end
        end
      end

      def dispatcher_module_name(klass_key)
        "StubDispatcher#{klass_key}"
      end

      def dispatcher_mutex
        @dispatcher_mutex ||= Mutex.new
      end

      def next_call_method_name
        call_mutex.synchronize do
          @call_sequence ||= 0
          @call_sequence += 1
          :"__smartest_simple_stub_call_#{@call_sequence}"
        end
      end

      def call_mutex
        @call_mutex ||= Mutex.new
      end
    end

    def initialize(klass, method_name, &implementation)
      raise ArgumentError, "klass must be a Class. #{klass.class} specified." unless klass.is_a?(Class)
      raise ArgumentError, "method name must be a Symbol." unless method_name.is_a?(Symbol)

      @klass = klass
      @method_name = method_name
      @implementation = implementation
    end

    def apply
      return if stub_defined?

      apply_stub
    end

    def apply!
      raise AlreadyAppliedError, "stub for #{@klass}##{@method_name} is already applied" if stub_defined?

      apply_stub
    end

    def reset
      return unless stub_defined?

      reset_stub
    end

    def reset!
      raise NotAppliedError, "stub for #{@klass}##{@method_name} is not applied" unless stub_defined?

      reset_stub
    end

    private

    def apply_stub
      raise ArgumentError, "block must be given for applying stub" unless @implementation

      self.class.ensure_dispatcher_method(@klass, klass_key, @method_name)
      active_stubs.set(stub_key, @implementation)
    end

    def reset_stub
      active_stubs.delete(stub_key)
      self.class.clear_active_stubs_if_empty
    end

    def active_stubs
      self.class.active_stubs
    end

    def stub_key
      self.class.stub_key(klass_key, @method_name)
    end

    def klass_key
      @klass_key ||= Digest::SHA256.hexdigest(@klass.object_id.to_s)
    end

    def stub_defined?
      self.class.current_stubs&.key?(stub_key)
    end
  end
end
