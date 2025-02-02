$LOAD_PATH << '.' << 'lib'
require 'http'
require 'solis'
require 'lib/elastic'

require 'json'

$SERVICE_ROLE = :codetable

def elastic_config
  @elastic_config ||= Solis::ConfigFile[:services][$SERVICE_ROLE][:elastic]
end

def logic_config
  Solis::ConfigFile[:services][:data_logic]
end

def all_codetables
  response = HTTP.get("#{logic_config[:host]}/#{logic_config[:base_path]}/codetabel?naam=*")
  if response.status == 200
    return JSON.parse(response.body.to_s).map { |m| m['id'] }
  end

  []
end

def load_codetabel(codetabel)
  response = HTTP.get("#{logic_config[:host]}/#{logic_config[:base_path]}/codetabel?naam=#{codetabel}&from_cache=0")
  if response.status == 200
    return JSON.parse(response.body.to_s)
  end

  nil
end

elastic = Elastic.new(elastic_config[:index],
                      elastic_config[:mapping],
                      elastic_config[:host])

elastic.index.delete if elastic.index.exist?
elastic.index.create unless elastic.index.exist?

query_mapping = {
  "any": {
    "*": {
      "match_all": {}
    }
  }
}

all_codetables.each do |codetabel|
  puts codetabel
  data = load_codetabel(codetabel)
  puts "\t #{data.length}"

  # when inserting an array the search result will be an array
  #  elastic.index.insert({ "#{codetabel}": data }, 'id', true)
  insert_data = data.map{|m| { "#{codetabel}": m } }
  elastic.index.insert(insert_data, 'id', true)

  # data.each do |d|
  #   elastic.index.insert({ "#{codetabel}": d }, 'id', true)
  # end
  query_mapping[codetabel] =
    {
      "{{}}": {
        "multi_match": {
          "query": "{{}}",
          "type": "bool_prefix",
          "fields": [
            "#{codetabel}.label",
            "#{codetabel}.label._2gram",
            "#{codetabel}.label._3gram"
          ]
        }
      }
    }
end

puts query_mapping.to_json
