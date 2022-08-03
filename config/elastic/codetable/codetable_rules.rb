RULES = {
  'archiefpunt' => {
    'codetabel' => {
      '@' => lambda do |d, query|
        result = []
        out = DataCollector::Output.new

        rules_ng.run(RULES['codetabel'], d, out, query)
        result << out[:data]
        out.clear

        result.flatten! unless result.empty? || result.nil?
        result.uniq! unless result.empty? || result.nil?

        result.compact
      end
    }
  },
  'codetabel' => {
    'data' => {
      '@.hits.hits[*]._source' => lambda do |d, query|

        browse = filter(query, '$..bool..query')
        index = filter(query, '$..fields[0]')

        browse = browse.first unless browse.nil? || browse.empty?
        index = (index.first unless index.nil? || index.empty?)

        return d if (browse.nil? || browse.empty?) || (index.nil? || index.empty?) && d.include?(index&.gsub(/\.label/, ''))

        findex = index.split('.')
        candidates = filter(d, "$..#{findex.join('..')}")&.grep(/#{browse}/i)

        candidates = [candidates] unless candidates.is_a?(Array)
        {"#{findex[0]}": d[findex[0]].select{|s| candidates.include?(s['label'])}}
        d
      end
    }
  }

}.freeze
