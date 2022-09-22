RULES = {
  'archiefpunt' => {
    'info' => {
      '@.hits.total.value' => lambda do |d, query|
        total = d.to_i
        last = (query['from'].to_i + query['size'].to_i)
        last = d.to_i if last > total
        first =  query['from'] + 1
        first = d.to_i if first > total
        {'total': total, 'first': first, 'last': last }
      end
    },
    'docs' => {
      '@.hits.hits' => lambda do |d, query|
        result = d['_source']
        result['fiche']['data'] unless result.empty?
      end
    },
    'facets' => {
      '@.aggregations' => lambda do |d, query|
        result = {}

        d.each do |k, v|
          result[k] = v['buckets']
        end

        result
      end
    }
  }
}.freeze