require 'hashdiff'
require 'solis/options'
require 'solis/query'
require 'lib/logic_helper'

module Logic
  #module Audit
  JSON.parse(File.read(Solis::ConfigFile[:services][:data][:solis][:inflections])).each do |s, p|
    ActiveSupport::Inflector.inflections.irregular(s, p)
  end

  def list(params = {})
    required_parameters(params, [:id, :entity])

    key = Solis::Query.uuid(params[:id])
    #result = cache[key] if cache.key?(key)

    #if result.nil? || (params.include?(:from_cache) && params[:from_cache].eql?('0'))

      ids = params[:id].split(',').map { |m| "#{Solis::ConfigFile[:solis_data][:graph_name]}#{params[:entity].pluralize.underscore}/#{m}" }
      result = Solis::Query.run_construct_with_file('./config/constructs/audit.sparql', 'soc', 'Audit', ids, 0)
      # cache.store(key, result, expires: 86400)
    #end
    result.to_json
  end

  def version(params = {})
    required_parameters(params, [:id, :version_id, :entity])
    data = JSON.load(list(id: params[:id], entity: params[:entity]))
    data = data.sort { |a, b| a['created_date'] <=> b['created_date'] }

    result = {}

    data.each do |d|
      Hashdiff.patch!(result, d['diff'])
      break if d['id'] =~ /#{params[:version_id]}/
    end
    result.to_json
  rescue StandardError => e
    $SOLIS::LOGGER.error(e.message)
    {}.to_json
  end

  def diff(params = {})
    required_parameters(params, [:id, :original_version_id, :changed_version_id, :entity])

    list = JSON.load(list(id: params[:id], entity: params[:entity]))

    list_ids = list.map { |m| m['id'].split('/').last }
    raise "#{params[:original_version_id]} is not part of #{params[:id]}" unless list_ids.include?(params[:original_version_id])
    raise "#{[:changed_version_id]} is not part of #{params[:id]}" unless list_ids.include?(params[:changed_version_id])

    original_data = JSON.parse(version(id: params[:id], version_id: params[:original_version_id], entity: params[:entity]))
    changed_data = JSON.parse(version(id: params[:id], version_id: params[:changed_version_id], entity: params[:entity]))

    Hashdiff.diff(changed_data, original_data).flatten.to_json
  rescue StandardError => e
    $SOLIS::LOGGER.error(e.message)
    {}.to_json
  end

  def revert(params = {})
    required_parameters(params, [:id, :version_id, :entity])
    list = JSON.load(list(id: params[:id], entity: params[:entity]))

    list_ids = list.map { |m| m['id'].split('/').last }
    raise "#{params[:version_id]} is not part of #{params[:id]}" unless list_ids.include?(params[:version_id])

    version_data = JSON.parse(version(id: params[:id], version_id: params[:version_id], entity: params[:entity]))
    id_url = "#{Solis::ConfigFile[:services][:data][:host]}#{Solis::ConfigFile[:services][:data][:base_path]}#{params[:entity].pluralize.underscore}/#{params[:id]}"

    result = HTTP.put(id_url, json: version_data)

    if result.status==200
      result_from_api = HTTP.get(id_url)
      if result_from_api.status == 200
        return result.body.to_s
      else
        api_error(500, '', 'Error reverting', 'Unable to load from DATA api')
      end
    else
      $SOLIS::LOGGER.error(result.body.to_s)
      api_error(500, '', 'Error reverting', '')
    end
  rescue StandardError => e
    $SOLIS::LOGGER.error(e.message)
    {}.to_json
    api_error(500, '', 'Error reverting', e.message)
  end

  private

  include Logic::Helper

  #end
end