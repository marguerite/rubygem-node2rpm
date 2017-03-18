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
      Dir.mkdir 'bower_components'
      pkgs.each do |pkg|
        current_dir = File.expand_path('.')
        tarball = Dir.glob(current_dir + "/#{pkg}-*").select { |x| x.end_with?('.tgz') }[0]
        dir = File.join(current_dir, File.basename(tarball, File.extname(tarball)))
        unless File.exist?(dir)
          Dir.mkdir dir
          IO.popen("tar --warning=none --no-same-owner --no-same-permissions -xf #{tarball} -C #{dir} --strip-components=1").close
        end
        bower_json = File.join(dir, 'bower.json')
        dest = File.join('bower_components', pkg)
        Dir.mkdir dest
        bower_structs(bower_json).each { |d| fillup(d, dest) }
      end
      IO.popen('tar -cf bower_components.tgz bower_components').close
    end

    private

    def bower_structs(json_file)
      structs = []
      bower_dependencies(json_file).each do |k, v|
        s = OpenStruct.new
        s.name = k
        url = lookup(k)
        fits = fit_versions(url + '/tags', v)
        s.version = Semver.max_satisfying(fits, v)
        s.url = url + '/archive/' + s.version + '.tar.gz'
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
      r.response_code != '404' ? JSON.parse(r.body_str)['url'].sub('.git', '') : nil
    end

    def fit_versions(url, range, versions = [])
      html = Nokogiri::HTML(open(url))
      version_objs = html.xpath('//span[@class="tag-name"]')
      tmp = []
      # sometimes the tag is not numberic
      version_objs.each { |v| tmp << v.text if v.text =~ /\d+\.\d+\.\d+/ && Semver.satisfies(v.text, range) }
      pagelinks = html.xpath('//div[@class="pagination"]/a')
      return versions.concat(tmp) if pagelinks.empty?
      # with previous and next, always use the last one in array, which is next.
      # in the last page, there's only a 'previous' href, we should consider this.
      newlink = pagelinks[pagelinks.size - 1]['href'] if pagelinks[pagelinks.size - 1].text == 'Next'
      # if tmp is empty, no fit versions in this page. versions are
      # in descending order, so no fit versions in the next pages either.
      # but versions can't be empty at the same time, because the
      # above policy applies only after we have all the matches found.
      unless newlink.nil? || (tmp.empty? && !versions.empty?)
        versions.concat(tmp)
        fit_versions(newlink, range, versions)
      end
      versions
    end

    def fillup(bower_dependency, dest)
      url = bower_dependency.url
      dir = File.join(dest, bower_dependency.name)
      tarball = File.join(dest, File.basename(url))
      unless File.exist?(dir)
        IO.popen("wget -c #{bower_dependency.url} -O #{tarball}").close
        Dir.mkdir dir
        IO.popen("tar --warning=none --no-same-owner --no-same-permissions -xf #{tarball} -C #{dir} --strip-components=1").close
        IO.popen("rm -rf #{tarball}").close
      end
    end
  end
end
