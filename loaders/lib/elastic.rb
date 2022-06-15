require_relative 'elastic/index'

class Elastic
  attr_reader :elastic, :index

  def initialize(index_name, configuration_file_name, elastic = 'http://127.0.0.1:9200')
    @elastic = elastic
    @index = Index.new("#{index_name}", configuration_file_name, elastic)
  end
end
