require 'json'
require 'ostruct'
require 'curb'
require 'nokogiri'
require 'node-semver'

module Node2RPM
  class Bower
    def initialize
      @bower ||= []
    end

    def bower?(pkg, dependencies)
      return unless dependencies.key?('bower')
      @bower << pkg
      dependencies.delete('bower')
      dependencies
    end

    def status
      @bower
    end

    def prepare_components(pkgs)
      return if pkgs.empty?
      pkgs.each do |pkg|
        current_dir = File.expand_path('.')
        tarball = Dir.glob(current_dir + "/#{pkg}-*").select { |x| x.end_with?('.tgz') }[0]
        dir = File.join(current_dir, File.basename(tarball, File.extname(tarball)))
        unless File.exist?(dir)
          Dir.mkdir dir
          IO.popen("tar --warning=none --no-same-owner --no-same-permissions -xf #{tarball} -C #{dir} --strip-components=1").close
        end
        bower_json = File.join(dir, 'bower.json')
        p bower_structs(bower_json)
      end
    end

    private

    def bower_structs(json_file)
      structs = []
      dependencies = bower_dependencies(json_file)
      dependencies.each do |k, v|
        s = OpenStruct.new
        s.name = k
        fits = fit_versions(lookup(k), v)
        s.version = Semver.max_satisfying(fits, v)
        structs << s
      end
      structs
    end

    def bower_dependencies(json_file)
      json = JSON.parse(open(json_file, 'r:UTF-8').read)
      json['dependencies']
    end

    def lookup(string)
      r = Curl::Easy.new('http://bower.herokuapp.com/packages/' + string)
      r.perform
      r.response_code != '404' ? JSON.parse(r.body_str)['url'] : nil
    end

    def fit_versions(url, range, versions = [])
      tmp = []
      html = Nokogiri::HTML(open(url.sub('.git', '') + '/tags'))
      version_objs = html.xpath('//span[@class="tag-name"]')
      version_objs.each { |v| tmp << v.text if Semver.satisfies(v.text, range) }
      # no need to get all versions, just versions in range
      # !tmp.empty? means no fit in this page and next pages.
      # !versions.empty? to eliminate the case if the first page doesn't have any
      # versions fit.
      if html.xpath('//diiv[@class="pagination"]/a') && !tmp.empty? && !versions.empty?
        pagelinks = []
        html.xpath('//div[@class="pagination"]/a/@href').each { |href| pagelinks << href.value }
        # has previous and next, always use the last one in array, which is next.
        # in the last page, there's only a 'previous' href, we should consider this.
        newlink = pagelinks[pagelinks.size - 1] if pagelinks[pagelinks.size - 1].text == 'Next'
        newlink.nil? ? versions.concat(tmp) : fit_versions(newlink, range, versions)
      else
        versions.concat(tmp)
      end
      versions
    end
  end
end
