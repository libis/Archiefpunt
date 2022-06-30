# frozen_string_literal: true

$LOAD_PATH << '.' << '..'
require 'lib/elastic'
require 'solis'
require 'lib/solis/store/sparql/client'

$SERVICE_ROLE = :search

def elastic_config
  @elastic_config ||= Solis::ConfigFile[:services][$SERVICE_ROLE][:elastic]
end

def archief_as_jsonld(c, archief_ids)
  raise 'Please supply an archief uuid' if archief_ids.nil? || archief_ids.empty?
  context = JSON.parse %(
{
    "@context": {
        "@vocab": "#{Solis::Options.instance.get[:graph_name]}",
        "id": "@id"
    },
    "@type": "Archief",
    "@embed": "@always"
}
                     )
  f = File.read('/Users/mehmetc/Dropbox/AllSources/LIBIS/archiefbank_api/esbridge-api/config/constructs/expanded_archief2.sparql')

  archief_ids = [archief_ids] unless archief_ids.is_a?(Array)
  archief_ids = archief_ids.map { |m| "<#{m}>" }.join(" ")

  q = f.gsub('{{VALUES}}', "VALUES ?archief_id { #{archief_ids} }")

  r = c.query(q)
  t = r.query('select * where{?s ?p ?o}')

  g = RDF::Graph.new
  t.each do |s|
    g << [s.s, s.p, s.o]
  end

  #puts g.dump(:ttl)

  framed = nil
  JSON::LD::API.fromRDF(g) do |e|
    framed = JSON::LD::API.frame(e, context)
  end
  framed
end

solis = Solis::Graph.new(Solis::Shape::Reader::File.read(Solis::ConfigFile[:shape]), Solis::ConfigFile[:solis])
elastic = Elastic.new(elastic_config[:index],
                      elastic_config[:mapping],
                      elastic_config[:host])

elastic.index.delete if elastic.index.exist?
elastic.index.create unless elastic.index.exist?

# result = solis.shape_as_resource('Archief').all({ stats: { total: :count }, page: {number:1, size:5} })
# data = result.data
# puts data[0].to_ttl

SOLIS_CONF = Solis::ConfigFile[:services][:data][:solis]
c = Solis::Graph.new(Solis::Shape::Reader::File.read(SOLIS_CONF[:shape]), SOLIS_CONF)


count_alle_archieven = c.query("SELECT (COUNT(distinct ?s) as ?count) FROM <#{Solis::Options.instance.get[:graph_name]}> WHERE {?s ?p ?o ; a <#{Solis::Options.instance.get[:graph_name]}Archief>.}").first[:count].object

limit = 1000
offset = 0

#while offset < 100
while offset < count_alle_archieven
  puts "reading #{offset}/#{count_alle_archieven}"
  q_alle_archieven = "SELECT DISTINCT ?s FROM <#{Solis::Options.instance.get[:graph_name]}> WHERE {?s ?p ?o ; a <#{Solis::Options.instance.get[:graph_name]}Archief>.} limit #{limit} offset #{offset}"
  alle_archieven = c.query(q_alle_archieven)

  ids = []
  alle_archieven.each do |s|
    ids << s.s.to_s
  end

  s = 0
  e = 0
  step = 100
  while e < ids.length
    #while e < 300
    d = ids.length - e
    e = if d < step
          ids.length
        else
          s + step
        end

    data = archief_as_jsonld(c, ids[s..e])
    elastic.index.insert(data['@graph'], 'id', true)
    s = e
  end
  offset += limit
end