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
      # File.join(@root, 'BUILD')
      File.expand_path('~/tryton-sao')
    end

    def self.sourcedir
      # Node2RPM::System.new.sourcedir
      File.expand_path('~/tryton-sao')
    end

    def sourcedir
      File.join(@root, 'SOURCES')
    end

    def self.buildroot
      # Node2RPM::System.new.buildroot
      File.expand_path('~/tryton-sao')
    end

    def buildroot
      Dir.glob(@root + '/BUILDROOT/*')[0]
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
  end
end
