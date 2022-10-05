class Alias
  def initialize(configuration_file_name, elastic = 'http://127.0.0.1:9200', logger = Logger.new(STDOUT))
    @logger = logger
    @elastic = elastic
    @configuration = load_configuration_file(configuration_file_name)
  end

  def index(name)
    result = []
    response = HTTP.get("#{@elastic}/_alias/#{name}")

    body = response.body.to_s

    result = JSON.parse(body).keys if response.status == 200
    result
  end

  def add(name, index)
    actions = {
      "actions": [
        { "add": { "index": index, "alias": name, "is_write_index": true } }
      ]
    }

    response = HTTP.post("#{@elastic}/_aliases", json: actions, headers: {'Content-Type' => 'application/json'})
    response.status == 200 ? true : false
  end

  def remove(name, index)
    actions = {
      "actions": [
        { "remove": { "index": index, "alias": name} }
      ]
    }

    response = HTTP.post("#{@elastic}/_aliases", json: actions, headers: {'Content-Type' => 'application/json'})
    response.status == 200 ? true : false
  end

  def replace(name, o_index, n_index)
    actions = {
      "actions": [
        { "remove": { "index": o_index, "alias": name} },
        { "add": { "index": n_index, "alias": name, "is_write_index": true } }
      ]
    }

    response = HTTP.post("#{@elastic}/_aliases", json: actions, headers: {'Content-Type' => 'application/json'})
    response.status == 200 ? true : false
  end

  private

  def load_configuration_file(configuration_file_name)
    raise 'Configuration file not found' unless File.exist?(configuration_file_name)
    JSON.parse(File.read(configuration_file_name))
  end

end