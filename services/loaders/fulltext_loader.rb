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

elastic = Elastic.new('archiefpunt_ftxt', #elastic_config[:index],
                      elastic_config[:mapping],
                      elastic_config[:host])

elastic.index.delete if elastic.index.exist?
elastic.index.create unless elastic.index.exist?

load_archieven(elastic)
load_beheerders(elastic)
load_samenstellers(elastic)
load_plaatsen(elastic)