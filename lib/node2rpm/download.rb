require 'curb'
require 'open-uri'
require 'json'

module Node2RPM
  class Download
    def initialize(pkg)
      if pkg =~ %r{^(@[^/%]+)/(.*)$}
        pkg = Regexp.last_match(1) + '%2F' + Regexp.last_match(2)
      end
      @url = REGISTRY + pkg
      @uri = URI.parse(@url)
      Dir.mkdir('/tmp/node2rpm') unless File.exist?('/tmp/node2rpm')
      @filename = File.join('/tmp/node2rpm', %r{.*\/(.*)}.match(@uri.path)[1])
    end

    def get
      # download the json file unless it exists and is
      # with a week, then return the json.
      # @param [String]
      # @return [Hash]

      if File.exist?(@filename) && !Node2RPM::Cache.new(@filename).clear?
        JSON.parse!(open(@filename, 'r:UTF-8').read)
      elsif exist?
        r = Curl::Easy.new(@url)
        r.perform
        json = JSON.parse!(r.body_str)
        open(@filename, 'w:UTF-8') { |f| f.write JSON.pretty_generate(json) }
        json
      else
        raise 'No such node module ' \
          + @url.sub(REGISTRY, '') + '. please check your spelling.'
      end
    end

    private

    def exist?
      r = Curl::Easy.new(@url)
      r.perform
      r.response_code == 404 ? false : true
    end
  end
end
