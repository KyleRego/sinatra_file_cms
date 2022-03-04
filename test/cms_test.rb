ENV["RACK_ENV"] = "test"

require 'minitest/autorun'
require 'rack/test'

require_relative "../cms"

class AppTest < MiniTest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.txt"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "history.txt"
  end

  def test_history
    get "/history.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "history.txt"
  end

  def test_trying_to_access_a_nonexistent_file
    get "/a.txt"
    assert_equal 302, last_response.status
    assert_equal "", last_response.body
    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "a.txt does not exist"
    get "/"
    refute_includes last_response.body, "a.txt does not exist"
  end

  def test_rendering_markdown_file
    get "/about.md"
    assert_equal 200, last_response.status
    assert_equal "text/html", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>test markdown file</h1>"
  end
end
