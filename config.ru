require 'rubygems'
require 'sinatra'
require 'social'

root_dir = File.dirname(__FILE__)
set :public,   File.expand_path(File.dirname(__FILE__) + '/public') #Include your public folder
set :views,    File.expand_path(File.dirname(__FILE__) + '/views')  #Include the views
set :config,    File.expand_path(File.dirname(__FILE__) + '/config')  #Include the config
set :environment, :development
set :root,        root_dir
set :app_file,    File.join(root_dir, 'social.rb')
disable :run

run Sinatra::Application
