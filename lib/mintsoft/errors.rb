# frozen_string_literal: true

module Mintsoft
  # Base error class for all Mintsoft-related errors
  class Error < StandardError
    attr_reader :response, :status_code

    def initialize(message = nil, response: nil, status_code: nil)
      super(message)
      @response = response
      @status_code = status_code
    end
  end

  # General API-related errors
  class APIError < Error; end

  # Authentication and authorization errors
  class AuthenticationError < APIError; end

  class ForbiddenError < APIError; end

  # Request validation errors
  class ValidationError < APIError; end
end
