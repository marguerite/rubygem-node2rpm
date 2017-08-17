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
      @specfile = RPMSpec::Parser.new(Dir.glob(@sourcedir + '/*.spec')[0]).parse
      @pkg = @specfile.name + '-' + @specfile.version
      @bower_dir = if File.exist?(@sourcedir + '/bower_components/' + @pkg)
                     @sourcedir + '/bower_components/' + @pkg
                   else
                     @sourcedir + '/bower_components'
                   end
      @bower_dest = if File.exist?(@dest_dir + '/' + @pkg +
                                   '/bower_components/' + @pkg)
                      @dest_dir + '/' + @pkg + '/bower_components/' + @pkg
                    else
                      @dest_dir + '/' + @pkg + '/bower_components'
                    end
      json ||= Dir.glob(@sourcedir + '/*.json')[0]
      # json still nil means no .json in sourcedir, the packager
      # chose the traditional way to package separated modules.
      @json = json.nil? ? nil : JSON.parse(open(json, 'r:UTF-8').read)
    end

    def prep
      # unpack the tarballs
      Dir.glob(@sourcedir + '/*.*[z,2]') do |tar|
        name = File.basename(tar, File.extname(tar))
        puts "Unpacking #{tar}"
        IO.popen("tar --warning=none --no-same-owner --no-same-permissions -xf #{tar} -C #{@sourcedir}").close
        source = File.join(@sourcedir, 'package')
        dest = File.join(@sourcedir, name)
        FileUtils.mv source, dest if File.exist?(source)
      end
    end

    def mkdir
      if @json.nil?
        puts "Creating #{@dest_dir}/#{@pkg}"
        FileUtils.mkdir_p File.join(@dest_dir, @pkg)
      else
        recursive_mkdir(@json, @dest_dir)
      end

      return unless bower?
      puts "Creating #{@bower_dest}"
      FileUtils.mkdir_p @bower_dest
      Dir.glob(@bower_dir + '/*') do |dir|
        puts "Creating #{@bower_dest}/#{File.basename(dir)}"
        Dir.mkdir File.join(@bower_dest, File.basename(dir))
      end
    end

    def copy
      Dir.glob(@dest_dir + '/**/*') do |dir|
        # 1. don't copy the bundled dependencies in tgz
        # 2. don't copy bower_components
        # 3. don't treat '@npmcorp' itself as a copy target
        next if dir =~ /(node_modules|bower_components)$/ || File.basename(dir).start_with?('@')
        filename = if dir =~ %r{^.*@[^/]+/(.*$)} && !Regexp.last_match(1).index('node_modules')
                     Regexp.last_match(1)
                   elsif dir =~ /(^.*)@[^-]+(-\d.*$)/
                     File.basename(Regexp.last_match(1) + Regexp.last_match(2))
                   else
                     File.basename(dir)
                   end
        recursive_copy(File.join(@sourcedir, filename), dir)
      end
      Dir.glob(@bower_dir + '/*') do |dir|
        dest = File.join(@bower_dest, File.basename(dir))
        recursive_copy(dir, dest)
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

    def filelist
      puts "Writing files list to #{File.join(@builddir, @pkg + '.list')}"
      open(File.join(@builddir, @pkg + '.list'), 'w:UTF-8') do |f|
        Dir.glob(@buildroot + '/**/*') do |i|
          if File.directory?(i)
            next if [File.join(@buildroot, '/usr'),
                     File.join(@buildroot, '/usr/lib'),
                     @dest_dir].include?(i)
            puts "Writing directory #{i.sub!(@buildroot, '')}"
            f.write "%dir\s" + i + "\n"
          else
            puts "Writing file #{i.sub!(@buildroot, '')}"
            f.write i + "\n"
          end
        end
      end
    end

    private

    # manual requires and its dependencies should be excluded
    # from the automatic dependency handling
    def manual_requires
      return if @specfile.requires.nil?
      m = {}
      @specfile.requires.each do |s|
        name = s.name.match(/^npm\((.*)\)$/)[1]
        version = s.version
        m[name] = version
      end
      m
    end

    # recursively create directories based on the json node2rpm produced
    def recursive_mkdir(json, workspace)
      json.each do |k, v|
        version = v['version']
        # use versioned dir to avoid copy wrong files
        dest = File.join(workspace, k + '-' + version)
        unless !manual_requires.nil? && Node2RPM::Exclusion.new(manual_requires).exclude?(k, version)
          puts "Creating #{dest}"
          FileUtils.mkdir_p dest
        end
        next if v['dependencies'].nil? || v['dependencies'].empty?
        v['dependencies'].each do |m, n|
          newjson = { m => n }
          recursive_mkdir(newjson, File.join(dest, 'node_modules'))
        end
      end
    end

    # recursively copy files from sourcedir to buildroot
    def recursive_copy(source, dest)
      Dir.glob(source + '/*') do |file|
        file = file_filter(file)
        next if file.nil? || file.end_with?('node_modules')
        if File.directory?(file)
          dirname = File.basename(file)
          newdest = File.join(dest, dirname)
          puts "Making directory #{newdest}"
          Dir.mkdir newdest
          recursive_copy(file, newdest)
        else
          copy_file(file, dest)
        end
      end
    end

    # copy file or symlink to buildroot
    def copy_file(file, dest)
      if File.symlink?(file)
        real_symlink(file, dest)
      else
        puts "Copying #{file} to #{dest}"
        FileUtils.cp_r file, dest
      end
    end

    # recreate a symlink from the location of the real file to be installed
    # eg, the given link is "@sourcedir + '/example-1.0.0/bin/example'"
    #     the real file behind is "@sourcedir + '/example-1.0.0/lib/example.js'"
    #     the target is "@dest_dir + '/a-1.0.0/node_modules/.../example-1.0.0/bin/example'"
    # we need to create a symlink from the install location of the real file,
    # to the target
    def real_symlink(link, dest)
      real_file = File.expand_path(File.split(link)[0] + '/' + File.readlink(link))
      real_name = File.basename(real_file)
      dest_name = File.basename(link)
      target_path = File.split(File.expand_path(dest + '/' + File.readlink(link)))[0].sub(@buildroot, '')
      target = File.join(target_path, real_name).gsub(%r{-(v)?\d+[^/]+}, '')
      puts "Creating symlink from #{target} to #{File.join(dest, dest_name)}"
      FileUtils.ln_sf target, File.join(dest, dest_name)
    end

    # drop the unneeded file
    def file_filter(file)
      arr = file.sub(@dest_dir, '').split('/').reject(&:empty?)[1..-1]
      r = /^\..*$ | .*~$ |
            \.(bat|cmd|orig|bak|sh|sln|njsproj|exe)$ |
            Makefile | example(s)?(\.js)?$ | benchmark(s)?(\.js)?$ |
            sample(s)?(\.js)?$ | test(s)?(\.js)?$ | _test\. |
            browser$ | coverage | windows | appveyor\.yml
          /x
      return unless arr.grep(r).empty?
      file
    end

    # rename versioned directory in buildroot to non-versioned
    def recursive_rename
      Dir.glob(@dest_dir + '/**/*').sort { |x| x.size }.each do |file|
        filename = File.basename(file)
        next unless File.directory?(file) && filename =~ /-(v)?\d+\.\d+/
        unversioned = filename.match(/(.*?)-(v)?\d+\.\d+.*/)[1]
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
        next if exclude.include?(filename) || file.index('bower_components') || file.end_with?('.js')
        FileUtils.mkdir_p bindir unless Dir.exist?(bindir)
        path = File.split(file)[0].sub(@buildroot, '')
        puts "Linking #{File.join(path, filename)} to #{File.join(bindir, filename)}"
        FileUtils.ln_sf File.join(path, filename), File.join(bindir, filename)
      end
    end

    def binary?(file)
      (file.sub(@dest_dir, '') =~ %r{/bin/} || file.end_with?('.node')) \
          && File.file?(file) && File.executable?(file)
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
         .select { |d| (Dir.entries(d) - %w[. ..]).empty? }
         .each do |d|
           puts "Dropping empty directory #{d}..."
           Dir.rmdir d
         end
    end

    def bower?
      Dir.glob(@sourcedir + '/bower_components.*').map! { |d| File.exist?(d) }.include?(true)
    end
  end
end
