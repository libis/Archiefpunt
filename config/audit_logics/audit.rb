require 'hashdiff'
require 'solis/options'
require 'solis/query'
require 'lib/logic_helper'

module Logic
  #module Audit
    JSON.parse(File.read(Solis::ConfigFile[:services][:data][:solis][:inflections])).each do |s, p|
      ActiveSupport::Inflector.inflections.irregular(s, p)
    end

    def list(params={})
      required_parameters(params, [:id, :entity])

      key = Solis::Query.uuid(params[:id])
      result = cache[key] if cache.key?(key)

      if result.nil? || (params.include?(:from_cache) && params[:from_cache].eql?('0'))

        ids=params[:id].split(',').map{|m| "#{Solis::ConfigFile[:solis_data][:graph_name]}#{params[:entity].pluralize.underscore}/#{m}"}
        result = Solis::Query.run_construct_with_file('./config/constructs/audit.sparql', 'soc', 'Audit', ids, 0)
        cache.store(key, result, expires: 86400)
      end
      result.to_json
    end

    def version(params={})
      required_parameters(params, [:id, :version_id, :entity])
      data = JSON.load(list(id: params[:id], entity: params[:entity])).reverse

      result = {}

      data.each do |d|
        Hashdiff.patch!(result, d['diff'])
        break if d['id'] =~ /#{params[:version_id]}/
      end
      #$SOLIS.shape_as_resource(entity).new(result).to_jsonapi
      #
      result.to_json
    rescue StandardError => e
      $SOLIS::LOGGER.error(e.message)
      {}.to_json
    end


    private
    include Logic::Helper

  #end
end