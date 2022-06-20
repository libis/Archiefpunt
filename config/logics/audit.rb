require 'solis/options'
require 'solis/query'

module Logic
  module Audit
    def laad_audit_links(params)
      result = Solis::Query.run_construct_with_file('./config/construct/audit.sparql', 'audit_id', 'audit', params[:ids])

    end
  end
end