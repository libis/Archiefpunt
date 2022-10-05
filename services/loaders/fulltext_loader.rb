$LOAD_PATH << '.' << 'lib'
require 'http'
require 'json'
require 'solis'
require 'lib/elastic'
require 'data_collector'
require 'lib/loader'

include DataCollector::Core
include LoaderHelper

SOLIS_CONF = Solis::ConfigFile[:services][:data][:solis]
SOLIS = Solis::Graph.new(Solis::Shape::Reader::File.read(SOLIS_CONF[:shape]), SOLIS_CONF)

elastic_index_name = "archiefpunt_#{Time.now.to_i}"

elastic = Elastic.new(elastic_index_name,
                      elastic_config[:mapping],
                      elastic_config[:host])

elastic.index.delete if elastic.index.exist?
elastic.index.create unless elastic.index.exist?

load_archieven(elastic)
load_beheerders(elastic)
load_samenstellers(elastic)
load_plaatsen(elastic)


puts "index created as: #{elastic_index_name}"

indexes_in_alias = elastic.alias.index('archiefpunt')
if indexes_in_alias.empty?
  elastic.alias.add('archiefpunt', elastic_index_name)
else
  elastic.alias.replace('archiefpunt', indexes_in_alias.first, elastic_index_name)
  elastic.index.delete( indexes_in_alias.first)
end
