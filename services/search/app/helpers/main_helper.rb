require 'data_collector'
include DataCollector::Core

puts "Looking for RULES at #{ConfigFile[:services][$SERVICE_ROLE][:rules]}"
raise "No rules found" unless File.exist?(ConfigFile[:services][$SERVICE_ROLE][:rules])
require ConfigFile[:services][$SERVICE_ROLE][:rules]

module Sinatra
  module MainHelper

    def available_indexes
      indexes = Query::Indexes.new(elastic_config[:templates][:mapping])

      indexes_list = {}
      indexes_list = indexes_list.merge(indexes.index_map, indexes.facet_map, indexes.query_mapping).map do |k, v|
        if v.is_a?(Array) && v.length > 0 && v[0].eql?('id')
          { k => '1234' }
        elsif v.is_a?(Array)
          { k => '' }
        elsif (v.is_a?(Hash) && v.keys.first.eql?('{{}}'))
          { k => '' }
        elsif v.is_a?(Hash)
          { k => v.keys.first }
        else
          { k => '' }
        end
      end

      indexes_list
    end

    def normalize_output(data, query)
      out = DataCollector::Output.new
      rules_ng.run(RULES['archiefpunt'], data, out, query)

      out
    end

    def elastic?
      result = HTTP.get("#{elastic_config[:host]}")
      return true
    rescue HTTP::Error => e
      return false
    end

    def elastic_config
      @elastic_config ||= ConfigFile[:services][$SERVICE_ROLE][:elastic]
    end

  end
  helpers MainHelper
end