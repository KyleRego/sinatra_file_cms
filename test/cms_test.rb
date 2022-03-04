ENV["RACK_ENV"] = "test"

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'

require_relative "../cms"

def create_document(name, content = "")
  File.open(File.join(data_path, name), 'w') do |file|
    file.write content
  end
end

class AppTest < MiniTest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"

  end

  def test_history
    create_document "history.txt", "the content of history.txt is this"
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
    create_document "about.md", "# test markdown file"
    get "/about.md"
    assert_equal 200, last_response.status
    assert_equal "text/html", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>test markdown file</h1>"
  end

  def test_editing_file
    create_document "history.txt"

    get "/history.txt/edit"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, "Save changes"

    post "/history.txt/edit", new_contents: "history.txt: new contents"
    assert_equal 302, last_response.status
    
    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "history.txt has been updated"

    get "/history.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new contents"
  end

  def test_adding_file
    get "/new"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Add a new document:"

    post "/new", new_document: "hello_world.txt"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "hello_world.txt"
  end

  def test_adding_file_with_no_name_error
    post "/new", new_document: ""

    get last_response["Location"]
    assert_includes last_response.body, "A name is required."

    get "/new"
    refute_includes last_response.body, "A name is required."
  end

  def test_deleting_a_file
    create_document "hello_world.txt"
    get "/"
    assert_includes last_response.body, "hello_world.txt"
    post "/hello_world.txt/delete"
    assert_equal 302, last_response.status
    get last_response["Location"]
    assert_includes last_response.body, "hello_world.txt was deleted."
    get "/"
    refute_includes last_response.body, "hello_world.txt"
  end
end
