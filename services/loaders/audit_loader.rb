require 'solis'
require 'hashdiff'
require 'logger'
require 'date'
require 'http'

def add_to_audit(data)
  entity = data['entity']['name']
  entity_plural = data['entity']['name_plural']
  id = data['entity']['id']
  graph = data['entity']['graph']

  subject_of_change = "#{graph}/#{entity_plural.underscore}/#{id}".gsub(/\/{2,}/,'/')
  diff = data['diff']

  created_date = data['timestamp'].is_a?(String) ? Date.parse(data['timestamp']) : data['timestamp']
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
  audit_url = "#{Solis::ConfigFile[:services][:audit][:host]}#{Solis::ConfigFile[:services][:audit][:base_path]}/change_sets"
  LOGGER.info(audit_url)
  response = HTTP.post(audit_url, :json => change_set )

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

def properties_to_hash(model)
  n = {}
  model.class.metadata[:attributes].each_key do |m|
    if model.instance_variable_get("@#{m}").is_a?(Array)
      n[m] = model.instance_variable_get("@#{m}").map { |iv| iv.class.ancestors.include?(Solis::Model) ? properties_to_hash(iv) : iv }
    elsif model.instance_variable_get("@#{m}").class.ancestors.include?(Solis::Model)
      n[m] = properties_to_hash(model.instance_variable_get("@#{m}"))
    else
      n[m] = model.instance_variable_get("@#{m}")
    end
  end

  n.compact!
end

def build_data(reason, diff, model)
  new_data = {
    entity: {
      id: model.id,
      name: model.name,
      name_plural: model.name(true),
      graph: model.class.graph_name
    },
    diff: diff,
    timestamp: Time.now,
    user: Graphiti.context[:object].query_user || 'unknown',
    misc: Graphiti.context[:object].other_data || {},
    change_reason: reason
  }
end

def load_entity(entity, total)
  limit = 100
  offset = 0
  while offset < total
    puts "#{entity} reading #{offset}/#{total}"
    ids = Solis::Query.run('', "SELECT DISTINCT ?s FROM <#{Solis::Options.instance.get[:graph_name]}> WHERE {?s ?p ?o ; a <#{Solis::Options.instance.get[:graph_name]}#{entity}>.} limit #{limit} offset #{offset}").map { |m| m[:s] }
    values = ids.map { |m| m.split('/').last }
    context = OpenStruct.new(query_user: 'system', other_data: {}, language: DATA_SOLIS_CONF[:language])
    Graphiti::with_context(context) do
      result = DATA_SOLIS.shape_as_resource(entity).all({ id: values })

      data = result.data
      data = [data] unless data.is_a?(Array)
      data.each do |model|
        n = properties_to_hash(model)
        diff = Hashdiff.best_diff({}, n)
        new_data = build_data('create', diff, model)
        add_to_audit(new_data.with_indifferent_access)
      end
    end
    exit 1
    offset += limit
  end
end

LOGGER = Logger.new(STDOUT)
DATA_SOLIS_CONF = Solis::ConfigFile[:services][:data][:solis]
DATA_SOLIS = Solis::Graph.new(Solis::Shape::Reader::File.read(DATA_SOLIS_CONF[:shape]), DATA_SOLIS_CONF)

total_archieven = Solis::Query.run('', "SELECT (COUNT(distinct ?s) as ?count) FROM <#{Solis::Options.instance.get[:graph_name]}> WHERE {?s ?p ?o ; a <#{Solis::Options.instance.get[:graph_name]}Archief>.}").first[:count].to_i
totaal_beheerders = Solis::Query.run('', "SELECT (COUNT(distinct ?s) as ?count) FROM <#{Solis::Options.instance.get[:graph_name]}> WHERE {?s ?p ?o ; a <#{Solis::Options.instance.get[:graph_name]}Beheerder>.}").first[:count].to_i
totaal_samenstellers = Solis::Query.run('', "SELECT (COUNT(distinct ?s) as ?count) FROM <#{Solis::Options.instance.get[:graph_name]}> WHERE {?s ?p ?o ; a <#{Solis::Options.instance.get[:graph_name]}Samensteller>.}").first[:count].to_i

load_entity('Archief', total_archieven)