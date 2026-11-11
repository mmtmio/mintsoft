# frozen_string_literal: true

module Mintsoft
  module Resources
    class Orders < BaseResource
      def search(order_number)
        validate_order_number!(order_number)
        response = get_request("/api/Order/Search", params: {"OrderNumber" => order_number})

        if response.status == 404
          [] # Return empty array for not found orders
        else
          response_data = handle_response(response)
          parse_orders(response_data)
        end
      end

      def retrieve(id)
        validate_id!(id)
        response = get_request("/api/Order/#{id}")

        if response.status == 404
          nil # Return nil for not found orders
        else
          response_data = handle_response(response)
          parse_order(response_data)
        end
      end

      def create(attributes)
        validate_attributes!(attributes)

        payload = format_payload(attributes)
        response = put_request("/api/Order", body: payload)
        response_data = handle_response(response)

        parse_orders(response_data)
      end

      private

      def validate_attributes!(attributes)
        raise ValidationError, "Order attributes required" unless attributes.is_a?(Hash) && !attributes.empty?
      end

      def format_payload(value)
        case value
        when Hash
          value.to_h { |key, val| [key.to_s.camelcase, format_payload(val)] }
        when Array
          value.map { |item| format_payload(item) }
        else
          value
        end
      end

      def validate_order_number!(order_number)
        raise ValidationError, "Order number required" if order_number.nil? || order_number.empty?
      end

      def validate_id!(id)
        raise ValidationError, "ID must be present" if id.nil? || (id.respond_to?(:empty?) && id.empty?)
      end

      def parse_orders(data)
        return [] unless data.is_a?(Array)

        data.map { |order_data| Objects::Order.new(order_data) }
      end

      def parse_order(data)
        return nil unless data.is_a?(Hash)

        Objects::Order.new(data)
      end
    end
  end
end
