module Node2RPM
  class Bower
    def bower?
      File.exist?(File.join(Node2RPM::System.sourcedir, 'bower_components.tgz'))
    end

    def prep
      sourcedir = Node2RPM::System.sourcedir
      tarball = File.join(sourcedir, 'bower_components.tgz')
      IO.popen("tar -xf #{tarball} -C #{sourcedir}").close
    end

    def copy; end

    private
  end
end
