require 'node_semver'

module Node2RPM
  class Dependency
    def initialize(pkg, version)
      @pkg = pkg
      @json = Node2RPM::Registry.new(@pkg).get
      @version = if Node2RPM::History.new(@pkg).include?(version)
                   version
                 else
                   Node2RPM::History.new(@pkg).latest
                 end
    end

    def dependencies
      get_dependency('dependencies')
    end

    def dev_dependencies
      get_dependency('devDependencies')
    end

    private

    def get_dependency(type)
      arr = @json['versions'][@version][type]
      return if arr.nil? || arr.empty?
      arr.each do |k, v|
        range = Node2RPM::History.new(k).versions
        version = NodeSemver.max_satisfying(range, v)
        if version.nil?
          raise "#{@pkg}'s dependency #{k} " \
                "has nil-matched version! Raw version range: #{v}. " \
                "All available versions: #{range}. Usually it means " \
                "you need to clear your cache at /tmp/node2rpm." 
        end
        arr[k] = version
      end
      arr
    end
  end
end
