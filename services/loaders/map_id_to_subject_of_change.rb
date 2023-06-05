#encoding: UTF-8
require 'solis'
require 'json'

def find_soc_query_arr(ids)

  filter = ids.map{|m| "'#{m}'" }.join(', ')

  %(
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX abv: <#{Solis::Options.instance.get[:graph_name]}>

select ?id ?subject_of_change where {
  ?subject_of_change ?p ?object_uri
  {
    SELECT ?id ?object_uri WHERE {
    ?object_uri abv:id ?id
      filter (?id in(#{filter}))
    }
  }
}
  )
end

def find_soc_query(id)
  %(
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX abv: <#{Solis::Options.instance.get[:graph_name]}>

select ?subject_of_change where {
  ?subject_of_change ?p ?object_uri
  {
    SELECT ?object_uri WHERE {
    ?object_uri
      abv:id '#{id}'
    }
  }
}
  )
end

DATA_SOLIS_CONF = Solis::ConfigFile[:services][:data][:solis]
DATA_SOLIS = Solis::Graph.new(Solis::Shape::Reader::File.read(DATA_SOLIS_CONF[:shape]), DATA_SOLIS_CONF)

BASE_DIR = '/Users/mehmetc/Desktop/stats_oldid'

stat = JSON.parse(File.read("#{BASE_DIR}/bwpl_stat.json", :encoding => 'iso-8859-1')) + JSON.parse(File.read("#{BASE_DIR}/ar_stat.json", :encoding => 'iso-8859-1')) + JSON.parse(File.read("#{BASE_DIR}/ae_stat.json", :encoding => 'iso-8859-1'))


offset=0
limit = 100
while offset < stat.length
  puts "#{offset}/#{stat.length}"
  offset_end = offset+limit
  if offset_end > stat.length
    offset_end = stat.length
  end


  data = stat[offset..offset_end]
  q = find_soc_query_arr(data.map{|m| m['id']})

  Solis::Query.run('EntiteitBasis', q).each do |r|
    d = data.find{|f| f['id'].eql?(r[:id])}
    d['subject_of_change'] = r[:subject_of_change] if r.key?(:subject_of_change)
    d['subject_of_change_id'] = r[:subject_of_change].split('/').last if r.key?(:subject_of_change)
  end

  offset += limit
end

File.open("#{BASE_DIR}/stats.json", 'wb') do |f|
  f.puts JSON.pretty_generate(stat)
end