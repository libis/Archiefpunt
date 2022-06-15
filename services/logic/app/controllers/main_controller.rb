require 'app/helpers/main_helper'

class MainController < Sinatra::Base
  helpers Sinatra::MainHelper

  configure do
    set :method_override, true # make a PUT, DELETE possible with the _method parameter
    set :show_exceptions, false
    set :raise_errors, false
    set :root, File.absolute_path("#{File.dirname(__FILE__)}/../../")
    set :views, (proc { "#{root}/app/views" })
    set :logging, true
    set :static, true
    set :public_folder, "#{root}/public"
    set :solis, Solis::Graph.new(Solis::Shape::Reader::File.read(Solis::ConfigFile[:shape]),
                                 Solis::ConfigFile[:solis])
  end

  get '/' do
    content_type :json
    all_logic_url.to_json
  end

  get '/ping' do
    content_type :json
    {
      "api": true
    }.to_json
  end

  get '/*' do
    content_type :json
    call_logic
  end

  not_found do
    content_type :json
    message = body
    logger.error(message)
    message.to_json
  end

  error do
    content_type :json
    message = { status: 500, body: "error:  #{env['sinatra.error'].to_s}" }
    logger.error(message)
    message.to_json
  end
end