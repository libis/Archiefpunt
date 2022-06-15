class Array
  def to_ndjson(index, id_label = 'id', action = "index", id_prefix = '')
# ES < 7  def to_ndjson(index, type, id_label = 'id', action = "index", id_prefix = '')
    output = ''
    each do |data|
      next if data.nil?
      id = data.key?(id_label) ? data[id_label] : nil

      nd_index = if id
                   {"#{action}": {"_index": index, "_id": "#{id_prefix}#{id}"}}
#ES <7             {"#{action}": {"_index": index, "_type": type, "_id": "#{id_prefix}#{id}"}}
                 else
                   {"#{action}": {"_index": index}}
#ES < 7            {"#{action}": {"_index": index, "_type": type}}
                 end

      output += "#{nd_index.to_json}\n"
      output += "#{data.to_json}\n" unless action.eql?("delete")
    end

    output
  end
end
