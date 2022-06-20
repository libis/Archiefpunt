require 'listen'
require 'fileutils'
require 'logger'
require 'solis'

require '../data/lib/file_queue'

ENV['LISTEN_GEM_DEBUGGING']='info'

LOGGER = Logger.new(STDOUT)
Listen.logger = LOGGER

fqueue = FileQueue.new(Solis::ConfigFile[:kafka][:name], base_dir: '/Users/mehmetc/Dropbox/AllSources/Archiefpunt/data')
listener = Listen.to(fqueue.in_dir, only: /\.f$/) do |modified, added, _|
  files =  added | modified

  files.each do |file|
    data = JSON.parse(File.read(file))
    add_to_audit(data)
    add_to_elastic(data)
  end

end
listener.start
pp Dir.glob("#{fqueue.in_dir}/*.f")
FileUtils.touch(Dir.glob("#{fqueue.in_dir}/*.f"))

sleep