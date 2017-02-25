module Node2RPM
  class Homepage
    def initialize(pkg, version)
      @json = Node2RPM::Download.new(pkg).get
      @version = if Node2RPM::History.new(pkg).include?(version)
                   version
                 else
                   Node2RPM::History.new(pkg).last
                 end
    end

    def parse
      @json['versions'][@version]['homepage']
    end
  end
end
