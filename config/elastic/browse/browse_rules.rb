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

        result.compact
      end
    }
  },
  'browse' => {
    'data' => {
      '@.hits.hits[*]._source.archief.auto' => lambda do |d, query|
        browse = filter(query, '$..bool..query')
        index = filter(query, '$..fields[0]')

        browse = browse.first unless browse.nil? || browse.empty?
        index = (index.first unless index.nil? || index.empty?)&.gsub(/^archief.auto\./, '')

        return d if (browse.nil? || browse.empty?) || (index.nil? || index.empty?) && d.include?(index)
        #findex = index.split('.').join('..')
        #candidates = d.map{|m| m[index]||filter(m, "$..#{findex}")}
        findex = index.split('.')
        candidates = d.map{|m| [m[index]].grep(/#{browse}/i) || filter(m, "$..#{findex[0]}[?(@['#{findex[1]}'] =~ /#{browse}/i)]")}
        candidates = [candidates] unless candidates.is_a?(Array)

        #candidates.flatten.grep(/#{browse}/i)
        candidates.flatten
      end
    }
  }

}.freeze