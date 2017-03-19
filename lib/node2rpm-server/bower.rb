module Node2RPM
  class Bower
    def initialize
      @sourcedir = Node2PRM::System.sourcedir
      @buildroot = Node2RPM::System.buildroot
      @sitelib = Node2RPM::System.sitelib
      @dest_dir = File.join(@buildroot, @sitelib)
      @bower_dir = File.join(@sourcedir, 'bower_components')
      @tarball = @bower_dir + '.tgz'
    end

    def bower?
      File.exist?(@tarball)
    end

    def prep
      IO.popen("tar -xf #{@tarball} -C #{@sourcedir}").close
    end

    def mkdir
      Dir.glob(@bower_dir + '/*') do |dir|
        dest = Dir.glob(@dest_dir + '/**/' + dir)[0]
        puts "Making #{File.join(dest, 'bower_components')}"
        Dir.mkdir File.join(dest, 'bower_components')
      end
    end

    def copy; end

    private
  end
end
