#encoding:UTF-8
require 'json'
require 'sinatra/streaming'
require 'tilt/erb'
require 'http/accept'

require 'app/helpers/main_helper'

class GenericController < Sinatra::Base
  helpers Sinatra::Streaming
  helpers Sinatra::MainHelper

  configure do
    set :method_override, true # make a PUT, DELETE possible with the _method parameter
    set :show_exceptions, false
    set :raise_errors, false
    set :root, File.absolute_path("#{File.dirname(__FILE__)}/../../")
    set :views, Proc.new { "#{root}/app/views" }
    set :logging, true
    set :static, true
    set :config, DataCollector::ConfigFile
  end

  before do
    accept_header = request.env['HTTP_ACCEPT']
    accept_header = params['accept'] if params.include?('accept')
    accept_header = 'application/json' if accept_header.nil?

    media_types = HTTP::Accept::MediaTypes.parse(accept_header).map { |m| m.mime_type.eql?('*/*') ? 'application/json' : m.mime_type } || ['application/json']
    @media_type = media_types.first

    content_type @media_type
  end

  error do
    body =  JSON.parse(env['sinatra.error'].message) rescue {message: env['sinatra.error'].message}
    message_body = body['message']
    http_status = env['sinatra.error'].http_status rescue 500
    message = { status: http_status, body: "error: #{message_body}" }
    status http_status
    logger.error(message)

    case @media_type
    when 'application/json'
      message.to_json
    else
      erb :error, locals: { message: message }, layout: true
    end
  end
end