require 'curb'
require 'open-uri'
require 'json'

module Node2RPM
  # Dump registry.npmjs.org data
  class Registry
    def initialize(pkg)
      @pkg = pkg.sub('/', '%2F')
      @uri = REGISTRY + @pkg
      Dir.mkdir('/tmp/node2rpm') unless File.exist?('/tmp/node2rpm')
      @file = local_filename
    end

    def get
      # download the json file unless it is cached, returns json
      if @file.nil? && ping?
        query_upstream
      elsif cached?(@file)
        query_cache
      else
        raise 'No such node module ' + @pkg
      end
    end

    private

    def query_upstream
      http = Curl::Easy.perform(@uri)
      json = JSON.parse!(http.body_str)
      open(timed_filename, 'w:UTF-8') do |f|
        f.write JSON.pretty_generate(json)
      end
      json
    end

    def query_cache
      Node2RPM::Logger.new(@pkg + ': using cached version.')
      JSON.parse!(open(@file, 'r:UTF-8').read)
    end

    def ping?
      Curl::Easy.perform(@uri).response_code != 404
    end

    def base_filename
      '/tmp/node2rpm/' + @pkg
    end

    def header_time
      http = Curl::Easy.perform(@uri)
      Time.parse(http.header_str.match(/(l|L)ast-(m|M)odified:(.*?)\n/m)[3].strip)
    end

    def timed_filename
      base_filename + '_' + header_time.to_i.to_s
    end

    def local_filename
      Dir.glob(base_filename + '_*')[0]
    rescue StandardError
      nil
    end

    def cached?(file)
      return false if file.nil?
      Time.at(file.match(/_(.*?)$/)[1].to_i) == header_time
    end
  end
end
