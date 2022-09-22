$LOAD_PATH << '.' << 'lib'
require 'http'
require 'json'
require 'solis'
require 'lib/elastic'
require 'data_collector'

include DataCollector::Core

$SERVICE_ROLE = :search

def logic_config
  Solis::ConfigFile[:services][:data_logic]
end

def elastic_config
  @elastic_config ||= Solis::ConfigFile[:services][$SERVICE_ROLE][:elastic]
end

SOLIS_CONF = Solis::ConfigFile[:services][:data][:solis]
SOLIS = Solis::Graph.new(Solis::Shape::Reader::File.read(SOLIS_CONF[:shape]), SOLIS_CONF)

elastic = Elastic.new('archiefpunt_ftxt', #elastic_config[:index],
                      elastic_config[:mapping],
                      elastic_config[:host])

elastic.index.delete if elastic.index.exist?
elastic.index.create unless elastic.index.exist?

def load_data(elastic, total, filename, entity, entity_id)
  limit = 1000
  offset = 0

  while offset < total
    puts "#{entity} reading #{offset}/#{total}"
    ids = Solis::Query.run('', "SELECT DISTINCT ?s FROM <#{Solis::Options.instance.get[:graph_name]}> WHERE {?s ?p ?o ; a <#{Solis::Options.instance.get[:graph_name]}#{entity}>.} limit #{limit} offset #{offset}").map { |m| m[:s] }

    s = 0
    e = 0
    step = 100

    while e < ids.length
      d = ids.length - e
      e = if d < step
            ids.length
          else
            s + step
          end

      data = Solis::Query.run_construct_with_file(filename, entity_id, entity, ids[s..e])
      #data = data.map{|m| {"#{entity.underscore}": m}}
      begin
        yield data, entity
      rescue StandardError => x
        puts x.message
      end

      s = e
    end
    offset += limit
  end
rescue StandardError => x
  puts x.message
end

def apply_data_to_query_list(data, entity, query_list)
  new_data = []
  data.each do |d|
    id = filter(d, '$.id').first

    query_list.each do |index_key, v|
      v = [v] unless v.is_a?(Array)
      nd = []
      v.each do |w|
        w.each do |i, j|
          j = [j] unless j.is_a?(Array)
          j.each do |k|
            if k.is_a?(Hash)
              sout = {}
              k.each { |a, b|
                t = filter(d, b)
                t.each do |s|
                  sout[a] = s
                end
              }

              nd << { index_key => { 'id' => id, i => sout } }
            else
              t = filter(d, k)
              t.each do |s|
                if i.eql?('datering')
                  gte, lte = s.split('/')
                  nd << { index_key => { 'id' => id, i => { 'gte' => gte, 'lte' => lte } } }
                else
                  nd << { index_key => { 'id' => id, i => s } }
                end
              end
            end
          end
        end
      end

      if v.length == 1
        new_data.concat(nd)
      else
        tnd = {}
        nd.map { |m| m[index_key] }.compact.map { |m| m.delete_if { |k, v| k.eql?('id') } }.each { |e|
          if tnd.key?(e.keys.first)
            a = tnd[e.keys.first]
            if a.is_a?(Hash)
              a = a.merge(e.values.first)
            else
              a = [a] unless a.is_a?(Array)
              a << e.values.first
            end

            tnd[e.keys.first] = a
          else
            tnd[e.keys.first] = e.values.first
          end
        }

        new_data << { index_key => { 'id' => id }.merge(tnd) }
      end
    end

    # new_data << { "#{entity.underscore}" => d }
  end
  new_data
end

total_archieven = 100#Solis::Query.run('',"SELECT (COUNT(distinct ?s) as ?count) FROM <#{Solis::Options.instance.get[:graph_name]}> WHERE {?s ?p ?o ; a <#{Solis::Options.instance.get[:graph_name]}Archief>.}").first[:count].to_i
load_data(elastic, total_archieven,'./config/constructs/expanded_archief2.sparql', 'Archief', 'archief_id') do |data, entity|
  query_list = {
    # 'archief_via_samensteller' => [{'samensteller' => '$..samensteller[*].naam'}, {'samensteller_rol' => '$..samensteller[*].rol'}],
    # 'archief_via_beheerder' => [{'beheerder' => '$..beheerder[*].naam'}, {'beheerder_rol' => '$..beheerder[*].rol'}],
    # 'archief_via_materiaaltype'=> {'materiaal_type' => '$..omvang[*].trefwoord'},
    # 'archief_via_topologie' => [{ 'topologie' => '$..beschrijvingsniveau'}, {'topologie' => '$..beheerder[*].rol'}, {'topologie' => '$..samensteller[*].rol'}],
    # 'archief_via_geografie' => {'geografie' => ["$..associatie[*].plaatsnaam", "$..beheerder[*].adres[*].gemeente"]},
    # 'archief_via_trefwoord' => {'trefwoord' => '$..associatie[*].onderwerp'},
    # 'archief_via_titel' => {'titel' => '$..titel'},
    # 'agent' => [{'waarde' => '$..titel'}, {'record_type' => '$..record_type'}],
    'fiche' => [{'titel' => '$..titel'},
                {'record_type' => '$..record_type'},
                {'beschrijvingsniveau' => '$..beschrijvingsniveau'},
                {'beheerder' => {'naam' => '$..beheerder[*].naam', 'rol' => '$..beheerder[*].rol'} },
                {'geografie' => ["$..associatie[*].plaatsnaam", "$..beheerder[*].adres[*].gemeente"]},
                {'samensteller' => {'naam' => '$..samensteller[*].naam', 'rol' => '$..samensteller[*].rol'}},
                {'agent' => [{'naam' => '$..beheerder[*].naam', 'record_type' => '$..beheerder[*].rol'}, {'naam' => '$..samensteller[*].naam', 'record_type' => '$..samensteller[*].rol'}]},
                {'trefwoord' => '$..associatie[*].onderwerp'},
                {'materiaal_type' => '$..omvang[*].trefwoord'},
                {'datering' => '$..datering_systematisch'},
                {'datering_text' => '$..datering_text'},
                {'generated_date' => '$..generated_date'},
                {'data' => '@'}]
  }

  new_data = apply_data_to_query_list(data, entity, query_list)

  elastic.index.insert(new_data, 'id', true)
end

totaal_beheerders = 100 #Solis::Query.run('', "SELECT (COUNT(distinct ?s) as ?count) FROM <#{Solis::Options.instance.get[:graph_name]}> WHERE {?s ?p ?o ; a <#{Solis::Options.instance.get[:graph_name]}Beheerder>.}").first[:count].to_i
load_data(elastic, totaal_beheerders, './config/constructs/expanded_beheerder.sparql', 'Beheerder', 'beheerder_id') do |data, entity|
  query_list = {
    #    'beheerder_via_plaats' => { 'plaats' => "$..adres[*].gemeente" },
    #'agent_via_naam_of_type' => [{ "agent_naam" => '$..agent[*].naam[*].waarde' }, { "agent_naam_type" => '$..agent[*].naam[*].type' }],
    #'agent' => [{'waarde' => '$..agent[*].naam[*].waarde'}, {'record_type' => '$..record_type'}],
    'fiche' => [{ 'record_type' => '$..record_type' },
                { 'beheerder' => { 'naam' => '$..agent[*].naam[*].waarde', 'rol' => '$..agent[*].naam[*].type' }},
                { 'agent' => { 'naam' => '$..agent[*].naam[*].waarde', 'record_type' => '$..record_type' } },
                { 'geografie' => "$..adres[*].gemeente" },
                { 'datering' => '$..agent[*].datering_systematisch' },
                { 'datering_text' => '$..datering_text' },
                { 'generated_date' => '$..generated_date' },
                { 'data' => '@' }
    ]
  }

  new_data = apply_data_to_query_list(data, entity, query_list)
  elastic.index.insert(new_data, 'id', true)
end

totaal_samenstellers = 100 #Solis::Query.run('',"SELECT (COUNT(distinct ?s) as ?count) FROM <#{Solis::Options.instance.get[:graph_name]}> WHERE {?s ?p ?o ; a <#{Solis::Options.instance.get[:graph_name]}Samensteller>.}").first[:count].to_i
load_data(elastic, totaal_samenstellers, './config/constructs/expanded_samensteller.sparql', 'Samensteller', 'samensteller_id') do |data, entity|
  query_list = {
    #'samensteller_via_naam' => { 'naam' => "$..agent.naam" },
    #'agent_via_naam_of_type' => [{ "agent_naam" => '$..agent[*].naam[*].waarde' }, { "agent_type" => '$..agent[*].naam[*].type' }],
    #'agent' => [{'waarde' => '$..agent.naam'}, {'record_type' => '$..record_type'}],
    'fiche' => [{ 'record_type' => '$..record_type' },
                { 'samensteller' => { 'naam' => '$..agent.naam', 'rol' => '$..agent.type' }},
                { 'agent' => { 'naam' => '$..agent.naam' , 'record_type' => '$..record_type' } },
                { 'geografie' => "$..agent.associaties[*].plaats" },
                { 'datering' => '$..agent[*].datering_systematisch' },
                { 'datering_text' => '$..datering_text' },
                { 'generated_date' => '$..generated_date' },
                { 'data' => '@' }]
  }

  new_data = apply_data_to_query_list(data, entity, query_list)
  elastic.index.insert(new_data, 'id', true)
end

response = HTTP.get("#{logic_config[:host]}/#{logic_config[:base_path]}/plaats")
data = {}
if response.status == 200
  data = JSON.parse(response.body.to_s)
end

data.each do |d|
  elastic.index.insert( {"plaats": d}, 'id', true)
end