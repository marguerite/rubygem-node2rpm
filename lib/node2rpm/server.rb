require 'json'
require 'fileutils'

module Node2RPM
  class Server
    def initialize(json = nil)
      @sourcedir = Node2RPM::System.sourcedir
      @builddir = Node2RPM::System.builddir
      @buildroot = Node2RPM::System.buildroot
      @sitelib = Node2RPM::System.sitelib
      @dest_dir = File.join(@buildroot, @sitelib)
      @specfile = open(Dir.glob(@sourcedir + '/*.spec')[0], 'r:UTF-8').read
      @pkg = @specfile.match(/mod_name(\s|\t)+(.*?)\n/m)[2]
      json ||= Dir.glob(@sourcedir + '/*.json')[0]
      # json still nil means no .json in sourcedir, the packager
      # chose the traditional way to package separated modules.
      @json = json.nil? ? nil : JSON.parse(open(json, 'r:UTF-8').read)
    end

    def prep
      # unpack the tarballs
      Dir.glob(@sourcedir + '/*.tgz') do |tar|
        name = File.basename(tar, File.extname(tar))
        IO.popen("tar --warning=none --no-same-owner --no-same-permissions -xf #{tar} -C #{@sourcedir}").close
        FileUtils.mv File.join(@sourcedir, 'package'), File.join(@sourcedir, name)
      end

      # FIXME: bower
    end

    def mkdir
      if @json.nil?
        FileUtils.mkdir_p File.join(@dest_dir, @pkg)
      else
        recursive_mkdir(@json, @dest_dir)
      end
    end

    def copy
      Dir.glob(@dest_dir + '/**/*') do |dir|
        # 1. don't copy the bundled dependencies in tgz
        # 2. don't treat '@npmcorp' itself as a copy target
        next if dir.end_with?('node_modules') || File.basename(dir).start_with?('@')
        filename = if dir =~ %r{^.*(@[^/]+)/(.*$)}
                     Regexp.last_match(1) + '%2F' + Regexp.last_match(2)
                   else
                     File.basename(dir)
                   end
        recursive_copy(File.join(@sourcedir, filename), dir)
      end
      recursive_rename
      symlink
    end

    def build
      gyp_dir = find_gyp_dir
      gyp_dir.each do |dir|
        io = IO.popen("npm build #{dir}")
        io.each_line { |l| puts l }
        io.close
      end
    end

    def clean
      clean_source_files
      clean_empty_directories
    end

    def generate_filelist
      open(File.join(@builddir, @pkg + '.list'), 'w:UTF-8') do |f|
        Dir.glob(@buildroot + '/**/*') do |i|
          if File.directory?(i)
            next if f == File.join(@buildroot, '/usr') ||
                    File.join(@buildroot, '/usr/lib') ||
                    @dest_dir
            f.write "%dir\s" + i.gsub(@buildroot, '') + "\n"
          else
            f.write i.gsub(@buildroot, '') + "\n"
          end
        end
      end
    end

    private

    # manual requires and its dependencies should be excluded
    # from the automatic dependency handling
    def manual_requires
      require_lines = @specfile.scan(/^Requires:.*npm\(.*$/)
      return if require_lines.empty?
      m = {}
      require_lines.each do |i|
        r = i.match(/^Requires:.*npm\((.*)\)(.*\d+\..*)?$/)
        name = r[1]
        version = r[2]
        m[name] = version
      end
      m
    end

    def recursive_mkdir(json, workspace)
      json.each do |k, v|
        version = v['version']
        # versioned dir first, to avoid copy wrong files
        dest = File.join(workspace, k + '-' + version)
        unless !manual_requires.nil? && Node2RPM::Exclusion.new(manual_requires).exclude?(k, version)
          puts "Creating #{dest}"
          FileUtils.mkdir_p dest
        end
        next if v['dependencies'].empty?
        v['dependencies'].each do |m, n|
          newjson = { m => n }
          recursive_mkdir(newjson, File.join(dest, 'node_modules'))
        end
      end
    end

    def recursive_copy(source, dest)
      Dir.glob(source + '/*') do |file|
        file = file_filter(file)
        next if file.nil? || file.end_with?('node_modules')
        if File.directory?(file)
          dirname = File.basename(file)
          newdest = File.join(dest, dirname)
          puts "Making directory #{newdest}"
          FileUtils.mkdir_p newdest
          recursive_copy(file, newdest)
        else
          puts "Copying #{file} to #{dest}"
          FileUtils.cp_r file, dest
        end
      end
    end

    # drop the unneeded file
    def file_filter(file)
      arr = file.sub(@dest_dir, '').split('/').reject(&:empty?)[1..-1]
      r = /^\..*$ | .*~$ |
            \.(bat|orig|bak|sh|sln|njsproj|exe)$ |
            Makefile | example(s)?(\.js)? | benchmark(s)?(\.js)? |
            sample(s)?(\.js)? | test(s)?(\.js)? | _test\. |
            browser$ | windows | appveyor\.yml
          /x
      return unless arr.grep(r).empty?
      file
    end

    # rename versioned directory in buildroot to non-versioned
    def recursive_rename
      Dir.glob(@dest_dir + '/**/*').sort { |x| x.size }.each do |file|
        filename = File.basename(file)
        next unless File.directory?(file) && filename =~ /-\d+\.\d+/ # && file =~ /#{@dest_dir}/
        unversioned = filename.match(/(.*?)-\d+\.\d+.*/)[1]
        path = File.split(file)[0].sub(@dest_dir, '')
        puts "Renaming #{file} to #{File.join(@dest_dir + path, unversioned)}"
        FileUtils.mv file, File.join(@dest_dir + path, unversioned)
      end
    end

    def symlink(exclude = [])
      bindir = File.join(@buildroot, '/usr/bin')
      Dir.glob(@dest_dir + '/**/*') do |file|
        next unless binary?(file)
        filename = File.basename(file)
        next if exclude.include?(filename)
        FileUtils.mkdir_p bindir unless Dir.exist?(bindir)
        path = File.split(file)[0].sub(@buildroot, '')
        puts "Linking #{File.join(path, filename)} to #{File.join(bindir, filename)}"
        FileUtils.ln_sf File.join(path, filename), File.join(bindir, filename)
      end
    end

    def binary?(file)
      if (file.sub(@dest_dir, '') =~ %r{/bin/} || file.end_with?('.node')) \
          && File.file?(file) && File.executable?(file)
        true
      else
        false
      end
    end

    def find_gyp_dir
      gyp_dir = []
      Dir.glob(@dest_dir + '/**/*') do |file|
        next unless file.end_with?('.gyp')
        gyp_dir << File.split(file)[0]
      end
      gyp_dir
    end

    def clean_source_files
      Dir.glob(@dest_dir + '/**/{*,.*}') do |file|
        if File.basename(file) =~ /\.(c|h|cc|cpp|o|gyp|gypi)$
                    | Makefile$ | ^\..*$ /x
          puts "Cleaning #{file}"
          FileUtils.rm_rf file
        end

        if file =~ %r{build/Release/obj\.target}
          puts "Cleaning #{file}"
          FileUtils.rm_rf file
        end
        fix_permissions(file)
      end
    end

    def fix_permissions(file)
      return if file =~ %r{/bin/} || file.end_with?('.node') \
                || !(File.file?(file) && File.executable?(file))
      puts "Fixing permission #{file}"
      IO.popen("chmod -x #{file}").close
    end

    def clean_empty_directories
      Dir.glob(@dest_dir + '/**/{*,.*}')
         .select! { |d| File.directory?(d) }
         .select { |d| (Dir.entries(d) - %w(. ..)).empty? }
         .each do |d|
           puts "Dropping empty directory #{d}..."
           Dir.rmdir d
         end
    end
  end
end
