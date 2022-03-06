require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when '.md'
    headers["Content-Type"] = "text/html"
    erb render_markdown(content)
  when '.txt'
    headers["Content-Type"] = "text/plain"
    content
  end
end

def user_logged_in?
  session[:username] == 'admin'
end

def require_signed_in_user
  unless user_logged_in?
    session[:error] = "You must be signed in to do that."
    redirect "/"
  end
end

def load_users
  path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test", __FILE__)
  else
    File.expand_path('..', __FILE__)
  end
  YAML.load(File.read("#{path}/users.yml"))
end

get "/" do
  @username = session[:username]
  @filenames = Dir.entries(data_path).select { |f| f != '.' && f != '..' }
  erb :index, layout: :layout
end

get "/users/signin" do
  erb :signin, layout: :layout
end

post "/users/signout" do
  session.delete(:username)
  session[:success] = "You have been signed out."
  redirect "/"
end

post "/users/new" do
  @username = params[:username]
  password = params[:password]
  valid_users = load_users
  if valid_users.any? do |name, pass|
    (name == @username && BCrypt::Password.new(pass) == password )
  end
    session[:username] = @username
    session[:success] = "Welcome!"
    redirect "/"
  else
    session[:error] = "Invalid credentials."
    erb :signin, layout: :layout
  end
end

get "/new" do
  require_signed_in_user
  erb :new, layout: :layout
end

post "/new" do
  require_signed_in_user
  
  new_document_name = params[:new_document]
  if new_document_name != ""
    new_document = File.join(data_path, new_document_name)
    File.open(new_document, 'w')
    session[:success] = "#{new_document_name} was created."
    redirect "/"
  else
    session[:error] = "A name is required."
    redirect "/new"
  end
end

get "/:filename" do
  require_signed_in_user
  
  filename = params[:filename]
  file_path = File.join(data_path, filename)

  if File.file?(file_path)
    load_file_content(file_path)
  else
    session[:error] = "#{filename} does not exist."
    redirect "/"
  end
end

post "/:filename/delete" do
  require_signed_in_user

  filename = params[:filename]
  file_path = File.join(data_path, filename)

  if File.file?(file_path)
    File.delete(file_path)
    session[:success] = "#{filename} was deleted."
  end
  redirect "/"
end

get "/:filename/edit" do
  require_signed_in_user

  @filename = params[:filename]
  @contents = File.read(File.join(data_path, @filename))
  erb :edit, layout: :layout
end

post "/:filename/edit" do
  require_signed_in_user

  new_contents = params[:new_contents]
  filename = params[:filename]
  file_path = File.join(data_path, filename)
  file = File.open(file_path, "w") { |f| f.write new_contents }
  session[:success] = "#{filename} has been updated."
  redirect "/"
end
