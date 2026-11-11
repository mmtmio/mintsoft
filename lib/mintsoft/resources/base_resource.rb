# frozen_string_literal: true

module Mintsoft
  module Resources
    class BaseResource
      def initialize(client)
        @client = client
      end

      protected

      def get_request(url, params: {})
        @client.connection.get(url) do |req|
          req.params.merge!(params) unless params.empty?
        end
      end

      def post_request(url, body: {})
        @client.connection.post(url) do |req|
          req.body = body unless body.empty?
        end
      end

      def put_request(url, body: {})
        @client.connection.put(url) do |req|
          req.body = body unless body.empty?
        end
      end

      def handle_response(response)
        case response.status
        when 200..299
          response.body
        else
          handle_error(response)
        end
      end

      def handle_error(response)
        error_message = extract_error_message(response.body)

        error_class = case response.status
        when 400 then ValidationError
        when 401 then AuthenticationError
        when 403 then ForbiddenError
        else APIError
        end

        message = build_error_message(response.status, error_message)
        raise error_class.new(message, response: response, status_code: response.status)
      end

      def build_error_message(status, error_message)
        case status
        when 400
          "Invalid request data: #{error_message}"
        when 401
          "Invalid or expired token"
        when 403
          "Insufficient permissions"
        else
          "API error: #{status} - #{error_message}"
        end
      end

      private

      def extract_error_message(body)
        case body
        when String
          body
        when Hash
          body["error"] || body["message"] || body.to_s
        else
          "Unknown error"
        end
      end
    end
  end
end
