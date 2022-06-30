RULES = {
  'archiefpunt' => {
    'browse' => {
      '@' => lambda do |d, query|
        result = []
        out = DataCollector::Output.new
        if !filter(query, '$..range').empty?
          rules_ng.run(RULES['browse_7days'], d, out, query)
        elsif !filter(query, '$..fields[?(@ =~ /bewaarplaats|archiefvormer/i)]').empty?
          rules_ng.run(RULES['browse_bewaarplaats_archiefvormer'], d, out, query)
        else
          rules_ng.run(RULES['browse'], d, out, query)
        end
        result << out[:data]
        out.clear

        result.flatten! unless result.empty? || result.nil?
        result.uniq! unless result.empty? || result.nil?

        result.compact
      end
    }
  },
  'browse_7days' => {
    'data' => {
      '@.hits.hits[*]._source.archief' => lambda do |d, query|
        { id: d['id'], titel: d['auto'].map { |a| a['archief_titel'].map { |m| m['waarde'] } }.flatten, laatste_wijziging: d['generated_date'] }
      end
    }
  },
  'browse_bewaarplaats_archiefvormer' => {
    'data' => {
      '@.hits.hits[*]._source.archief.auto' => lambda do |d, query|

        result = []
        if !filter(query, '$..fields[?(@ =~ /bewaarplaats/i)]').empty?
          d.each do |bewaarplaats|
            bewaarplaats['bewaarplaats'].each do |b|
              result << { id: b['id'], waarde: b['naam'] }
            end
          end
        elsif !filter(query, '$..fields[?(@ =~ /archiefvormer/i)]').empty?
          d.each do |archiefvormer|
            archiefvormer['archiefvormer'].each do |b|
              result << { id: b['id'], waarde: b['naam'] }
            end
          end
        end
        result
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
        findex = index.split('.')

        #candidates = d.map{|m| m[index]&.grep(/#{browse}/i) || filter(m, "$..#{findex[0]}[?(@['#{findex[1]}'] =~ /#{browse}/i)]")}
        candidates = d.map do |m|
          i = m[index]
          i = [i] unless i.is_a?(Array)

          i&.grep(/#{browse}/i) | filter(m, "$..#{findex.join('..')}")&.grep(/#{browse}/i)
        end

        candidates = [candidates] unless candidates.is_a?(Array)
        candidates
      end
    }
  }

}.freeze
