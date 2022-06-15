module Query
  class Indexes
    def initialize(mappings)
      @facet_map = JSON.load(File.read(mappings[:facet]))
      @index_map = JSON.load(File.read(mappings[:index]))
      @query_mapping = {}
      if mappings.has_key?(:query_mapping)
        @query_mapping = JSON.load(File.read(mappings[:query_mapping]))
      end
      @indexlist = (@facet_map.keys + @index_map.keys + @query_mapping.keys).select { |s| s !~ /local/ } || {}
    end

    def facet_map
      @facet_map
    end

    def index_map
      @index_map
    end

    def list
      @indexlist
    end

    def query_mapping
      @query_mapping
    end

    def include?(key)
      case key
      when /lsr\d+/
        return true
      when /facet_local\d+/
        return true
      else
        return @indexlist.include?(key) ? true : false
      end
    end
  end
end