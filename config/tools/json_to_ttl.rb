$LOAD_PATH << '.' << './lib'
require 'bundler'
Bundler.require

require 'logger'
require 'solis'
require 'json'

@running = true
Signal.trap('TERM') do
  puts 'Terminating...'
  @running = false
end

def worker(d, i, wid)
  SOLIS.shape_as_model(d['type'].classify).new(d['attributes'])
  #WORKER_MODEL.new(d['attributes'])
rescue StandardError => e
  @logger.error("#{wid} - #{e.message}")
  puts JSON.pretty_generate(d)
  File.open('bad.json', 'ab') do |f|
    f.puts JSON.pretty_generate(d)
  end
  nil
end

@logger = Logger.new(STDOUT)
READ_QUEUE = Queue.new
WRITE_QUEUE = Queue.new
READERS = []
WRITERS = []
SOLIS = Solis::Graph.new(Solis::Shape::Reader::File.read(Solis::ConfigFile[:shape]), Solis::ConfigFile[:solis])

#WORKER_MODEL = Plaats
#WORKER_MODEL = Contactpersoon
#WORKER_MODEL = Archief
#WORKER_MODEL_NAME = WORKER_MODEL.new.class.name.to_sym

5.times do |x|
  READERS << Thread.new do
    worker_id = x
    @logger.info("Starting reader #{worker_id}")
    while @running || READ_QUEUE.length > 0
      x = READ_QUEUE.pop
      next if x.nil? || READ_QUEUE.empty?
      data = x[:data]
      index = x[:index]
      file_id = x[:file]

      @logger.info("READ - #{worker_id} - #{File.basename(file_id)} - #{data['id']}")
      begin
        WRITE_QUEUE << { id: data['id'], model: worker(data, index, worker_id), file: file_id }
      rescue StandardError => e
        @logger.error("#{file_id} - #{e.message}")
      end
    end
    @logger.info("Stopping reader #{worker_id}")
  end
end

5.times do |x|
  WRITERS << Thread.new do
    worker_id = x
    @logger.info("Starting writer")

    while @running || WRITE_QUEUE.length > 0
      data = WRITE_QUEUE.pop
      next if data.nil? || WRITE_QUEUE.empty?
      @logger.info("WRITE - #{worker_id} - #{File.basename(data[:file])} - #{data[:id]}")
      tries = 0
      File.open("config/exports/ttl/#{data[:model].class.name}_#{worker_id}.ttl", 'ab') do |f|
        begin
          tries += 1
          f.puts data[:model].to_ttl
        rescue StandardError => e
          @logger.error("#{data[:file]} - #{data[:id]} - #{e.message}")
          if tries < 3
            sleep 5
            @logger.info("Retrying...")
            retry
          end
        end
      end
    end
    @logger.info("Stopping writer")
  end
end

file_list = ARGV
file_list = Dir.glob('config/exports/*.json') if file_list.empty?

file_list.each do |file_id|
  @logger.info("Reading #{File.absolute_path(file_id)}")
  data = JSON.load(File.read(File.absolute_path(file_id)))

  data.each_with_index do |d, i|
    READ_QUEUE << { data: d, index: i, file: file_id }

    if READ_QUEUE.size > 1000
      while READ_QUEUE.size > 0
        sleep 5
      end
      GC.start
    end

  end

  @logger.info("READ QUEUE size = #{READ_QUEUE.length}")
end

i = 0
while READ_QUEUE.length > 0 || WRITE_QUEUE.length > 0
  @logger.info("IN=#{READ_QUEUE.length}  OUT=#{WRITE_QUEUE.length}")
  GC.start if i.modulo(500) == 0
  sleep 5
  i += 1
end

@running = false

@logger.info('stopping reader threads')
READERS.each do |worker|
  worker.join(5)
end

@logger.info('stopping writer threads')
WRITERS.each do |worker|
  worker.join(5)
end

READ_QUEUE.close
WRITE_QUEUE.close

puts "done"
exit 1
