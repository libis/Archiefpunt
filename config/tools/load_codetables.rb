$LOAD_PATH << '.' << './lib'

require 'solis'
require 'solis/shape/reader/simple_sheets'
require 'pp'
require 'uuidtools'
require 'active_support/all'

def encode_id(data)
  data.unpack("H*")[0].to_i(16).to_s(36)
end

def decode_id(data)
  [data.to_i(36).to_s(16)].pack('H*')
end

key = Solis::ConfigFile[:key]
code_table_id = '1jcpRRt13mMlZzUtNntsEE6tA4DZCnzKnzvT8hMf4wkM'

solis = Solis::Graph.new(Solis::Shape::Reader::File.read(Solis::ConfigFile[:shape]), Solis::ConfigFile[:solis])
session = SimpleSheets.new(key, code_table_id)
sheets = {}
session.worksheets.each do |worksheet|
  sheet = ::Sheet.new(worksheet)
  sheets[sheet.title] = sheet
end

sheets.each do |tab_name, tab_data|
  puts tab_name
  if solis.shape?(tab_name)
    resource = solis.shape_as_resource(tab_name)

    tab_data.each do |data|
      label = data['label']
      id_label = "#{tab_name.underscore}.#{label}"
      id = UUIDTools::UUID.sha1_create(UUIDTools::UUID_URL_NAMESPACE, id_label)
      type = data['type']
      definitie = data['definitie']
      # query = { "filter" => { "id" => { "eq" => "#{id}" } } }
      query = { "filter" => { "label" => { "eq" => "#{label}" } } }
      if resource.model.metadata[:attributes]['label'][:maxcount].nil?
        query = { "filter" => { "label" => { "eq" => "[\"#{label}\"]" } } }
      end

      if resource.all(query).first.nil?
        Solis::LOGGER.info("#{id_label} - #{id} - #{label}")
        model = solis.shape_as_model(tab_name)

        insert_data = {
          id: id,
          identificatienummer: { id: id },
          label: label
        }

        unless definitie.empty? || definitie.nil?
          insert_data[:definitie] = definitie
        end
        Solis::LOGGER.info("\t#{id} - #{id_label} - #{tab_name}(#{label}) created")
        result = model.new(insert_data).save
      else
        Solis::LOGGER.info("\t#{id} - #{id_label} - #{tab_name}(#{label}) exists")
      end
    end
  else
    Solis::LOGGER.error("\t #{tab_name} not found")
  end
end