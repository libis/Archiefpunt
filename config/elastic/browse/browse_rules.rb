RULES = {
  'archiefpunt' => {
    'browse' => {
      '@' => lambda do |d, query|
        result = []
        out = DataCollector::Output.new
        if !filter(query, '$..range').empty?
          rules_ng.run(RULES['browse_7days'], d, out, query)
        elsif !filter(query, '$..fields[?(@ =~ /beheerder|samensteller/i)]').empty?
          rules_ng.run(RULES['browse_bewaarplaats_archiefvormer'], d, out, query)
        elsif filter(query, '$..fields').include?('plaats.label')
          rules_ng.run(RULES['browse_plaats'], d, out, query)
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
      '@.hits.hits[*]._source.fiche' => lambda do |d, query|
        { id: d['id'], titel: d['titel'], laatste_wijziging: d['generated_date'] }
      end
    }
  },
  'browse_bewaarplaats_archiefvormer' => {
    'data' => {
      '@.hits.hits[*]._source.fiche.data' => lambda do |d, query|

        result = []
        if filter(query, '$..fields').select { |s| s =~ /beheerder|bewaarplaats/ }.size > 0 && filter(d, '$..id').select { |s| s =~ /beheerder/ }.size > 0
          if d.key?('beheerder')
            d['beheerder'].each do |beheerder|
              result << { id: beheerder['id'], waarde: beheerder['naam'] }
            end
          else
            result << { id: d['id'], waarde: filter(d, '$..naam..waarde').first }
          end
        elsif filter(query, '$..fields').select { |s| s =~ /samensteller|archiefvormer/ }.size > 0 && filter(d, '$..id').select { |s| s =~ /samensteller/ }.size > 0
          if d.key?('samensteller')
            d['samensteller'].each do |samensteller|
              result << { id: samensteller['id'], waarde: samensteller['naam'] }
            end
          else
            result << { id: d['id'], waarde: filter(d, '$..naam..waarde').first }
          end
        end
        result
      end
    }
  },
  'browse' => {
    'data' => {
      '@.hits.hits[*]._source.fiche' => lambda do |d, query|
        browse = filter(query, '$..bool..query')
        index = filter(query, '$..fields[0]')

        browse = browse.first unless browse.nil? || browse.empty?
        index = (index.first unless index.nil? || index.empty?)&.gsub(/^fiche\./, '')

        return d if (browse.nil? || browse.empty?) || (index.nil? || index.empty?) && d.include?(index)
        findex = index.split('.')

        # candidates = [d].map{|m| m[index]&.grep(/#{browse}/i) || filter(m, "$..#{findex[0]}[?(@['#{findex[1]}'] =~ /#{browse}/i)]")}
        candidates = [d].map do |m|
          i = m[index]
          i = [i] unless i.is_a?(Array)

          i&.grep(/#{browse}/i) | filter(m, "$..#{findex.join('..')}")&.grep(/#{browse}/i)
        end

        candidates = [candidates] unless candidates.is_a?(Array)
        candidates
      end
    }
  },
  'browse_plaats' => {
    'data' => {
      '@.hits.hits[*]._source.plaats' => lambda do |d, query|
        d
      end
    }
  }
}.freeze
