require 'sinatra/base'
require 'http'
require 'json'
require 'lib/config_file'
require 'app/helpers/main_helper'
require 'lib/elastic/query'

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
  end

  get '/' do
    content_type :json
    halt 500, ERB::Util.html_escape('I need a "query" parameter') unless params.key?('query')
    query = params['query']
    parser = Query::Parser.new(elastic_config[:templates])
    elastic_query = parser.parse_to_elasticsearch(query, params)
    puts "\nORIGINAL_QUERY:\n#{query}"
    puts "ELASTIC_QUERY: \n#{elastic_query.to_json}"

    response = HTTP.post("#{elastic_config[:host]}/#{elastic_config[:index]}/_search", json: elastic_query)

    if response.status == 200
      result = normalize_output(::JSON.parse(response.body.to_s), elastic_query)
    else
      logger.error(response.body.to_s)
      halt 500, ERB::Util.html_escape('Error doing search')
    end
    result.raw.to_json

  end

  get '/help' do
    words = ['water', 'wijn', 'archief', 'koning', 'antw', 'amsab', 'kadoc', 'gebouw', 'open']

    erb :'help.html', locals: {base_path: ConfigFile[:services][$SERVICE_ROLE][:base_path], indexes: available_indexes, words: words}
  end

  post '/' do
    halt 500, ERB::Util.html_escape('I only accept GET requests')
  end

  put '/' do
    halt 500, ERB::Util.html_escape('I only accept GET requests')
  end


  get '/ping' do
    content_type :json
    {
      "api": true,
      "storage": elastic?
    }.to_json
  end

  delete '/' do
    halt 500, ERB::Util.html_escape('I only accept GET requests')
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