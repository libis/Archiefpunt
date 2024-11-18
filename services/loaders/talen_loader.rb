#encoding: UTF-8
require 'csv'
require 'json'
require 'http'
require 'data_collector'

key = ENV['ArchiefpuntQKey']
lookup = {}

# response = HTTP.get("https://data.q.archiefpunt.be/type_concepten", headers: { 'Authorization' => "Bearer #{key}" })
# data = JSON.parse(response.body)
# data['data'].map{|m| m['id']}.each do |entry|
#   response = HTTP.delete("https://data.q.archiefpunt.be/type_concepten/#{entry}", headers: { 'Authorization' => "Bearer #{key}" })
#   if response.code == 200
#     puts "DELETE #{entry}"
#   else
#     data = JSON.parse(response.body)
#     pp data
#   end
# end

concepten = ['historisch', 'migratie', 'varia', 'religieus', 'Europees, > 500 duizend of officieel', 'ex-kolonies',
             'top 100, < 20 mil']
concepten.each do |concept|
  puts concept
  response = HTTP.get("https://data.q.archiefpunt.be/type_concepten?filter[label][eq]={{#{URI.encode_uri_component(concept)}}}", headers: { 'Authorization' => "Bearer #{key}" })
  if response.code == 200
    data = JSON.parse(response.body)
    if data['data'].empty?
        data = {
        'label' => concept,
      }
      response = HTTP.post("https://data.q.archiefpunt.be/type_concepten", json: data, headers: { 'Authorization' => "Bearer #{key}" })
      if response.code == 200
        data = JSON.parse(response.body)
        lookup.store(concept.gsub(/[^a-zA-Z0-9]/,''), data['data']['id'])
      else
        puts "unable to write #{concept}"
      end
    else
        data = JSON.parse(response.body)
        lookup.store(concept.gsub(/[^a-zA-Z0-9]/,''), data['data'].map{|m| m['id']}.last)
    end
  else
    puts "awch"
  end

end


pp lookup


languages = []
CSV.foreach('/Users/mehmetc/Dropbox/AllSources/Archiefpunt/services/loaders/talen.csv',
            :headers => true, :col_sep => ';', :encoding => 'utf-8') do |csv|

  data = {
    'id' => csv[1],
    'label' => csv[0],
    'type' => {'id' => lookup[csv[2].gsub(/[^a-zA-Z0-9]/,'')]},
  }
  begin
  response = DataCollector::Input.new.from_uri('https://data.q.archiefpunt.be/talen?page[size]=1000', headers: { 'Authorization' => "Bearer #{key}"})
  if DataCollector::Core.filter(response, '$..id').include?(data['id'])
    puts "\t update #{data['label']}"
    response = HTTP.put("https://data.q.archiefpunt.be/talen/#{data['id']}", json: data, headers: { 'Authorization' => "Bearer #{key}" })
    if response.status != 200
      puts data['label']
      puts response.body.to_s
      puts "\n\n"
    else
      puts data['label']
    end
  else
    puts "\t create #{data['label']}"
    response = HTTP.post('https://data.q.archiefpunt.be/talen', json: data, headers: { 'Authorization' => "Bearer #{key}" })

    if response.status != 200
      puts data['label']
      puts response.body.to_s
      puts "\n\n"
    else
      puts data['label']
    end
  end

  rescue StandardError => e
    puts e
  end


  languages << data
end

=begin
POST https://data.q.archiefpunt.be/talen
{
  "id": "eng",
  "label": "Engels"
}


deu, https://data.q.archiefpunt.be/talen/4164-B28D-E9B6-A870-5A7554CTTL9A
nld, https://data.q.archiefpunt.be/talen/4164-B28D-E9B6-A870-5A7552CTTL9A
fra, https://data.q.archiefpunt.be/talen/4164-B28D-E9B6-A870-5A7553CTTL9A
eng, https://data.q.archiefpunt.be/talen/4164-B28D-E9B6-A870-5A7555CTTL9A

# update data with language reference
prefix abv: <https://data.q.archiefpunt.be/>
with abv:
delete {
  ?s ?p <https://data.q.archiefpunt.be/talen/4164-B28D-E9B6-A870-5A7554CTTL9A>.
} insert {
  ?s ?p <https://data.q.archiefpunt.be/talen/deu>.
} where {
	?s ?p <https://data.q.archiefpunt.be/talen/4164-B28D-E9B6-A870-5A7554CTTL9A>.
}


#delete language codetable entry
DELETE https://data.q.archiefpunt.be/talen/4164-B28D-E9B6-A870-5A7552CTTL9A
DELETE https://data.q.archiefpunt.be/talen/4164-B28D-E9B6-A870-5A7553CTTL9A
DELETE https://data.q.archiefpunt.be/talen/4164-B28D-E9B6-A870-5A7554CTTL9A
DELETE https://data.q.archiefpunt.be/talen/4164-B28D-E9B6-A870-5A7555CTTL9A


=end