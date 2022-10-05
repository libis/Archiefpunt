require 'logger'
require_relative 'elastic/index'
require_relative 'elastic/alias'

class Elastic
  attr_reader :elastic, :index, :alias
  attr_accessor :logger

  def initialize(index_name, configuration_file_name, elastic = 'http://127.0.0.1:9200', logger = Logger.new(STDOUT))
    @logger = logger
    @elastic = elastic
    @index = Index.new("#{index_name}", configuration_file_name, elastic, @logger)
    @alias = Alias.new(configuration_file_name, elastic, @logger)
  end
end
