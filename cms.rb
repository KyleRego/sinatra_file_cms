require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'

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

get "/" do
  @filenames = Dir.entries(data_path).select { |f| f != '.' && f != '..' }
  erb :index, layout: :layout
end

get "/new" do
  erb :new, layout: :layout
end

post "/new" do
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
  filename = params[:filename]
  file_path = File.join(data_path, filename)

  if File.file?(file_path)
    File.delete(file_path)
    session[:success] = "#{filename} was deleted."
  end
  redirect "/"
end

get "/:filename/edit" do
  @filename = params[:filename]
  @contents = File.read(File.join(data_path, @filename))
  erb :edit, layout: :layout
end

post "/:filename/edit" do
  new_contents = params[:new_contents]
  filename = params[:filename]
  file_path = File.join(data_path, filename)
  file = File.open(file_path, "w") { |f| f.write new_contents }
  session[:success] = "#{filename} has been updated."
  redirect "/"
end
