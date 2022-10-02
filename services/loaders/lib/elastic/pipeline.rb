class Pipeline
  def initialize(name)
    @name = name
    super
  end

  def exist?
    response = HTTP.head("#{@elastic}/_ingest/pipeline/#{@name}", headers: {'Accept' => 'application/json'})
    response.code == 200
  end

  def create
    raise "Pipeline #{@name} already exists" if exist?
    raise 'Configuration not loaded correctly' unless @configuration

    puts "Creating index #{@name}"
    response = HTTP.put("#{@elastic}/#{@name}", body: @configuration.to_json,
                        headers: {'Content-Type' => 'application/json'})
    puts response.code
    return true if response.code == 200

    raise "Failed to create index #{@name} \n#{response.body}"
  end

  def delete

  end

end