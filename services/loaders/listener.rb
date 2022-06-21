$LOAD_PATH << '.'
require 'listen'
require 'fileutils'
require 'logger'
require 'solis'
require 'http'
require 'lib/elastic'

require '../data/lib/file_queue'

def elastic_config
  @elastic_config ||= Solis::ConfigFile[:services][:search][:elastic]
end

def add_to_elastic(data)
  change = data['change_reason']
  entity = data['entity']['name']
  entity_id = "#{entity.underscore}_id"
  id = data['entity']['id']

  constructs = {'Archief' => '/Users/mehmetc/Dropbox/AllSources/Archiefpunt/config/constructs/expanded_archief2.sparql',
                'Beheerder' => '/Users/mehmetc/Dropbox/AllSources/Archiefpunt/config/constructs/expanded_beheerder.sparql',
                'Samensteller' => '/Users/mehmetc/Dropbox/AllSources/Archiefpunt/config/constructs/expanded_samensteller.sparql'}


  filename = constructs[entity]
  raise "#{entity} not registered for Elastic" if filename.nil? || filename.empty?

  elastic_data = Solis::Query.run_construct_with_file(filename, entity_id, entity, id)
  elastic_data = elastic_data.map{|m| {"#{entity.underscore}": m}}

  case change
  when 'create'
    ELASTIC.index.insert(elastic_data, 'id', true)
  when 'update'
    ELASTIC.index.delete_data(elastic_data, 'id', true)
    ELASTIC.index.insert(elastic_data, 'id', true)
  when 'delete'
    ELASTIC.index.delete_data(elastic_data, 'id', true)
  else
    raise 'Unknown change request'
  end
  true
rescue StandardError => e
  LOGGER.error("#{__method__}: #{entity}(#{id}) -- #{e.message}")
  false
else
  LOGGER.info("#{__method__}: #{entity}(#{id}) -- done")
end

def add_to_audit(data)
  entity = data['entity']['name']
  entity_plural = data['entity']['name_plural']
  id = data['entity']['id']
  graph = data['entity']['graph']

  subject_of_change = "#{graph}/#{entity_plural.underscore}/#{id}".gsub(/\/{2,}/,'/')
  diff = data['diff']
  created_date = Date.parse(data['timestamp'])
  creator_name = data['user'] || 'unknown'
  change_reason = data['change_reason'] || 'unknown'
  other_data = data['other_data'] || {}

  change_set = {
    subject_of_change: subject_of_change,
    diff: diff,
    created_date: created_date,
    creator_name: creator_name,
    change_reason: change_reason,
    other_data: other_data
  }
  audit_url = "#{Solis::ConfigFile[:services][:audit][:host]}#{Solis::ConfigFile[:services][:audit][:base_path]}"

  response = HTTP.post("#{audit_url}/change_sets", :json => change_set )

  if response.code == 200
    result = response.body
    true
  else
    raise response.body.to_s
  end
  false
rescue StandardError => e
  LOGGER.error("#{__method__}: #{entity}(#{id}) -- #{e.message}")
  raise e
  false
else
  LOGGER.info("#{__method__}: #{entity}(#{id}) -- done")
end

#ENV['LISTEN_GEM_DEBUGGING']='info'

puts ENV['LISTEN_GEM_DEBUGGING']

LOGGER = Logger.new(STDOUT)
Listen.logger = LOGGER
# HTTP.default_options = HTTP::Options.new(features: {
#   logging: {
#     logger: LOGGER
#   }
# })

ELASTIC = Elastic.new(elastic_config[:index], elastic_config[:mapping], elastic_config[:host])
SOLIS_CONF = Solis::ConfigFile[:services][:data][:solis]
SOLIS = Solis::Graph.new(Solis::Shape::Reader::File.read(SOLIS_CONF[:shape]), SOLIS_CONF)

fqueue = FileQueue.new(Solis::ConfigFile[:kafka][:name], base_dir: '/Users/mehmetc/Dropbox/AllSources/Archiefpunt/data')
listener = Listen.to(fqueue.in_dir, only: /\.f$/) do |modified, added, _|
  files =  added | modified

  files.each do |in_filename|
    begin
      data = JSON.parse(File.read(in_filename))
      add_to_audit(data)
      add_to_elastic(data)
    rescue StandardError => e
      LOGGER.error(e.message)
    else
      filename = File.basename(in_filename)
      out_filename = "#{fqueue.out_dir}/#{filename}"
      FileUtils.move(in_filename, out_filename) unless out_filename.empty?
    end
  end
end
listener.start
sleep 2
FileUtils.touch(Dir.glob("#{fqueue.in_dir}/*.f"))

sleep