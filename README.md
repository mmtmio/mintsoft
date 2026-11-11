# Mintsoft Ruby Gem

A Ruby wrapper for the Mintsoft API that provides simple token-based authentication and access to essential warehouse management functions.

## Features

- **Token-only authentication**: Manual token management for full control
- **7 Essential API endpoints**: Authentication, Order Search, Create Orders, Return Reasons, Create Returns, Add Return Items, Retrieve Returns
- **OpenStruct-based objects**: Flexible response handling with automatic attribute conversion
- **Faraday HTTP client**: Robust HTTP handling with JSON support
- **Comprehensive error handling**: Clear error messages for common scenarios

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mintsoft'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install mintsoft

## Usage

### Basic Workflow

```ruby
require 'mintsoft'

begin
  # Step 1: Get authentication token
  auth_client = Mintsoft::AuthClient.new
  token = auth_client.auth.authenticate("username", "password")

  # Step 2: Initialize client with token
  client = Mintsoft::Client.new(token: token)

  # Step 3: Search for orders
  orders = client.orders.search("ORD-2024-001")
  if orders.empty?
    puts "No orders found"
    return
  end
  order = orders.first

  # Step 4: Get return reasons
  reasons = client.returns.reasons
  damage_reason = reasons.find { |r| r.name.include?("Damaged") && r.active? }

  # Step 5: Create return
  return_obj = client.returns.create(order.id)

  # Step 6: Add item to return
  result = client.returns.add_item(return_obj.id, {
    product_id: 123,
    quantity: 2,
    reason_id: damage_reason.id,
    unit_value: 25.00,
    notes: "Damaged in shipping"
  })
rescue Mintsoft::AuthClient::AuthenticationError => e
  puts "Authentication failed: #{e.message}"
rescue Mintsoft::AuthenticationError => e
  puts "Token expired: #{e.message}"
rescue Mintsoft::ForbiddenError => e
  puts "Insufficient permissions: #{e.message}"
rescue Mintsoft::ValidationError => e
  puts "Validation error: #{e.message}"
end
```

### API Reference

#### AuthClient

```ruby
# Initialize authentication client
auth_client = Mintsoft::AuthClient.new

# Authenticate and get token
begin
  token = auth_client.auth.authenticate("username", "password")
  puts token  # Direct token string
rescue Mintsoft::AuthClient::AuthenticationError => e
  # Invalid credentials when getting auth token
  puts "Auth failed: #{e.message}"
rescue Mintsoft::ValidationError => e
  # Missing username or password
  puts "Validation error: #{e.message}"
end
```

#### Client

```ruby
# Initialize with token
client = Mintsoft::Client.new(token: "your_token_here")

# Custom base URL (optional)
client = Mintsoft::Client.new(
  token: "your_token_here",
  base_url: "https://custom.api.com"
)
```

#### Orders

```ruby
# Search for orders by order number
orders = client.orders.search("ORD-123")

# Retrieve specific order by ID
order = client.orders.retrieve(order_id)

# Access order properties
order = orders.first
puts order.id              # Direct access to order ID
puts order.order_number    # Direct access to order number
puts order.customer_id     # Direct access to customer ID
puts order.items&.length || 0  # Get number of items if available

# Create an order (PUT /api/Order)
# snake_case keys are converted to Mintsoft's casing, including nested order items.
# Keys already in Mintsoft's casing (e.g. "SKU", "VATNumber") are sent unchanged.
results = client.orders.create({
  order_number: "ORD-125",
  first_name: "Jane",
  last_name: "Doe",
  address1: "22 Test Lane",
  town: "Testsend",
  post_code: "G13 1EE",
  country: "UK",
  courier_service: "Royal Mail Tracked 48",
  channel_id: 87,
  warehouse_id: 24,
  currency: "GBP",
  order_items: [
    {"SKU" => "S-4001", :quantity => 1, :unit_price => 0.0, :unit_price_vat => 0.0}
  ]
})

# Mintsoft returns one result per order created
result = results.first
puts result.order_id   # Mintsoft order ID
puts result.success    # true when the order was created
puts result.message    # Message from Mintsoft, e.g. why creation failed
```

#### Returns

```ruby
# Get return reasons
reasons = client.returns.reasons
active_reasons = reasons.select(&:active?)

# Create return for order
return_obj = client.returns.create(order_id)

# Add item to return
begin
  result = client.returns.add_item(return_obj.id, {
    product_id: 123,
    quantity: 2,
    reason_id: reason_id,
    unit_value: 25.00,
    notes: "Optional notes"
  })
rescue Mintsoft::ForbiddenError => e
  # This typically occurs when credentials don't have permission to add items to returns
  puts "Permission denied: #{e.message}"
end

# Retrieve a specific return by ID
return_obj = client.returns.retrieve(return_id)

# Access return properties
puts return_obj.id          # Direct access to return ID
puts return_obj.order_id    # Direct access to order ID
puts return_obj.status      # Direct access to return status
puts return_obj.customer_name # Direct access to customer name
puts return_obj.total_value # Direct access to total value
# Note: Available properties depend on API response structure
```

### Error Handling

All error classes now include response context and status codes for better debugging:

```ruby
begin
  orders = client.orders.search("ORD-123")
rescue Mintsoft::AuthenticationError => e
  # Token expired or invalid (401) - for API resource calls
  puts "Authentication failed: #{e.message}"
  puts "Status: #{e.status_code}"
rescue Mintsoft::AuthClient::AuthenticationError => e
  # Invalid credentials when getting auth token
  puts "Auth client authentication failed: #{e.message}"
  puts "Status: #{e.status_code}"
rescue Mintsoft::ForbiddenError => e
  # Insufficient permissions (403) - typically when adding items to returns
  puts "Insufficient permissions: #{e.message}"
  puts "Status: #{e.status_code}"
rescue Mintsoft::ValidationError => e
  # Invalid request data (400)
  puts "Validation error: #{e.message}"
  puts "Response: #{e.response.body if e.response}"
rescue Mintsoft::APIError => e
  # General API error
  puts "API error: #{e.message}"
  puts "Status: #{e.status_code}"
end
```

### Not Found Behavior

When resources cannot be found, the gem returns `nil` instead of raising exceptions:

```ruby
# Search for orders - returns empty array if no orders found
orders = client.orders.search("NONEXISTENT-ORDER")
puts orders.empty? # true

# Retrieve specific order - returns nil if not found
order = client.orders.retrieve(99999)
puts order.nil? # true

# Retrieve specific return - returns nil if not found
return_obj = client.returns.retrieve(99999)
puts return_obj.nil? # true
```

### Object Methods

#### Order Objects

```ruby
order = orders.first

# Direct property access
order.id            # Order ID
order.order_number  # Order number
order.customer_id   # Customer ID
order.to_hash       # Convert to hash
order.raw           # Original API response
```

#### Return Objects

```ruby
return_obj = client.returns.create(order_id)

# Direct property access
return_obj.id        # Return ID from API response
# Note: Other properties depend on API response structure
```

### Authentication Token Management

The authentication method returns the token string directly:

```ruby
token = auth_client.auth.authenticate("username", "password")
puts token  # Direct token string

# Token management in workflow
client = Mintsoft::Client.new(token: token)

# For re-authentication when token expires:
token = auth_client.auth.authenticate("username", "password")
client = Mintsoft::Client.new(token: token)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/mintsoft. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/mintsoft/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Mintsoft project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/mintsoft/blob/main/CODE_OF_CONDUCT.md).
