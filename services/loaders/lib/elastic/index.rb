require 'http'
require 'json'
require 'logger'
require_relative '../ext/array'

class Index
  attr_reader :name, :elastic, :type, :configuration, :logger

  def initialize(name, configuration_file_name, elastic = 'http://127.0.0.1:9200', logger = Logger.new(STDOUT))
    @logger = logger
    @name = name
    @elastic = elastic
    @configuration = load_configuration_file(configuration_file_name)
    @type = '_doc' #@configuration['mappings'].keys.first if @configuration
  end

  def exist?
    response = HTTP.head("#{@elastic}/#{@name}", headers: {'Accept' => 'application/json'})
    response.code == 200
  end

  def create
    raise "Index #{@name} already exists" if exist?
    raise 'Configuration not loaded correctly' unless @configuration

    @logger.info "Creating index #{@name}"
    response = HTTP.put("#{@elastic}/#{@name}", body: @configuration.to_json,
                        headers: {'Content-Type' => 'application/json'})
    @logger.info "status #{response.code}"
    return true if response.code == 200

    raise "Failed to create index #{@name} \n#{response.body}"
  end

  def delete
    raise "Index #{@name} does not exist" unless exist?

    @logger.info "Deleting index #{@name}"
    response = HTTP.delete("#{@elastic}/#{@name}")

    return true if response.code == 200

    raise "Failed to delete index #{@name} \n#{response.body}"
  end


  def delete_data(data, id = 'id', save_to_disk = false, id_prefix='')
    raise "Index #{@name} does not exist" unless exist?
    raise "Index type is not set. Configuration not loaded" unless @type

    data = [data] unless data.is_a?(Array)
    if save_to_disk
      File.open("#{Time.new.to_i}-#{rand(100000)}.ndjson", "wb") do |f|
        f.puts data.to_ndjson(@name, id, "delete", id_prefix)
      end
    end

    @logger.info "Deleting #{data.size} from #{@name}/#{@type}"
    response = HTTP.post("#{@elastic}/_bulk",
                         headers: {'Content-Type' => 'application/x-ndjson'},
                         body: data.to_ndjson(@name, id, "delete", id_prefix))

    body = JSON.parse(response.body.to_s)
    return body if response.code == 200
    return body unless body["errors"]

    raise "Failed to delete record from #{@name}, #{response.code}, #{response.body.to_s}"
  end

  def insert(data, id = 'id', save_to_disk = false)
    raise "Index #{@name} does not exist" unless exist?
    raise "Index type is not set. Configuration not loaded" unless @type
    raise "Data can not be nil" if data.nil?

    data = [data] unless data.is_a?(Array)

    return '' if data.nil? || data.empty?

    filename = "#{Time.new.to_i}-#{rand(100000)}"
    if save_to_disk
      File.open("./ndjson/#{filename}.ndjson", "wb") do |f|
        f.puts data.to_ndjson(@name, id, "index")
      end
    end

    @logger.info "Inserting #{data.size} into #{@name}/#{@type}"
    response = HTTP.post("#{@elastic}/_bulk",
                         headers: {'Content-Type' => 'application/x-ndjson'},
                         body: data.to_ndjson(@name, id, "index"))

    response_body = JSON.parse(response.body.to_s)
    raise "Failed to insert record into #{@name}, #{"./ndjson/#{filename}.ndjson"} - #{response.code}, #{response.body.to_s}" if response.code != 200
    raise "Failed to insert record into #{@name}, #{"./ndjson/#{filename}.ndjson"} - #{response.code}, #{response_body.to_s}" if response_body["errors"]

    response_body.to_s
  end

  def get_by_id(id)
    response = HTTP.get("#{@elastic}/#{@name}/#{@type}/#{id}")
    return response.body if response.code == 200

    raise "Failed to load record #{id} form #{@name} index"
  end

  private

  def load_configuration_file(configuration_file_name)
    raise 'Configuration file not found' unless File.exist?(configuration_file_name)
    JSON.parse(File.read(configuration_file_name))
  end
end

