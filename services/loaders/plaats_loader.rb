$LOAD_PATH << '.' << 'lib'
require 'http'
require 'solis'
require 'lib/elastic'

require 'json'

$SERVICE_ROLE = :search
def logic_config
  Solis::ConfigFile[:services][:data_logic]
end

def elastic_config
  @elastic_config ||= Solis::ConfigFile[:services][$SERVICE_ROLE][:elastic]
end

SOLIS_CONF = Solis::ConfigFile[:services][:data][:solis]
SOLIS = Solis::Graph.new(Solis::Shape::Reader::File.read(SOLIS_CONF[:shape]), SOLIS_CONF)

elastic = Elastic.new(elastic_config[:index],
                      elastic_config[:mapping],
                      elastic_config[:host])


#elastic.index.delete if elastic.index.exist?
#elastic.index.create unless elastic.index.exist?

response = HTTP.get("#{logic_config[:host]}/#{logic_config[:base_path]}/plaats")
data = {}
if response.status == 200
  data = JSON.parse(response.body.to_s)
end

data.each do |d|
  elastic.index.insert( {"plaats": d}, 'id', true)
end