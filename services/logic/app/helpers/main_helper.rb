require 'active_support/all'
require 'moneta'
require 'solis'

Dir.glob("#{Solis::ConfigFile[:services][:logic][:logics]}/**/*.rb").each do |logic|
  puts "Load logic from #{logic}"
  require "#{logic}"
end


module Sinatra
  module MainHelper

    def all_logic_modules
      Logic.constants.select{|c| Logic.const_get(c).is_a?(Module)}
    end

    def all_logic(m = Logic)
      m.public_instance_methods.map{|m| m.to_s}
    end

    def all_logic_url
      #TODO: get parameters class.method(:uitleenbaar).parameters
      @logic_urls ||= begin
                        l = []
                        l += all_logic.map{|m| "#{Solis::ConfigFile[:services][:logic][:base_path]}/#{m}"}
                        all_logic_modules.each do |c|
                          l += all_logic(Logic.const_get(c)).map{|m| "#{Solis::ConfigFile[:services][:logic][:base_path]}/#{c.downcase}/#{m}"}
                        end
                        l
                        end
    end

    def call_logic
      call_stack = params[:splat].first.split('/')
      call_stack_params = params.select{|k,v| !k.eql?('splat')}
      if call_stack.size > 2
        raise "call stack can only be 1 deep"
      end

      if call_stack.size == 1
        if call_stack_params && call_stack_params.size > 0
          Class.new.extend( Logic).send(call_stack[0].to_sym, call_stack_params)
        else
          Class.new.extend( Logic).send(call_stack[0].to_sym)
        end
      else
        if call_stack_params && call_stack_params.size > 0
          Class.new.extend( Logic.const_get(call_stack[0].classify)).send(call_stack[1].to_sym, call_stack_params)
        else
          Class.new.extend( Logic.const_get(call_stack[0].classify)).send(call_stack[1].to_sym)
        end
      end
    rescue ArgumentError => e
      e.message
    rescue StandardError => e
      LOGGER.error(e.class)
      LOGGER.error(e.message)
      raise RuntimeError, "A runtime error occured see logs: #{e.message}"
    end

  end
  helpers MainHelper
end