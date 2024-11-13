#encoding: UTF-8
require 'csv'
require 'json'
require 'http'
require 'data_collector'

key = ENV['ArchiefpuntQKey']
lookup = {
  "exkolonies" => "0d88312a-6b7f-4ff2-ba19-1461816542f1",
  "historisch" => "172cd17c-74d6-4a5a-acd4-39b4a65eef4a",
  "Europees500duizendofofficieel" => "295ba7c4-4409-4444-9524-58a86a5c4d64",
  "varia" => "64301553-100b-460d-b6ce-b2f084f6dccb" ,
  "religieus" => "7ac2ca76-a407-4b30-aedb-72d2beae1bf9" ,
  "migratie" => "ac01d12e-3219-40b7-a89c-5167a009e888" ,
  "top10020mil" => "cba64670-ee2c-4816-a63a-f8b4f514bf7a"
}

languages = []
CSV.foreach('/Users/mehmetc/Dropbox/AllSources/Archiefpunt/services/loaders/talen.csv',
            :headers => true, :col_sep => ';', :encoding => 'utf-8') do |csv|



  data = {
    'label' => csv[1],
    'definitie' => csv[0],
    'type' => {'id' => lookup[csv[2].gsub(/[^a-zA-Z0-9]/,'')]},
  }
  begin
  response = DataCollector::Input.new.from_uri('https://data.q.archiefpunt.be/talen', headers: { 'Authorization' => "Bearer #{key}"})
  next if DataCollector::Core.filter(response, '$..attributes.label').flatten.include?(data['label'])

  response = HTTP.post('https://data.q.archiefpunt.be/talen', json: data, headers: { 'Authorization' => "Bearer #{key}" })

  if response.status != 200
    puts data['definitie']
    puts response.body.to_s
    puts "\n\n"
  else
    puts data['definitie']
  end

  rescue StandardError => e
    puts e
  end


  languages << data
end

=begin
PUT https://data.q.archiefpunt.be/talen/4164-B28D-E9B6-A870-5A7555CTTL9A
{
  "identificatienummer": {"id": "295ba7c4-4409-4444-9524-58a86a5c4d64"},
  "label": "eng",
  "definitie": "Engels"
}

PUT https://data.q.archiefpunt.be/talen/4164-B28D-E9B6-A870-5A7554CTTL9A
{
  "identificatienummer": {"id": "295ba7c4-4409-4444-9524-58a86a5c4d64"},
  "label": "deu",
  "definitie": "Duits"
}
DELETE https://data.q.archiefpunt.be/talen/d99f1517-1663-4c66-9f3b-9e4fcf380af3

PUT https://data.q.archiefpunt.be/talen/4164-B28D-E9B6-A870-5A7553CTTL9A
{
  "identificatienummer": {"id": "295ba7c4-4409-4444-9524-58a86a5c4d64"},
  "label": "fra",
  "definitie": "Frans"
}

DELETE https://data.q.archiefpunt.be/talen/9a94bcf0-bbbc-4fcc-b451-a5a137110118

PUT https://data.q.archiefpunt.be/talen/4164-B28D-E9B6-A870-5A7552CTTL9A
{
  "identificatienummer": {"id": "295ba7c4-4409-4444-9524-58a86a5c4d64"},
  "label": "nld",
  "definitie": "Nederlands"
}

DELETE https://data.q.archiefpunt.be/talen/1bb14d67-b215-414c-8bf1-4208094fc092
=end