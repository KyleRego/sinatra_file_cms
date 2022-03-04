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

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when '.md'
    headers["Content-Type"] = "text/html"
    render_markdown(content)
  when '.txt'
    headers["Content-Type"] = "text/plain"
    content
  end
end

root = File.expand_path("..", __FILE__)

get "/" do
  data_path = root + "/data"
  @filenames = Dir.entries(data_path).select { |f| f != '.' && f != '..' }
  erb :index, layout: :layout
end

get "/:filename" do
  filename = params[:filename]
  file_path = root + "/data/#{filename}"

  if File.file?(file_path)
    load_file_content(file_path)
  else
    session[:error] = "#{filename} does not exist."
    redirect "/"
  end
end