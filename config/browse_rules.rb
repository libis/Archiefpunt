RULES = {
  'archiefpunt' => {
    'browse' => {
      '@' => lambda do |d, query|
        result = []
        out = DataCollector::Output.new
        rules_ng.run(RULES['browse'], d, out, query)
        result << out[:data]
        out.clear

        result.flatten! unless result.empty? || result.nil?
        result.uniq! unless result.empty? || result.nil?

        result
      end
    }
  },
  'browse' => {
    'data' => {
      '@.hits.hits[*]._source.auto' => lambda do |d, query|
        browse = filter(query, '$..bool..query')
        index = filter(query, '$..fields[0]')

        browse = browse.first unless browse.nil? || browse.empty?
        index = (index.first unless index.nil? || index.empty?)&.gsub(/^auto\./, '')

        return [] if (browse.nil? || browse.empty?) || (index.nil? || index.empty?) && d.include?(index)
        candidates = d[index]
        candidates = [candidates] unless candidates.is_a?(Array)

        candidates.grep(/#{browse}/i)
      end
    }
  }

}.freeze