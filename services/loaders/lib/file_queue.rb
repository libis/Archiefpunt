require 'fileutils'
require 'json'

class FileQueue
  attr_accessor :base_dir, :in_dir, :out_dir, :fail_dir
  include Enumerable

  def initialize(name, options={})
    @name = name
    @base_dir = File.absolute_path(options[:base_dir] || "#{Dir.pwd}/data")

    @in_dir = "#{@base_dir}/in/#{name}"
    @out_dir = "#{@base_dir}/out/#{name}"
    @fail_dir = "#{@base_dir}/fail/#{name}"
    FileUtils.mkdir_p(@base_dir) unless Dir.exist?(@base_dir)
    FileUtils.mkdir_p(@in_dir) unless Dir.exist?(@in_dir)
    FileUtils.mkdir_p(@out_dir) unless Dir.exist?(@out_dir)
    FileUtils.mkdir_p(@fail_dir) unless Dir.exist?(@fail_dir)
  end

  def count
    Dir.glob("#{@in_dir}/*.f").count
  end

  def [](index)
    JSON.parse(File.read(Dir.glob("#{@in_dir}/*.f").sort[index]))
  end

  def <<(item)
    push(item)
  end

  def push(item)
    return nil if item.nil?

    filename = "%10.9f" % Time.now.to_f
    File.open("#{@in_dir}/#{filename}.f", 'wb') do |f|
      f.puts item.to_json
    end
  end

  def pop
    data = nil
    in_filename = Dir.glob("#{@in_dir}/*.f").sort.first
    out_filename = ''
    fail_filename = ''
    if in_filename
      data = JSON.parse(File.read(in_filename))

      filename = File.basename(in_filename)
      out_filename = "#{@out_dir}/#{filename}"
      fail_filename = "#{@fail_dir}/#{filename}"
    end

    data
  rescue StandardError => e
    puts e.message
  else
    FileUtils.move(in_filename, out_filename) unless out_filename.empty?
    data
  end

  def each
    Dir.glob("#{@in_dir}/*.f").sort.each do|f|
      yield JSON.parse(File.read(f))
    end
  end
end