require 'redis'
require 'json'
require 'connection_pool'
require 'lib/config_file'

class RedisQueue
  attr_reader :redis
  include Enumerable
  def initialize(name, redis_url=ConfigFile[:redis][:url])
    @name = name
    @redis = ConnectionPool::Wrapper.new(size:5) {Redis.new(url: redis_url)}

    raise "Unable to open redis at '#{redis_url}'" if @redis.nil?
  end

  def count
    @redis.llen(@name)
  end

  def [](index)
    @redis.lindex(@name, index)
  end

  def <<(item)
    push(item)
  end

  def push(item)
    @redis.lpush(@name, item.to_json)
  end

  def pop
    JSON.parse(@redis.rpop(@name))
  rescue StandardError => e
    nil
  end

  def each
    i = 0

    while (data=@redis.lindex(@name, i)).nil?
      yield data
      i += 1
    end
  end

end