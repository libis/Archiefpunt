# frozen_string_literal: true
require 'http'
require_relative 'generic_controller'

class MainController < GenericController
  get '/' do
    content_type :json
    endpoints(Solis::ConfigFile[:services][$SERVICE_ROLE][:base_path]).to_json
  rescue StandardError => e
    halt 500, api_error('500', request.url, 'Unknown Error', e.message, e)
  end

  get '/_vandal/?' do
    #File.read('public/vandal/index.html')
    redirect to('/_vandal/index.html')
  rescue StandardError => e
    halt 500, api_error('500', request.url, 'Unknown Error', e.message, e)
  end

  get '/_doc/?' do
    redirect to('/_doc/index.html')
  rescue StandardError => e
    halt 500, api_error('500', request.url, 'Unknown Error', e.message, e)
  end

  get '/_yas/?' do
    # erb :'yas/index.html', locals: { sparql_endpoint: '/_sparql' }
    redirect to('/_yas/index.html')
  rescue StandardError => e
    halt 500, api_error('500', request.url, 'Unknown Error', e.message, e)
  end

  get '/_sparql/?' do
    content_type :json
    halt 501, api_error('501', request.url, 'SparQL error', 'Only POST queries are supported')
  end

  post '/_sparql' do
    content_type env['HTTP_ACCEPT'] || 'text/turtle'
    result = ''
    data = request.body.read

    halt 501, api_error('501', request.url, 'SparQL error', 'INSERT, UPDATE, DELETE not allowed') unless data.match(/clear|drop|insert|update|delete/i).nil?
    data = URI.decode_www_form(data).to_h

    url = "#{Solis::ConfigFile[:solis][:sparql_endpoint]}"

    response = HTTP.post(url, form: data, headers: {'Accept' => env['HTTP_ACCEPT'] || 'text/turtle'})
    if response.status == 200
      result = response.body.to_s
    elsif response.status == 500
      halt 500, api_error('500', request.url, 'SparQL error', response.body.to_s)
    elsif response.status == 400
      halt 400, api_error('400', request.url, 'SparQL error', response.body.to_s)
    else
      halt response.status, api_error(response.status.to_s, request.url, 'SparQL error', response.body.to_s)
    end

    result
  rescue HTTP::Error => e
    halt 500, api_error('500', request.url, 'SparQL error', e.message, e)
  rescue StandardError => e
    halt 500, api_error('500', request.url, 'SparQL error', e.message, e)
  end

  get '/schema.json' do
    content_type :json
    Graphiti::Schema.generate.to_json
  rescue StandardError => e
    halt 500, api_error('500', request.url, 'Unknown Error', e.message, e)
  end

  get '/:entity' do
    content_type :json
    #recursive_compact(JSON.parse(for_resource.all(params.merge({stats: {total: :count}})).to_jsonapi)).to_json
    #
    context = load_context #OpenStruct.new(query_user: params.key?(:gebruiker) ? params[:gebruiker] : 'unknown')
    Graphiti::with_context(context) do
      for_resource.all(params.merge({ stats: { total: :count } })).to_jsonapi
    end
  rescue Solis::Error::InvalidAttributeError => e
    content_type :json
    halt 500, api_error(response.status, request.url, 'Invalid attribute', e.message, e)
  rescue Graphiti::Errors::RecordNotFound
    content_type :json
    halt 404, api_error('404', request.url, 'Not found', "'#{id}' niet gevonden in  #{params[:entity]}")
  rescue StandardError => e
    puts e.backtrace.join("\n")
    content_type :json
    halt 500, api_error(response.status, request.url, "Error in '#{e.name}'", e.cause, e)
  end

  post '/:entity' do
    content_type :json
    result = nil
    data = JSON.parse(request.body.read)
    data = data['attributes'] if data.include?('attributes')

    context = OpenStruct.new(query_user: params.key?(:gebruiker) ? params[:gebruiker] : 'unknown')
    Graphiti::with_context(context) do
      model = for_model.new(data)
      model.save(params.key?(:validate_dependencies) ? !params[:validate_dependencies].eql?('false') : true)
      result = for_resource.find({ id: model.id })
      return result.to_jsonapi
    end
    result.to_jsonapi
  rescue Graphiti::Errors::RecordNotFound
    content_type :json
    halt 404, api_error('404', request.url, 'Not found', "'#{id}' niet gevonden in  #{params[:entity]}")
  rescue Solis::Error::InvalidAttributeError => e
    content_type :json
    halt 500, api_error(response.status, request.url, 'Invalid attribute', e.message, e)
  rescue StandardError => e
    content_type :json
    halt 500, api_error(response.status, request.url, 'Unknown Error', e.cause, e)
  end

  get '/:entity/model' do
    content_type :json
    if params.key?(:template) && params[:template]
      for_model.model_template.to_json
    else
      for_model.model.to_json
    end
  rescue Solis::Error::InvalidAttributeError => e
    content_type :json
    halt 500, api_error(response.status, request.url, 'Invalid attribute', e.message, e)
  rescue StandardError => e
    content_type :json
    halt 500, api_error(response.status, request.url, 'Unknown Error', e.cause, e)
  end

  put '/:entity/:id' do
    content_type :json
    result = {}
    context = load_context
    Graphiti::with_context(context) do
      resource = for_resource.find({ id: params['id'] })
      raise Graphiti::Errors::RecordNotFound unless resource

      data = JSON.parse(request.body.read)
      data = data['attributes'] if data.include?('attributes')
      data['id'] = params[:id] unless data.include?('id')

      resource = for_model.new.update(data,
                                      params.key?(:validate_dependencies) ? !params[:validate_dependencies].eql?('false') : true)

      result = for_resource.find({ id: resource.id })
      return result.to_jsonapi
    end
    result.to_jsonapi
  rescue Solis::Error::InvalidAttributeError => e
    content_type :json
    halt 500, api_error(response.status, request.url, 'Invalid attribute', e.message, e)
  rescue Graphiti::Errors::RecordNotFound
    content_type :json
    halt 404, api_error('404', request.url, 'Not found', "'#{id}' niet gevonden in  #{params[:entity]}")
  rescue StandardError => e
    content_type :json
    puts e.backtrace.join("\n")
    halt 500, api_error(response.status, request.url, 'Unknown Error', e.cause, e)
  end

  delete '/:entity/:id' do
    content_type :json
    context = OpenStruct.new(query_user: params.key?(:gebruiker) ? params[:gebruiker] : 'unknown')
    Graphiti::with_context(context) do

      resource = for_resource.find({ id: params['id'] })
      raise Graphiti::Errors::RecordNotFound unless resource

      resource.data.destroy
      return resource.to_jsonapi
    end
    resource.to_jsonapi
  rescue Solis::Error::InvalidAttributeError => e
    content_type :json
    halt 500, api_error(response.status, request.url, 'Invalid attribute', e.message, e)
  rescue Graphiti::Errors::RecordNotFound
    content_type :json
    halt 404, api_error('404', request.url, 'Not found', "'#{id}' niet gevonden in  #{params[:entity]}")
  rescue StandardError => e
    content_type :json
    puts e.backtrace.join("\n")
    halt 500, api_error(response.status, request.url, 'Unknown Error', e.cause, e)
  end

  get '/:entity/:id' do
    result = {}
    content_type :json
    id = params.delete(:id)
    context = load_context
    Graphiti::with_context(context) do
      data = { id: id }
      data = data.merge(params)
      result = for_resource.find(data)
      return result.to_jsonapi
    end
    result.to_jsonapi
  rescue Solis::Error::InvalidAttributeError => e
    content_type :json
    halt 500, api_error(response.status, request.url, 'Invalid attribute', e.message, e)
  rescue Graphiti::Errors::RecordNotFound
    content_type :json
    halt 404, api_error('404', request.url, 'Not found', "'#{id}' niet gevonden in  #{params[:entity]}")
  rescue StandardError => e
    content_type :json
    halt 500, api_error(response.status, request.url, 'Unknown Error', e.message, e)
  end
end
