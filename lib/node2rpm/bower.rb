require 'json'
require 'ostruct'
require 'curb'
require 'nokogiri'
require 'node_semver'
require 'fileutils'

module Node2RPM
  # define an empty array and fill it up with nodejs modules that have
  # 'bower' as dependency
  class Bower
    def initialize(pkgs)
      @bower = pkgs
    end

    # use the bower array to create bower_components.tgz
    def prepare_components(pkgs)
      return if pkgs.empty?
      puts 'Creating bower_components...'
      Dir.mkdir 'bower_components'
      pkgs.each do |pkg|
        current_dir = File.expand_path('.')
        tarball = Dir.glob(current_dir + '/' + pkg[0] + '-' + pkg[1] + '.tgz')[0]
        dir = File.join(current_dir, File.basename(tarball, File.extname(tarball)))
        unless File.exist?(dir)
          puts "Creating #{dir}"
          Dir.mkdir dir
          puts "Unpacking #{tarball}..."
          IO.popen("tar --warning=none --no-same-owner --no-same-permissions -xf #{tarball} -C #{dir} --strip-components=1").close
        end
        bower_json = bower_dependencies(File.join(dir, 'bower.json'))
        dest = File.join('bower_components', pkg[0] + '-' + pkg[1])
        puts "Creating #{dest}"
        Dir.mkdir dest
        # bower components will be put under pkg namespace
        bower_structs(bower_json).each { |d| fillup(d, dest) }
      end
      # bower package also have bower.json that requires other bower packages.
      # we have to handle them too
      bower_find_internal_depends('bower_components')
      clean_ignore
      puts 'Compressing bower_components.tgz...'
      IO.popen('tar -cf bower_components.tgz bower_components').close
    end

    private

    def bower_structs(json)
      structs = []
      json.each do |k, v|
        s = OpenStruct.new
        s.name = k
        url = lookup(k)
        fits = fitted_versions(url + '/tags', v)
        s.version = NodeSemver.max_satisfying(fits, v)
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
      puts "Querying http://bower.herokuapp.com/packages/#{string}..."
      r = Curl::Easy.new('http://bower.herokuapp.com/packages/' + string)
      r.perform
      r.response_code != '404' ? JSON.parse(r.body_str)['url'].sub('.git', '') : nil
    end

    def fitted_versions(url, range, versions = [])
      html = Nokogiri::HTML(open(url))
      version_objs = html.xpath('//span[@class="tag-name"]')
      tmp = []
      # sometimes the tag is not numberic
      version_objs.each { |v| tmp << v.text if v.text =~ /\d+\.\d+\.\d+/ && NodeSemver.satisfies(v.text, range) }
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
        fitted_versions(newlink, range, versions)
      end
      versions
    end

    def fillup(bower_struct, dest)
      url = bower_struct.url
      dir = File.join(dest, bower_struct.name + '-' + bower_struct.version)
      tarball = File.join(dest, File.basename(url))
      unless File.exist?(dir)
        puts "Downloading #{bower_struct.url}..."
        IO.popen("wget -c #{bower_struct.url} -O #{tarball}").close
        Dir.mkdir dir
        puts "Unpacking #{tarball}..."
        IO.popen("tar --warning=none --no-same-owner --no-same-permissions -xf #{tarball} -C #{dir} --strip-components=1").close
        puts "Removing #{tarball}..."
        IO.popen("rm -rf #{tarball}").close
      end
    end

    def bower_find_internal_depends(dir)
      Dir.glob(dir + '/**/bower.json').each do |b|
        json = JSON.parse(open(b, 'r:UTF-8').read)
        next if json['dependencies'].nil? || json['dependencies'].empty?
        path = b.match(%r{^(.*?bower_components/.*?/)})[1]
        pkgs = Dir.glob(path + '/*').map {|i| File.basename(i)}
        pkgs = handle_pkgs(pkgs)
        # FIXME: what if the key match, but version don't
        depends = json['dependencies'].reject {|j| pkgs.key?(j) }
        next if depends.empty?
        bower_structs(depends).each do |d|
          fillup(d, path)
          bower_find_internal_depends(path + '/' + d)
        end
      end
    end

    def handle_pkgs(pkgs)
      h = {}
      pkgs.each do |i|
        next unless i =~ %r{^(.*?)-v?(\d+[^/]+)$}
        h[Regexp.last_match(1)] = Regexp.last_match(2)
      end
      h
    end

    def clean_ignore
      Dir.glob('bower_components/**/bower.json').each do |f|
        json = JSON.parse(open(f, 'r:UTF-8').read)
        dir = File.dirname(f)
        json['ignore'].each do |i|
          i = Regexp.last_match(1) if i =~ %r{^/(.*$)}
          Dir.glob(dir + '/' + i).each do |j|
            # avoid '.' and '..' being removed
            next if j.end_with?('.')
            puts "Cleaning #{j}"
            FileUtils.rm_rf j
          end
        end
      end
    end
  end
end
