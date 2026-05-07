# frozen_string_literal: true

require "net/http"
require "puma"
require "timeout"

require_relative "../smartest"

module Smartest
  module Rails
    class TestServer
      DEFAULT_HOST = "127.0.0.1"
      DEFAULT_READY_TIMEOUT = 10

      attr_reader :host, :port

      def initialize(app:, host: DEFAULT_HOST, port: nil)
        @app = app
        @host = host
        @requested_port = port || ENV["SMARTEST_RAILS_PORT"]&.to_i || 0
        @server = Puma::Server.new(@app)
        @port = bind_tcp_listener
        @thread = nil
      end

      def start
        @thread ||= @server.run
      end

      def stop
        @server.stop
      end

      def wait_for_ready(timeout: DEFAULT_READY_TIMEOUT)
        Timeout.timeout(timeout) do
          sleep 0.05 until responsive?
        end
      rescue Timeout::Error
        raise "Rails test server did not become ready at #{base_url} within #{timeout} seconds"
      end

      def wait_for_stopped(timeout: DEFAULT_READY_TIMEOUT)
        return unless @thread
        return if @thread.join(timeout)

        raise "Rails test server did not stop within #{timeout} seconds"
      end

      def base_url
        "http://#{host}:#{port}"
      end

      private

      def bind_tcp_listener
        listener = @server.add_tcp_listener(@host, @requested_port)
        bound_port = listener.respond_to?(:addr) ? listener.addr[1] : @requested_port

        return bound_port if bound_port && bound_port.positive?

        raise "Rails test server could not determine bound port"
      end

      def responsive?
        Net::HTTP.start(host, port, open_timeout: 0.2, read_timeout: 0.2) do |http|
          http.head("/")
        end
        true
      rescue EOFError, IOError, Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError
        false
      end
    end
  end
end
