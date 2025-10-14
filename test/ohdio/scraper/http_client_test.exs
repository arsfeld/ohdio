defmodule Ohdio.Scraper.HttpClientTest do
  use ExUnit.Case, async: true

  alias Ohdio.Scraper.HttpClient

  # Note: These are integration tests that make real HTTP requests
  # In a production environment, you might want to use mocks or recorded responses

  describe "get/2" do
    @tag :integration
    test "successfully fetches a valid URL" do
      # Using httpbin.org for testing - it's a reliable test service
      url = "https://httpbin.org/html"
      assert {:ok, body} = HttpClient.get(url)
      assert is_binary(body)
      assert String.contains?(body, "html")
    end

    @tag :integration
    test "returns error for 404 not found" do
      url = "https://httpbin.org/status/404"
      assert {:error, :not_found} = HttpClient.get(url)
    end

    @tag :integration
    test "returns error for 500 server error" do
      url = "https://httpbin.org/status/500"
      assert {:error, :server_error} = HttpClient.get(url, max_retries: 1)
    end

    @tag :integration
    test "respects custom headers" do
      url = "https://httpbin.org/headers"
      custom_header = "TestAgent/1.0"

      assert {:ok, body} =
               HttpClient.get(url, headers: %{"user-agent" => custom_header})

      assert String.contains?(body, custom_header)
    end

    @tag :integration
    test "handles timeout errors" do
      # httpbin.org/delay/{seconds} delays response
      url = "https://httpbin.org/delay/10"
      assert {:error, :timeout} = HttpClient.get(url, timeout: 100, max_retries: 0)
    end
  end

  describe "post/2" do
    @tag :integration
    test "successfully posts JSON data" do
      url = "https://httpbin.org/post"
      data = %{"key" => "value", "number" => 42}

      assert {:ok, body} = HttpClient.post(url, json: data)
      assert is_binary(body)
      assert String.contains?(body, "key")
      assert String.contains?(body, "value")
    end

    @tag :integration
    test "returns error for 404 not found" do
      url = "https://httpbin.org/status/404"
      assert {:error, :not_found} = HttpClient.post(url, json: %{})
    end

    @tag :integration
    test "handles params correctly" do
      url = "https://httpbin.org/post"
      params = %{"param1" => "value1", "param2" => "value2"}

      assert {:ok, body} = HttpClient.post(url, params: params)
      assert String.contains?(body, "param1")
      assert String.contains?(body, "value1")
    end
  end

  describe "retry logic" do
    @tag :integration
    test "retries on server errors with exponential backoff" do
      # httpbin /status/500 will consistently return 500
      # This test verifies retry logic is attempted (though it will ultimately fail)
      url = "https://httpbin.org/status/500"

      # Set max_retries to 2 and base_delay to 100ms
      start_time = System.monotonic_time(:millisecond)
      assert {:error, :server_error} = HttpClient.get(url, max_retries: 2, base_delay: 100)
      end_time = System.monotonic_time(:millisecond)

      # With exponential backoff: 100ms + 200ms = 300ms minimum
      # Adding some buffer for request time
      duration = end_time - start_time
      assert duration >= 200, "Expected retry delays to be applied, got #{duration}ms"
    end
  end
end
