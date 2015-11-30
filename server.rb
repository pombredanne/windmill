require 'sinatra'
require 'sinatra/namespace'
require 'sinatra/flash'
require 'json'
require 'omniauth'
require 'omniauth-github'
require 'omniauth-heroku'
require 'omniauth-google-oauth2'
require 'securerandom'
require 'encrypted_cookie'
require 'time_difference'
require 'will_paginate'
require 'will_paginate/active_record'
require_relative 'lib/models/endpoint'
require_relative 'lib/models/configuration'
require_relative 'lib/models/configuration_group'
require_relative 'lib/models/enroller'
require_relative 'lib/models/api_key'
require_relative 'lib/controllers/auth'
require_relative 'lib/controllers/configuration_groups'
require_relative 'lib/controllers/api'
require_relative 'lib/controllers/apikeys'

disable :show_exceptions

NODE_ENROLL_SECRET = ENV['NODE_ENROLL_SECRET'] || "valid_test"

use Rack::Session::EncryptedCookie, expire_after: 86_400, secret: ENV['COOKIE_SECRET'] || SecureRandom.hex(64)
use OmniAuth::Builder do
  provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET'],lict scope: "user:email"
  provider :heroku, ENV['HEROKU_KEY'], ENV['HEROKU_SECRET'], fetch_info: true, scope: "identity"
  provider :google_oauth2, ENV['GOOGLE_ID'], ENV['GOOGLE_SECRET'], name: 'google'
end

if ENV['FULL_URL']
  OmniAuth.config.full_host = ENV['FULL_URL']
end

def logdebug(message)
  if ENV['OSQUERYDEBUG']
    puts "\n" + caller_locations(1,1)[0].label + ": " + message
  end
end

configure do
  if ENV['RACK_ENV'] != 'test'
    if ENV['AUTHORIZEDUSERS']
      set :authorized_users, ENV['AUTHORIZEDUSERS'].split(',')
    else
      begin
        set :authorized_users, File.open('authorized_users.txt').readlines.map {|line| line.strip}
      rescue
        raise ArgumentError, "No ENV or file for authorized users. See: https://github.com/heroku/windmill#authentication-and-logging-in"
      end
    end
  end
end

before do
  pass if request.path_info =~ /^\/auth\//
  pass if request.path_info =~ /^\/api\//
  pass if request.path_info =~ /^\/status/
  redirect to('/auth/login') unless current_user
end

helpers do
  def current_user
    session[:email] || nil
  end

  def bootflash
    remapper = {notice: "alert alert-info", success: "alert alert-success", warning: "alert alert-danger"}
    flash.collect {|k, v| "<div class=\"#{remapper[k]}\">#{v}</div>"}.join
  end

  def difftime(oldtime, newtime)
    oldtime = oldtime || DateTime.now
    diff = TimeDifference.between(oldtime, newtime).in_each_component
    returnstring = "never"
    diff.each do |key, value|
      if value >= 1
        returnstring = "#{value.to_i} #{key.to_s.singularize.pluralize(value.to_i)}"
        break
      end
    end
    returnstring
  end
end

get '/status' do
  "running at #{Time.now}"
end

get '/' do
  redirect '/configuration-groups'
end

namespace '/auth' do
  get '/login' do
    erb :"auth/login", layout: :'login_layout'
  end

  get '/:provider/callback' do
    logdebug JSON.pretty_generate(request.env['omniauth.auth'])
    email = env['omniauth.auth']['info']['email']
    if settings.authorized_users.include? email
      session[:email] = email
      flash[:notice] = "#{email} logged in successfully."
      redirect to('/')
    end
    flash[:warning] = "#{email} logged in successfully but not authorized in authorized_users.txt"
    redirect to('/auth/login')
  end

  get '/failure' do
    flash[:warning] = "Authentication failed."
    redirect to('/auth/login')
    # erb "<h1>Authentication Failed:</h1><h3>message:<h3> <pre>#{params}</pre>"
  end

  get '/:provider/deauthorized' do
    erb "#{params[:provider]} has deauthorized this app."
  end

  get '/logout' do
    email = session[:email]
    session[:email] = nil
    flash[:notice] = "#{email} logged out successfully."
    redirect to('/')
  end
end
