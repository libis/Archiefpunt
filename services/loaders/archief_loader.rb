$LOAD_PATH << '.' << 'lib'
require 'solis'
require 'lib/elastic'


$SERVICE_ROLE = :search

def elastic_config
  @elastic_config ||= Solis::ConfigFile[:services][$SERVICE_ROLE][:elastic]
end

solis = Solis::Graph.new(Solis::Shape::Reader::File.read(Solis::ConfigFile[:shape]),
                 Solis::ConfigFile[:solis])

elastic = Elastic.new(elastic_config[:index],
                      elastic_config[:mapping],
                      elastic_config[:host])


elastic.index.delete if elastic.index.exist?
elastic.index.create unless elastic.index.exist?

def load_data(elastic, total, filename, entity, entity_id)
  limit = 1000
  offset = 0

  while offset < total
    puts "#{entity} reading #{offset}/#{total}"
    ids = Solis::Query.run('', "SELECT DISTINCT ?s FROM <https://abv.libis.be/> WHERE {?s ?p ?o ; a <https://abv.libis.be/#{entity}>.} limit #{limit} offset #{offset}").map{|m| m[:s]}

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
      data = data.map{|m| {"#{entity.underscore}": m}}
      elastic.index.insert(data, 'id', true)
      s = e
    end
    offset += limit
  end
rescue StandardError => e
  puts e.message
end

total_archieven = Solis::Query.run('',"SELECT (COUNT(distinct ?s) as ?count) FROM <https://abv.libis.be/> WHERE {?s ?p ?o ; a <https://abv.libis.be/Archief>.}").first[:count].to_i
load_data(elastic, total_archieven,'./config/constructs/expanded_archief2.sparql', 'Archief', 'archief_id')

totaal_beheerders = Solis::Query.run('',"SELECT (COUNT(distinct ?s) as ?count) FROM <https://abv.libis.be/> WHERE {?s ?p ?o ; a <https://abv.libis.be/Beheerder>.}").first[:count].to_i
load_data(elastic, totaal_beheerders,'./config/constructs/expanded_beheerder.sparql', 'Beheerder', 'beheerder_id')

totaal_samenstellers = Solis::Query.run('',"SELECT (COUNT(distinct ?s) as ?count) FROM <https://abv.libis.be/> WHERE {?s ?p ?o ; a <https://abv.libis.be/Samensteller>.}").first[:count].to_i
load_data(elastic, totaal_samenstellers,'./config/constructs/expanded_samensteller.sparql', 'Samensteller', 'samensteller_id')