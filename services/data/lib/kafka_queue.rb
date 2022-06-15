require  'rdkafka'
require 'uuidtools'

class KafkaQueue
  attr_reader :config, :id, :name
  include Enumerable

  def initialize(name, config=ConfigFile[:kafka])
    @name = name
    @config = config
    setup_kafka
    puts "Starting Kafka subscribing to topic #{@name}"
    kafka_alive?
  end

  def count
    raise 'not implemented'
  end

  def [](index)
    raise 'not implemented'
  end

  def <<(item)
    push(item)
  end

  def push(item)
    kafka_producer.produce(
      topic: @name,
      payload: item.to_json,
      key: UUIDTools::UUID.random_create.to_s
    )
  rescue StandardError => e
    puts e.message
  end

  def pop
    kafka_consumer(@name).poll(100)
  end

  def each
    kafka_consumer(@name).each do |message|
      yield message
    end
  end

  def close
    finalize_kafka
  end

  private

  def setup_kafka
    @id = "#{@name}-#{Time.now.to_i}-#{rand(10000)}"
    create_kafka_topic
  end

  def finalize_kafka
    kafka_consumer.close if kafka_consumer
    kafka_admin.close if kafka_admin
    kafka_producer.close if kafka_producer
  end

  def create_kafka_topic
    kafka_topic_handle = kafka_admin.create_topic(@name, 2, 1)
    kafka_topic_handle.wait(max_wait_timeout: 5)
  rescue Rdkafka::RdkafkaError => e
    puts e.message unless e.message =~ /topic_already_exists/ #ignore
  rescue StandardError => e
    puts e.message
  end

  def delete_kafka_topic
    kafka_topic_handle = kafka_admin.delete_topic(@name)
    kafka_topic_handle.wait(max_wait_timeout: 5)
  rescue StandardError => e
    puts e.message
  end

  def kafka_subscriptions
    kafka_consumer.subscription.to_h.keys
  end

  def kafka_consumer(subscription = nil)
    @consumer = nil if kafka_consumer_closed

    @consumer ||= begin
                    config = @config.clone
                    config[:"group.id"] = @id
                    kafka = Rdkafka::Config.new(config)

                    c=kafka.consumer
                    unless subscription.nil? && not(kafka_subscriptions.include?(subscription))
                      puts "subscribing to #{subscription}"
                      c.subscribe(subscription)
                    end
                    c
                  end
  end

  def kafka_consumer_closed
    @consumer.nil? && @consumer.instance_variable_get(:"@native_kafka").nil?
  end

  def kafka_producer
    @producer = nil if kafka_producer_closed
    @producer ||= begin
                 kafka = Rdkafka::Config.new(@config)

                 p = kafka.producer
               end

  end

  def kafka_producer_closed
    @producer.nil? && @producer.instance_variable_get(:"@native_kafka").nil?
  end


  def kafka_admin
    @admin = nil if kafka_admin_closed
    @admin ||= begin
                 kafka = Rdkafka::Config.new(@config)

                 kafka.admin
               end
  end

  def kafka_admin_closed
    @admin.nil? && @admin.instance_variable_get(:"@native_kafka").nil?
  end


  def kafka_alive?
    raise "Unable to connect to Kafka" if kafka_admin_closed
  end

end