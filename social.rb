#!/usr/local/bin/ruby -w
require 'rubygems'
require 'sinatra'
require 'oauth2'
require 'json'
require 'net/http'
require 'yaml'
require 'rest_client'
require 'rest-graph'
require 'time'
require 'nokogiri'
require 'partials'
require 'models/InfoPane'
require 'models/NewsList'
require 'models/Photostream'

config = YAML.load_file('config/config.yml')
API_KEY = config['facebook']['api_key']
API_SECRET = config['facebook']['secret_key']
APP_ID = config['facebook']['app_id']
NEWS_SOURCES = config['facebook']['sources'].sort
DEFAULT_SOURCE = config['facebook']['sources']['miscellaneous']['npr']

configure do
	#set :bind, '157.57.202.163'
	set :sessions, true
end


helpers Sinatra::Partials

# Runs before every request is processed
before do
	@user = session[:user]
	@client = OAuth2::Client.new(API_KEY, API_SECRET, :site => 'https://graph.facebook.com')
end

# This must be called to authorize the application
get '/auth/facebook' do
	# The permissions listed in the scope come from here:
	# http://developers.facebook.com/docs/authentication/permissions
	redirect @client.web_server.authorize_url(
		:redirect_uri => redirect_uri,
		:scope => 'read_stream,user_location,offline_access,friends_photos')
end

# This gets called by Facebook in response to a request to authorize the application
# So to be called, the user must have just logged into Facebook and given the
# application authorization of some kind
get '/auth/facebook/callback' do
	@access_token = @client.web_server.get_access_token(
		params[:code], :redirect_uri => redirect_uri
	)

	session[:access_token] = @access_token.token
	redirect '/fb/me'
	#redirect '/fb/friends'
end

# Home page
get '/' do
	erb :index
end

# Home page for an authenticated FB user (go through authorization first)
get '/fb/me' do
	if session[:access_token].nil?
		redirect '/auth/facebook'
	end

	@token = session[:access_token]
	rg = RestGraph.new(:access_token => @token)
	@user = rg.get('me')
	@info_pane = Facebook::InfoPane.new(@user, @token)
	@info_pane.find_popular
	erb :fb_me
end

get '/fb/friends' do
	if session[:access_token].nil?
		redirect '/auth/facebook'
	end
	@token = session[:access_token]
	@photostream = Facebook::Photostream.new(@token)
	erb :fb_friends
end

get '/fb/news' do
	@fb_id = DEFAULT_SOURCE.to_s
	if !params[:source].nil?
		@fb_id = params[:source].to_s
	end

	nl = Facebook::NewsList.new
	nl.latest_updates(@fb_id)
	@news = nl
	@sources = NEWS_SOURCES
	#erb :public_news
	erb :fql
end

get '/fb/sources' do
  @sources = NEWS_SOURCES
	erb :news_sources
end

def redirect_uri
	uri = URI.parse(request.url)
	uri.path = '/auth/facebook/callback'
	uri.query = nil
	uri.to_s
end

def fb_news_for(id)
    url = "http://graph.facebook.com/#{URI.encode(id)}/feed"
    json = Net::HTTP.get_response(URI.parse(url)).body
    data = JSON.parse(json)
end

def page_info_for(id)
    url = "http://graph.facebook.com/#{URI.encode(id)}"
    json = Net::HTTP.get_response(URI.parse(url)).body
    info = JSON.parse(json)
end
