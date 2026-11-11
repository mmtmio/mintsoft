# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mintsoft::Resources::Orders do
  let(:token) { "test_token" }
  let(:client) { Mintsoft::Client.new(token: token) }
  let(:orders_resource) { described_class.new(client) }

  describe "#search" do
    context "with valid order number" do
      it "returns array of Order objects" do
        order_data = [
          {"Id" => 1, "OrderNumber" => "ORD-123", "CustomerID" => 456},
          {"Id" => 2, "OrderNumber" => "ORD-124", "CustomerID" => 789}
        ]

        stub_request(:get, "https://api.mintsoft.co.uk/api/Order/Search")
          .with(query: {"OrderNumber" => "ORD-123"})
          .to_return(
            status: 200,
            body: order_data.to_json,
            headers: {"Content-Type" => "application/json"}
          )

        result = orders_resource.search("ORD-123")

        expect(result).to be_an(Array)
        expect(result.size).to eq(2)
        expect(result.first).to be_a(Mintsoft::Objects::Order)
        expect(result.first.id).to eq(1)
        expect(result.first.order_number).to eq("ORD-123")
      end
    end

    context "when order not found" do
      it "returns empty array for 404 response" do
        stub_request(:get, "https://api.mintsoft.co.uk/api/Order/Search")
          .with(query: {"OrderNumber" => "NOTFOUND"})
          .to_return(status: 404)

        result = orders_resource.search("NOTFOUND")
        expect(result).to eq([])
      end
    end

    context "with invalid order number" do
      it "raises ValidationError for empty order number" do
        expect {
          orders_resource.search("")
        }.to raise_error(Mintsoft::ValidationError, "Order number required")
      end

      it "raises ValidationError for nil order number" do
        expect {
          orders_resource.search(nil)
        }.to raise_error(Mintsoft::ValidationError, "Order number required")
      end
    end

    context "with authentication error" do
      it "raises AuthenticationError for 401 response" do
        stub_request(:get, "https://api.mintsoft.co.uk/api/Order/Search")
          .with(query: {"OrderNumber" => "ORD-123"},
            headers: {"ms-apikey" => "test_token"})
          .to_return(status: 401)

        expect {
          orders_resource.search("ORD-123")
        }.to raise_error(Mintsoft::AuthenticationError, "Invalid or expired token")
      end
    end
  end

  describe "#create" do
    let(:order_attributes) do
      {
        order_number: "ORD-125",
        external_order_reference: "REF-1",
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
        order_value: 12.5,
        order_items: [
          {"SKU" => "S-4001", :quantity => 1, :unit_price => 10.0, :unit_price_vat => 2.5}
        ]
      }
    end

    context "with valid attributes" do
      it "returns array of Order objects with original response data" do
        response_data = [
          {
            "OrderId" => 789,
            "DropShipOrderId" => 0,
            "OrderNumber" => "ORD-125",
            "Success" => true,
            "OrderStatusId" => 1,
            "OrderStatus" => "NEW",
            "Message" => nil,
            "OrderItems" => [{"SKU" => "S-4001", "Quantity" => 1}]
          }
        ]

        stub_request(:put, "https://api.mintsoft.co.uk/api/Order")
          .with(
            headers: {"ms-apikey" => "test_token"},
            body: {
              "OrderNumber" => "ORD-125",
              "ExternalOrderReference" => "REF-1",
              "FirstName" => "Jane",
              "LastName" => "Doe",
              "Address1" => "22 Test Lane",
              "Town" => "Testsend",
              "PostCode" => "G13 1EE",
              "Country" => "UK",
              "CourierService" => "Royal Mail Tracked 48",
              "ChannelId" => 87,
              "WarehouseId" => 24,
              "Currency" => "GBP",
              "OrderValue" => 12.5,
              "OrderItems" => [
                {"SKU" => "S-4001", "Quantity" => 1, "UnitPrice" => 10.0, "UnitPriceVat" => 2.5}
              ]
            }.to_json
          )
          .to_return(
            status: 200,
            body: response_data.to_json,
            headers: {"Content-Type" => "application/json"}
          )

        result = orders_resource.create(order_attributes)

        expect(result).to be_an(Array)
        expect(result.size).to eq(1)
        expect(result.first).to be_a(Mintsoft::Objects::Order)
        expect(result.first.order_id).to eq(789)
        expect(result.first.order_number).to eq("ORD-125")
        expect(result.first.success).to be true
        expect(result.first.order_items.first.sku).to eq("S-4001")

        # Test original response is preserved with original casing
        expect(result.first.original_response["OrderId"]).to eq(789)
        expect(result.first.original_response["OrderStatus"]).to eq("NEW")
      end

      it "sends keys already in Mintsoft casing unchanged" do
        stub_request(:put, "https://api.mintsoft.co.uk/api/Order")
          .with(body: {"OrderNumber" => "ORD-126", "VATNumber" => "GB123", "OrderItems" => [{"SKU" => "S-4001"}]}.to_json)
          .to_return(status: 200, body: [].to_json, headers: {"Content-Type" => "application/json"})

        result = orders_resource.create({"OrderNumber" => "ORD-126", "VATNumber" => "GB123", "OrderItems" => [{"SKU" => "S-4001"}]})

        expect(result).to eq([])
      end
    end

    context "when Mintsoft does not create the order" do
      it "returns the result without raising" do
        response_data = [{"OrderId" => 0, "OrderNumber" => "ORD-125", "Success" => false, "Message" => "Duplicate order number"}]

        stub_request(:put, "https://api.mintsoft.co.uk/api/Order")
          .to_return(status: 200, body: response_data.to_json, headers: {"Content-Type" => "application/json"})

        result = orders_resource.create(order_attributes)

        expect(result.first.success).to be false
        expect(result.first.message).to eq("Duplicate order number")
      end
    end

    context "with invalid attributes" do
      it "raises ValidationError for nil attributes" do
        expect {
          orders_resource.create(nil)
        }.to raise_error(Mintsoft::ValidationError, "Order attributes required")
      end

      it "raises ValidationError for empty attributes" do
        expect {
          orders_resource.create({})
        }.to raise_error(Mintsoft::ValidationError, "Order attributes required")
      end
    end

    context "with bad request" do
      it "raises ValidationError for 400 response" do
        stub_request(:put, "https://api.mintsoft.co.uk/api/Order")
          .to_return(status: 400, body: {"message" => "Country is required"}.to_json, headers: {"Content-Type" => "application/json"})

        expect {
          orders_resource.create(order_attributes)
        }.to raise_error(Mintsoft::ValidationError, "Invalid request data: Country is required")
      end
    end

    context "with authentication error" do
      it "raises AuthenticationError for 401 response" do
        stub_request(:put, "https://api.mintsoft.co.uk/api/Order")
          .to_return(status: 401, body: "Unauthorized")

        expect {
          orders_resource.create(order_attributes)
        }.to raise_error(Mintsoft::AuthenticationError, "Invalid or expired token")
      end
    end

    context "with other API errors" do
      it "raises APIError for 500 response" do
        stub_request(:put, "https://api.mintsoft.co.uk/api/Order")
          .to_return(status: 500, body: "Internal Server Error")

        expect {
          orders_resource.create(order_attributes)
        }.to raise_error(Mintsoft::APIError, "API error: 500 - Internal Server Error")
      end
    end
  end

  describe "#retrieve" do
    context "with valid ID" do
      it "returns Order object" do
        order_data = {"Id" => 123, "OrderNumber" => "ORD-123", "CustomerID" => 456}

        stub_request(:get, "https://api.mintsoft.co.uk/api/Order/123")
          .to_return(
            status: 200,
            body: order_data.to_json,
            headers: {"Content-Type" => "application/json"}
          )

        result = orders_resource.retrieve(123)

        expect(result).to be_a(Mintsoft::Objects::Order)
        expect(result.id).to eq(123)
        expect(result.order_number).to eq("ORD-123")
        expect(result.customer_id).to eq(456)
      end
    end

    context "when order not found" do
      it "returns nil for 404 response" do
        stub_request(:get, "https://api.mintsoft.co.uk/api/Order/999")
          .to_return(status: 404)

        result = orders_resource.retrieve(999)
        expect(result).to be_nil
      end
    end

    context "with invalid ID" do
      it "raises ValidationError for empty ID" do
        expect {
          orders_resource.retrieve("")
        }.to raise_error(Mintsoft::ValidationError, "ID must be present")
      end

      it "raises ValidationError for nil ID" do
        expect {
          orders_resource.retrieve(nil)
        }.to raise_error(Mintsoft::ValidationError, "ID must be present")
      end
    end

    context "with authentication error" do
      it "raises AuthenticationError for 401 response" do
        stub_request(:get, "https://api.mintsoft.co.uk/api/Order/123")
          .to_return(status: 401)

        expect {
          orders_resource.retrieve(123)
        }.to raise_error(Mintsoft::AuthenticationError, "Invalid or expired token")
      end
    end

    context "with other API errors" do
      it "raises APIError for 500 response" do
        stub_request(:get, "https://api.mintsoft.co.uk/api/Order/123")
          .to_return(status: 500, body: "Internal Server Error")

        expect {
          orders_resource.retrieve(123)
        }.to raise_error(Mintsoft::APIError, /API error: 500/)
      end
    end
  end
end
