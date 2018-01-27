require 'json'
require 'fileutils'
require 'rpmspec'

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
      json ||= Dir.glob(@sourcedir + '/*.json')[0]
      # json still nil means no .json in sourcedir, the packager
      # chose the traditional way to package separated modules.
      @json = json.nil? ? nil : JSON.parse(open(json, 'r:UTF-8').read)
    end

    def prep
      puts "Checking .json's consistency"
      json_consist?(@sourcedir, @json, @specfile)
      recursive_untar(@sourcedir)
      puts "Finding and renaming files created under Windows"
      rename_windows_file
      puts "Checking bower_components' consistency"
      bower_consist?(@sourcedir, flatten_json(@json))
    end

    def mkdir
      if @json.nil?
        puts "Creating #{@dest_dir}/#{@pkg}"
        FileUtils.mkdir_p File.join(@dest_dir, @pkg)
      else
        recursive_mkdir(@json, @dest_dir)
      end

      return unless bower?
      make_bower_dirs(@sourcedir, @dest_dir, flatten_json(@json))
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
      copy_bower_files(@sourcedir, @dest_dir, flatten_json(@json))
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

    # recursively untar the tarballs in RPM sources directory
    def recursive_untar(dir)
      Dir.glob(dir + '/*.{tar.gz,tgz,bz2,xz}') do |tar|
        tarname = File.basename(tar, File.extname(tar))
        # if the dir contains only one file
        file_num = Dir.glob(dir + '/*').size
        puts "Untaring #{tar}"
        unpack(tar, dir, tarname)
        tardir = guess_tardir(tarname, tarname,
                              File.basename(dir), file_num)
        dest = post_process_tardir(tardir, tarname,
                                   dir, file_num)
        tars = Dir.glob(dest + '/**/*.{tar.gz,tgz,bz2,xz}')
        next if tars.empty?
        tars.each { |t| recursive_untar(File.split(t)[0]) }
      end
    end

    # unpack a tarball
    def unpack(tar, dir, tarname)
      tardir = File.join(dir, tarname)
      FileUtils.mkdir_p tardir
      cmd = 'tar -xf ' + tar + ' -C ' + tardir + ' --strip-components=1 ' \
            '--warning=none --no-same-owner --no-same-permissions'
      IO.popen(cmd).close
    end

    def correct_unpacked_tardir(dir)
      # bower.json is always downcased
      dir = dir.downcase if bower?
      # escape common suffix
      dir.gsub!(%r{^(.*?)(-(bower|dist))?(.*)$}, '\1\4')
    end

    def guess_tardir(unpacked, tarname, parent, num)
      unpacked = correct_unpacked_tardir(unpacked)
      guessed = guess(unpacked, tarname)
      if num == 1
        name = fullname(guessed, parent)
        guess(name, parent)
      else
        # the parent is non of our business
        guessed
      end
    end

    def guess(unpacked, tarname)
      # escape bower_components.tgz
      return unpacked if unpacked == tarname
      regex = %r{^(.*?)?-?v?(\d+[^/]+)$}
      u = unpacked.match(regex)
      t = tarname.match(regex)
      if u.nil?
        # unpacked has no version, then it must have a name
        if t.nil?
          raise unpacked + " doesn't have version"
        else
          return unpacked + '-' + t[2]
        end
      elsif u[1].nil?
        # unpacked has a version only
        if t.nil?
          return tarname + '-' + u[2]
        elsif t[1].nil?
          raise unpacked + " doesn't have name"
        else
          return t[1] + '-' + u[2]
        end
      else
        return unpacked
      end
    end

    # eonasdan-bootstrap-datetimepicker vs. bootstrap-datetimepicker
    def fullname(name, parent)
      regex = %r{^(.*?)-v?(\d+[^/]+)$}
      parent = Regexp.last_match(1) if parent =~ regex
      m = name.match(regex)
      if parent.index(m[1])
        parent + '-' + m[2]
      else
        name
      end
    end

    def post_process_tardir(tardir, unpacked, dir, num)
      dest = File.join(dir, tardir)
      source = File.join(dir, unpacked)
      unless File.exist?(dest) || source == dest
        puts "Renaming #{source} to #{dest}"
        FileUtils.mv source, dest
      end
      return dest unless num == 1
      path = File.split(dir)[0]
      new_dest = File.join(path, tardir)
      puts "Renaming #{source} to #{new_dest}"
      FileUtils.mv dest, new_dest + '.new'
      FileUtils.rm_rf dir
      FileUtils.mv new_dest + '.new', new_dest
      new_dest
    end

    # rename files created under windows with space in their filenames
    def rename_windows_file
      Dir.glob(@sourcedir + '/**/*') do |file|
        next unless File.basename(file).index(/\s+/)
        path = File.split(file)[0]
        puts "Renaming " + file
        FileUtils.mv file, path + File.basename(file).gsub(/\s+/, '_')
      end
    end

    # manual requires and its dependencies should be excluded
    # from the automatic dependency handling
    def manual_requires
      return if @specfile.requires.nil?
      m = {}
      @specfile.requires.each do |s|
        next unless s.name =~ /^npm\(/
        name = s.name.match(/^npm\((.*)\)$/)[1]
        version = s.version
        m[name] = version
      end
      return if m.empty?
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
      target = File.join(target_path, real_name).gsub(%r{-v?\d+[^/]+}, '')
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
        next unless File.directory?(file) && filename =~ %r{-v?\d+[^/]+$}
        unversioned = filename.match(%r{^(.*?)-v?\d+[^/]+$})[1]
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
