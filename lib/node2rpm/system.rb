require 'rpmspec'

module Node2RPM
  class System
    def initialize
      systemroot = '/usr/src/packages'.freeze
      @root = File.writable?(systemroot) ? systemroot : File.expand_path(File.join('~', 'rpmbuild'))
    end

    def self.builddir
      Node2RPM::System.new.builddir
    end

    def builddir
      File.join(@root, 'BUILD')
    end

    def self.sourcedir
      Node2RPM::System.new.sourcedir
    end

    def sourcedir
      File.join(@root, 'SOURCES')
    end

    def self.buildroot
      Node2RPM::System.new.buildroot
    end

    def buildroot
      # we need to create it ourselves
      specfile = RPMSpec::Parser.new(Dir.glob(sourcedir + '/*.spec')[0]).parse
      buildroot = @root + '/BUILDROOT/' + specfile.name + '-' + \
                  specfile.version + '-' + specfile.release + '.' + arch
      Dir.mkdir buildroot unless File.exist? buildroot
      buildroot
    end

    def self.sitelib
      '/usr/lib/node_modules'.freeze
    end

    def self.sitearch
      if RbConfig::CONFIG['sitearch'] =~ /64/
        '/usr/lib64/node_modules'.freeze
      else
        sitelib
      end
    end

    def arch
      # this is really ugly
      io = IO.popen('rpm -qa filesystem')
      arch = io.readline.match(/.*\.(.*)\n/)[1]
      io.close
      arch
    end
  end
end
