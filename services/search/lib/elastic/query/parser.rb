require 'json'
require_relative 'indexes'

module Query
  class Parser
    attr_reader :query, :parsed

    def initialize(templates)
      @templates = templates
      @mappings = templates[:mapping]
      @indexes = Indexes.new(@mappings)
      @parsed = []
    end

    def parse(query)
      @query = query
      @parsed = determine_clause(
        determine_phrases(
          normalize_dates(
            normalize_operators(
              normalize_query(
                normalize_wildcard(
                  normalize_missing_index(
                    determine_indexes(
                      tokenize(query)
                    )
                  )
                )
              )
            )
          )
        )
      )
    end

    def parse_to_elasticsearch(raw_query_string, params)
      sort_map = JSON.load(File.read(@mappings[:sort]))
      elastic_query = JSON.load(File.read(@templates[:query])) || {}

      from = params.key?(:from) ? (params[:from].to_i - 1) : 0
      from = 0 if from < 0
      bulk_size = ((params[:bulksize] || params[:bulkSize]) || 10).to_i
      bulk_size = 100 if bulk_size > 100
      bulk_size = 10000 if params.key?(:forceLimit) && params[:forceLimit].eql?('0')

      elastic_query["from"] = from
      elastic_query["size"] = bulk_size
      if elastic_query.key?('query')
        unless elastic_query['query'].key?('bool')
          elastic_query['query']['bool'] = {}
        end

        unless elastic_query['query']['bool'].key?('must')
          elastic_query['query']['bool']['must'] = []
        end
      else
        elastic_query['query'] = { 'bool' => { 'must' => [] } }
      end

      elastic_query['sort'] = sort_map[params['sort']] if params.key?('sort') && !sort_map[params['sort']].nil?

      parsed = parse(raw_query_string)
      query = {}
      prev_index = nil
      prev_operator = 'AND'
      parsed.each do |clauses|
        clauses[:clause].each do |clause|
          index = clause[:index]
          operator = clause[:operator]
          terms = clause[:terms]

          bool_operator = 'must'

          if operator.eql?('OR')
            bool_operator = 'should'
          elsif operator =~ /NOT$/
            bool_operator = 'must_not'
          end

          query_fragment = query[bool_operator] || []

          if @indexes.query_mapping.has_key?(index) && @indexes.query_mapping[index].has_key?(terms)
              query_fragment << @indexes.query_mapping[index][terms]
          elsif @indexes.query_mapping.has_key?(index) && @indexes.query_mapping[index].has_key?("{{}}")
            q = @indexes.query_mapping[index]["{{}}"]

            query_fragment << JSON.parse(q.to_json.gsub('{{}}', terms))
          elsif index =~ /date/
            index = @indexes.facet_map[index]
            if terms =~ /^(-?\d{3,4}|NaN) TO (-?\d{3,4}|NaN)$/
              from_date = $1
              to_date = $2

              from_date = '1970' unless from_date =~ /^\d+$/ && from_date.length <= 4
              to_date = '9999' unless to_date =~ /^\d+$/ && to_date.length <= 4

              from_date = "#{from_date}-01-01"
              to_date = "#{to_date}-12-31"

              #query_fragment << {'range' => {index => {'gte' => from_date, 'lte' => to_date, 'relation' => 'CONTAINS'}}}
              #query_fragment << {'range' => {index => {'gte' => from_date, 'lte' => to_date, 'relation' => 'WITHIN'}}}
              query_fragment << { 'range' => { index => { 'gte' => from_date, 'lte' => to_date, 'relation' => 'INTERSECTS' } } }
            elsif terms =~ /^(-?\d{8}) TO (-?\d{8})$/
              from_date = $1
              to_date = $2

              #query_fragment << {'range' => {index => {'gte' => from_date, 'lte' => to_date, 'relation' => 'CONTAINS'}}}
              #query_fragment << {'range' => {index => {'gte' => from_date, 'lte' => to_date, 'relation' => 'WITHIN'}}}
              query_fragment << { 'range' => { index => { 'gte' => from_date, 'lte' => to_date, 'relation' => 'INTERSECTS' } } }
            end
          elsif index =~ /^facet_/
            index = @indexes.facet_map[index]

            query_fragment << { "term" => { "#{index}" => terms.gsub(/^"/, '').gsub(/"$/, '') } }
          else
            real_index = @indexes.index_map[index]

            if index.eql?('rid')
              if terms.is_a?(Array)
                terms = terms.map { |m| m.gsub(/^"TN_/, '"') }
              else
                terms = terms.gsub(/^"TN_/, '"')
              end
            end

            qs = JSON.load(File.read(@mappings[:query_string]))
            qs_index = 0
            qs_operator = operator.eql?('NOT') ? 'AND' : operator
            unless query_fragment.empty?
              if prev_index == index && qs_operator == prev_operator
                qs = query_fragment.select { |s| s.key?('query_string') }
                qs = qs.empty? ? JSON.load(File.read(@mappings[:query_string])) : qs.first
                qs_index = query_fragment.rindex(qs)
              else
                qs_index = query_fragment.size
              end
            end
            qs['query_string']["fields"] << real_index
            qs['query_string']["fields"]&.flatten!&.uniq!
            qs['query_string']["query"] += ' ' if qs['query_string']["query"].length > 0

            # https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-query-string-query.html#_reserved_characters
            #qs['query_string']["query"] += terms.is_a?(Array) ? terms.join(' ') : terms
            qs['query_string']["query"] += (terms.is_a?(Array) ? terms.join(' ') : terms).gsub(/([\+\-\=\&\|\>\<\!\(\)\{\}\[\]^\"\~\*\?:\/])/, '\\\\\1')

            qs['query_string']["query"] = qs['query_string']["query"].strip
            qs['query_string']["default_operator"] = qs_operator
            query_fragment[qs_index] = qs
          end
          prev_index = index
          prev_operator = qs_operator
          query[bool_operator] = query_fragment.flatten
        end

      end

      query.each do |op, data|
        case op
        when 'must'
          elastic_query['query']['bool']['must'] += data
        when 'should'
          elastic_query['query']['bool']['must'] << { "bool" => { "should" => data } }
        when 'must_not'
          elastic_query['query']['bool']['must'] << { "bool" => { "must_not" => data } }
        end
      end

      elastic_query
    end

    private

    def tokenize(query)
      parsed = []
      query.scan(/\w+|\W/) do |token|
        token_offset = $~.offset(0)
        case token
        when ":"
          parsed << { value: token, delete: false, type: 'colon', offset: token_offset }
        when '"'
          parsed << { value: token, delete: false, type: 'quote', offset: token_offset }
        when '('
          parsed << { value: token, delete: false, type: 'open_round_bracket', offset: token_offset }
        when ')'
          parsed << { value: token, delete: false, type: 'close_round_bracket', offset: token_offset }
        when '['
          parsed << { value: token, delete: false, type: 'open_box_bracket', offset: token_offset }
        when ']'
          parsed << { value: token, delete: false, type: 'close_box_bracket', offset: token_offset }
        when /OR|AND|NOT/
          parsed << { value: token, delete: false, type: 'operator', offset: token_offset }
        else
          parsed << { value: token, delete: false, type: 'term', offset: token_offset } #unless token.eql?(' ')
        end
      end
      parsed
    end

    def normalize_query(parsed)
      parsed.each_with_index do |p, i|
        if p[:value].eql?(' ') || p[:value].empty?
          if (parsed[i + 1] && !parsed[i + 1][:type].eql?('term')) && (parsed[i - 1] && !parsed[i - 1][:type].eql?('term'))
            p[:delete] = true
          end
        end

      end

      parsed.delete_if { |d| d[:delete] }

      parsed
    end

    def normalize_missing_index(parsed)
      i = 0
      while parsed[i][:type].eql?('open_round_bracket')
        i += 1
      end

      unless parsed[i][:type].eql?('index')
        parsed.insert(i, { value: "any", delete: false, type: "index", offset: [] })
      end

      parsed.select { |s| s[:type].eql?('operator') }.each do |operator|
        index = parsed.rindex(operator)
        parsed[index..].each_with_index do |p, i|
          break if p[:type].eql?('index')
          if p[:type].eql?('open_round_bracket')
            parsed.insert(index + i, { value: "any", delete: false, type: "index", offset: [] })
          end
        end
      end

      parsed
    end

    def normalize_wildcard(parsed)
      parsed.each do |p|
        if p[:value].eql?('*')
          index = parsed.rindex(p)
          if index - 1 > 0 && parsed[index - 1][:type].eql?('term')
            parsed[index - 1][:value] = "#{parsed[index - 1][:value]}*"
            parsed[index][:delete] = true
          end
        end
      end
      parsed
    end

    def normalize_operators(parsed)
      parsed.each do |p|
        if p[:type].eql?('operator')
          index = parsed.rindex(p)
          if p[:value].eql?('AND')
            if index + 1 <= parsed.length - 1
              if parsed[index + 1][:type].eql?('operator') && parsed[index + 1][:value].eql?('NOT')
                parsed[index][:delete] = true
              end
            end
          end
        end
      end

      parsed.delete_if { |d| d[:delete] }
      parsed
    end

    def normalize_dates(parsed)
      new_date_range = []
      date_ranges = parsed.select { |s| s[:type].eql?('index') && s[:value] =~ /(start|end)date$/ }
      if date_ranges.length > 0
        index = parsed.rindex(date_ranges[0])
        date_range_operator = { value: 'AND', type: 'operator', delete: false, offset: [0, 0] }
        date_ranges.each do |date_range|
          start_index = parsed.rindex(date_range)
          end_index = find_closing_box_bracket(start_index, parsed)
          terms = parsed[start_index..end_index].select { |s| s[:type].eql?('term') }
          if date_range[:value].eql?('enddate')
            new_date_range << terms.first[:value]
          else
            new_date_range << terms.last[:value]
          end

          until parsed[start_index][:type].eql?('operator') || start_index < 1
            start_index -= 1
          end
          date_range_operator = parsed[start_index].clone

          parsed[start_index..end_index].each { |d| d[:delete] = true }
        end

        parsed[index] = date_range_operator
        parsed[index + 1] = { value: ' ', type: 'term', delete: false, offset: [0, 0] }
        parsed[index + 2] = { value: 'date_range', type: 'index', delete: false, offset: [0, 0] }
        parsed[index + 3] = { value: new_date_range.join(' TO '), type: 'date_range', delete: false, offset: [0, 0] }
      end

      parsed.delete_if { |d| d[:delete] }

      indexes = parsed.select { |s| s[:type].eql?('index') && s[:value] =~ /date/ }
      indexes.each do |index|
        date_ranges = parsed[parsed.index(index)..].select { |s| s[:type].eql?('open_box_bracket') }
        date_ranges.each do |date_range|
          start_index = parsed.index(date_range)
          end_index = find_closing_box_bracket(start_index, parsed)
          terms = parsed[start_index..end_index].select { |s| s[:type].eql?('term') }.map { |m| m[:value] }.join('').split(' TO ')

          parsed[start_index..end_index].each { |d| d[:delete] = true }
          parsed[start_index] = { value: terms.join(' TO '), type: 'date_range', delete: false, offset: [0, 0] }
          parsed.delete_if { |d| d[:delete] }
        end
      end

      parsed
    end

    def determine_indexes(parsed)
      colon = parsed.select { |s| s[:type].eql?('colon') }
      colon.each do |c|
        index = parsed.rindex(c)
        if index > 0
          term_index = index - 1
          term = parsed[term_index]
          if @indexes.include?(term[:value])
            c[:delete] = true
            parsed[term_index][:type] = 'index'
          end
        end
      end
      parsed.delete_if { |d| d[:delete] }
      parsed
    end

    def determine_phrases(parsed)
      while (quotes = parsed.select { |s| s[:type].eql?('quote') }).length > 0
        phrase = []
        quote_index = parsed.rindex(quotes[0])

        parsed[quote_index..parsed.length].each_with_index do |t, i|
          if t[:type].eql?('quote') && i > 0
            t[:delete] = true
            break
          else
            phrase << t.clone if i > 0
            t[:delete] = true
          end

        end

        parsed[quote_index] = { value: phrase, delete: false, type: 'phrase', offset: [phrase.first[:offset][0], phrase.last[:offset][1]] }
        parsed.delete_if { |d| d[:delete] }
      end

      parsed
    end

    def find_closing_box_bracket(candidate_index_start, parsed)
      candidate_index_end = -1
      bracket_counter = 0
      parsed[candidate_index_start..parsed.length].each_with_index do |part, index|
        bracket_counter += 1 if part[:type].eql?('open_box_bracket')
        bracket_counter -= 1 if part[:type].eql?('close_box_bracket')

        if part[:type].eql?('close_box_bracket') && bracket_counter == 0
          candidate_index_end = candidate_index_start + index
          break
        end
      end
      candidate_index_end
    end

    def find_closing_round_bracket(candidate_index_start, parsed)
      candidate_index_end = -1
      bracket_counter = 0
      parsed[candidate_index_start..parsed.length].each_with_index do |part, index|
        bracket_counter += 1 if part[:type].eql?('open_round_bracket')
        bracket_counter -= 1 if part[:type].eql?('close_round_bracket')

        if part[:type].eql?('close_round_bracket') && bracket_counter == 0
          candidate_index_end = candidate_index_start + index
          break
        end
      end
      candidate_index_end
    end

    def remove_matching_rounded_brackets(data)
      until (open_round_brackets = data.select { |s| s[:type].eql?('open_round_bracket') }).empty?
        start_index = data.index(open_round_brackets.first)
        matching_bracket = find_closing_round_bracket(start_index, data)
        if matching_bracket.eql?(data.length - 1)
          data.delete_at(matching_bracket)
          data.delete_at(start_index)
        else
          break
        end
      end

      data
    end

    def determine_clause(parsed)
      new_parsed = []
      data = remove_matching_rounded_brackets(parsed.clone)
      # data.each do |d|
      #     d[:delete] = true if d[:type].eql?('term') && (d[:value].eql?(' ') || d[:value].eql?(''))
      # end

      offset_start = 0
      offset_end = 0
      data.each_with_index do |d, i|
        offset_end += d[:value].length
        d[:offset] = [offset_start, offset_end]
        offset_start = offset_end
      end

      indexmap = make_indexmap(data)

      indexmap.each do |s|
        index = s[0]
        all_operators = data.select { |m| m[:type].eql?('operator') }.map { |m| m[:offset] = []; m }
        if all_operators.map { |m| m[:value] }.uniq.compact.size == 1 && !all_operators.map { |m| m[:value] }.uniq.compact.include?('NOT')
          default_operator = all_operators.first
        else
          default_operator = { type: 'operator', value: 'AND', delete: false, offset: [] }
        end
        clause = data[s[1]..s[2]].clone

        operatormap = make_operatormap(clause)

        sub_queries = []
        operator = default_operator
        if operatormap.map { |m| m[0][:value] }.uniq.compact.size == 1
          operator = operatormap.first.first
        end
        if operatormap && operatormap.length > 0 && operatormap.first.first[:value].eql?('NOT')
          operatormap.each do |op|
            op.first[:value] = 'NOT'
          end
        end

        operatormap.each_with_index do |om, i|
          op = operatormap.last[0]
          # if op[:value].eql?('NOT') && i == 0 && i < operatormap.size-1
          #   op = default_operator
          #   operator = op
          # end
          terms = clause[om[1]..om[2]]
          next if terms.empty? || terms.map { |m| m[:value] }.join('').strip.empty?

          sub_queries << { index: index[0], operator: op, terms: terms }
        end
        unless sub_queries.empty?
          clause = sub_queries
        else
          next if clause.empty? || clause.map { |m| m[:value] }.join('').strip.empty?
          clause = [{ index: index[0], operator: operator, terms: clause }]
        end

        # if operatormap.empty?
        #   operator = default_operator
        # else
        #   operator = operatormap.first.first
        # end

        new_parsed << { index: index[0], operator: operator, clause: clause }
      end

      parsed = []
      new_parsed.each do |n|
        clause = []

        n[:clause].each do |c|
          terms = build_terms(c[:terms])
          clause << { index: c[:index][:value], operator: c[:operator][:value], terms: terms }
        end
        parsed << { index: n[:index][:value], operator: n[:operator][:value], clause: clause }
      end

      parsed
    end

    def build_terms(data)
      query = ''
      data.each do |value|
        case value[:type]
        when 'term'
          query += value[:value]
        when 'phrase'
          phrase = "\"#{value[:value].map { |n| n[:value] }.join("")}\""
          query += phrase
        else
          next if ['index', 'operator'].include?(value[:type])
          query += value[:value]
        end
      end
      query.strip.gsub(/^\(*/, '').gsub(/\)*$/, '')
    end

    def make_operatormap(data)
      operators = data.select { |s| s[:type].eql?('operator') }
      operator_map = []
      operators.each_with_index do |operator, index|
        operator_index = data.index(operator)
        if index == 0 && operator_index > 0
          operator_map << [operator, 0, operator_index - 1]
        end

        if index + 1 < operators.length
          next_operator = operators[index + 1]
          next_operator_index = data.index(next_operator)
          operator_map << [operator, operator_index + 1, next_operator_index - 1]
        else
          operator_map << [operator, operator_index + 1, data.size - 1]
        end
      end
      operator_map
    end

    def make_indexmap(data)
      indexes = data.select { |s| s[:type].eql?('index') }
      indexes_map = indexes.map { |m| [m, data.index(m)] }

      m = []
      indexes_map.each_with_index do |_, i|
        start_index = indexes_map[i][1] + 1
        until data[start_index][:type].eql?('operator') || start_index < 1
          start_index -= 1
        end
        start_index = indexes_map[i][1] + 1 if start_index < 1

        if i == indexes_map.size - 1
          end_index = data.size - 1
        else
          end_index = indexes_map[i + 1][1] - 1
        end
        until data[end_index][:type].eql?('operator') || end_index < 1 || end_index < start_index
          end_index -= 1
        end

        end_index -= 1 if data[end_index][:type].eql?('operator')

        if end_index < 1 || end_index <= start_index
          if i == indexes_map.size - 1
            end_index = data.size - 1
          else
            end_index = indexes_map[i + 1][1] - 1
          end
        end
        if indexes_map.size - 1 == i && end_index != data.size - 1
          end_index = data.size - 1
        end
        m << [_, start_index, end_index]
      end
      m
    end

  end
end