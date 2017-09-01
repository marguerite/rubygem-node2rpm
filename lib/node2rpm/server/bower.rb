require 'json'
require 'node_semver'

module Node2RPM
  # Handle bower stuff at server part
  class Server
    def find_component(dir)
      components = {}
      Dir.glob(dir + '/*') do |d|
        f = File.basename(d)
        m = f.match(%r{^(.*?)-v?(\d+[^/]+)$})
        if m.nil?
          components[f] = nil
        else
          components[m[1]] = m[2]
        end
      end
      components
    end

    def find_bower_components(dir, json)
      if old_hiearchy?(dir, json)
        find_component(dir)
      else
        components = {}
        Dir.glob(dir + '/*') do |d|
          components[File.basename(d)] = find_component(d)
        end
        components
      end
    end

    def old_hiearchy?(dir, json)
      pool = Dir.glob(dir + '/*').map! { |d| File.basename(d) }
      pool.each do |f|
        if f =~ %r{-v?\d+[^/]+$}
          key = f.sub!(Regexp.last_match(0), '')
          value = Regexp.last_match(0).sub!(/^-v?/, '')
          return false if json.key?(key) && json[key].include?(value)
        elsif json.key?(f)
          return false
        end
      end
      true
    end

    def bower_consist?(sourcedir, json)
      bowerdir = sourcedir + '/bower_components'
      components = find_bower_components(bowerdir, json)
      Dir.glob(bowerdir + '/**/bower.json') do |file|
        comp = if old_hiearchy?(bowerdir, json)
                 components
               else
                 components[file.match(%r{bower_components/([^/]+)})[1]]
               end
        js = JSON.parse(open(file, 'r:UTF-8').read)
        next if js['dependencies'].nil? || js['dependencies'].empty?
        keys = []
        versions = {}
        js['dependencies'].each do |k, v|
          if comp.keys.include?(k)
            versions[k] = [comp[k], v] unless comp[k].nil? || NodeSemver.satisfies(comp[k], v)
          else
            keys << k
          end
        end
        unless keys.empty? && versions.empty?
          puts "Mis-matched keys: #{keys}"
          puts "Mis-matched versions: #{versions}"
          raise "bower_components doesn't match with #{file}"
        end
      end
      puts 'Everything ok!'
      true
    end

    def make_bower_dirs(sourcedir, destdir, json)
      bowerdir = File.join(sourcedir, 'bower_components')
      if old_hiearchy?(bowerdir, json)
        pkg = File.basename(Dir.glob(destdir + '/*')[0])
        dest = destdir + '/' + pkg + '/bower_components'
        puts "Making directory #{dest}"
        Dir.mkdir dest
        Dir.glob(bowerdir + '/*') do |dir|
          dir = File.join(dest, File.basename(dir))
          puts "Making directory #{dir}"
          Dir.mkdir dir
        end
      else
        Dir.glob(bowerdir + '/*') do |dir|
          f = File.basename(dir)
          path = find_component_path(destdir, f)
          dest = File.join(path, 'bower_components')
          puts "Making directory #{dest}"
          Dir.mkdir dest
          Dir.glob(dir + '/*') do |d|
            d = File.join(dest, File.basename(d))
            puts "Making directory #{d}"
            Dir.mkdir d
          end
        end
      end
    end

    def find_component_path(dest, comp)
      Dir.glob(dest + '/**/*').select { |i| File.basename(i) == comp }[0]
    end

    def copy_bower_files(sourcedir, destdir, json)
      bowerdir = File.join(sourcedir, 'bower_components')
      if old_hiearchy?(bowerdir, json)
        pkg = File.basename(Dir.glob(destdir + '/*')[0])
        dest = destdir + '/' + pkg + '/bower_components'
        Dir.glob(bowerdir + '/*') do |dir|
          recursive_copy(dir, File.join(dest, File.basename(dir)))
        end
      else
        Dir.glob(bowerdir + '/*') do |dir|
          f = File.basename(dir)
          path = find_component_path(destdir, f) + '/bower_components'
          Dir.glob(dir + '/*') do |d|
            dest = File.join(path, File.basename(d))
            recursive_copy(d, dest)
          end
        end
      end
    end
  end
end
