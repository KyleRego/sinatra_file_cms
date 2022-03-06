ENV["RACK_ENV"] = "test"

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'

require_relative "../cms"

class AppTest < MiniTest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), 'w') do |file|
      file.write content
    end
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  def session
    last_request.env["rack.session"]
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  # tests about index view

  def test_index_not_logged_in
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Sign in"
  end

  def test_index_logged_in
    create_document 'about.md'
    create_document 'history.txt'
    get "/", {}, admin_session
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "history.txt"
    assert_includes last_response.body, "Signed in as admin"
  end

  # tests about signing in

  def test_signin
    get "/users/signin"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Username:"
    assert_includes last_response.body, "Password:"
  end

  def test_unsuccessful_signin
    post "/users/new", username: "kyle", password: "password"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "kyle"
    assert_includes last_response.body, "Invalid credentials."
  end
  
  def test_successful_signin_as_admin
    post "/users/new", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:success]
    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Signed in as admin"
    assert_includes last_response.body, "Sign out"
  end

  def test_successful_signin_as_user
    
  end

  # tests about accessing files

  def test_viewing_a_txt_file_while_logged_in
    get "/", {}, admin_session
    create_document "history.txt", "the content of history.txt is this"
    get "/history.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "history.txt"
  end

  def test_trying_to_access_a_nonexistent_file_while_logged_in
    get "/", {}, admin_session
    get "/a.txt"
    assert_equal 302, last_response.status
    assert_equal "", last_response.body
    assert_equal "a.txt does not exist.", session[:error]
    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "a.txt does not exist"
    get "/"
    refute_includes last_response.body, "a.txt does not exist"
  end

  def test_viewing_a_markdown_file_while_logged_in
    get "/", {}, admin_session
    create_document "about.md", "# test markdown file"
    get "/about.md"
    assert_equal 200, last_response.status
    assert_equal "text/html", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>test markdown file</h1>"
  end

  # tests about editing a file

  def test_editing_file_while_logged_in
    create_document "history.txt"
    get "/", {}, admin_session
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

  def test_attempting_to_access_editing_file_view_while_not_logged_in
    create_document "history.txt"
    get "/history.txt/edit"
    assert_equal "You must be signed in to do that.", session[:error]
    assert_equal 302, last_response.status
  end

  def test_attempting_edit_file_by_post_while_not_logged_in
    create_document "history.txt"
    post "/history.txt/edit", new_contents: "new history.txt contents"
    assert_equal "You must be signed in to do that.", session[:error]
    assert_equal 302, last_response.status
  end

  # tests about adding a file

  def test_adding_file_while_logged_in
    get "/", {}, admin_session
    get "/new"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Add a new document:"

    post "/new", new_document: "hello_world.txt"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "hello_world.txt"
  end

  def test_adding_file_with_no_name_error_while_logged_in
    get "/", {}, admin_session
    post "/new", new_document: ""

    get last_response["Location"]
    assert_includes last_response.body, "A name is required."

    get "/new"
    refute_includes last_response.body, "A name is required."
  end

  def test_visiting_add_file_view_while_not_logged_in
    get "/new"
    assert_equal "You must be signed in to do that.", session[:error]
    assert_equal 302, last_response.status
  end

  def test_attempting_to_add_file_by_post
    post "/new", new_document: "hello_world.txt"
    assert_equal "You must be signed in to do that.", session[:error]
    assert_equal 302, last_response.status
  end

  # tests about deleting a file

  def test_deleting_a_file_while_logged_in
    create_document "hello_world.txt"
    get "/", {}, admin_session
    assert_includes last_response.body, "hello_world.txt"
    post "/hello_world.txt/delete"
    assert_equal 302, last_response.status
    get last_response["Location"]
    assert_includes last_response.body, "hello_world.txt was deleted."
    get "/"
    refute_includes last_response.body, "hello_world.txt"
  end

  def test_trying_to_delete_a_file_while_not_logged_in
    create_document "hello_world.txt"
    post "/hello_world.txt/delete"
    assert_equal "You must be signed in to do that.", session[:error]
    assert_equal 302, last_response.status
  end
end
