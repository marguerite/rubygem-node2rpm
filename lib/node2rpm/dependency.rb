require 'node-semver'

module Node2RPM
  class Dependency
    def initialize(pkg, version)
      @json = Node2RPM::Download.new(pkg).get
      @version = if Node2RPM::History.new(pkg).include?(version)
                   version
                 else
                   Node2RPM::History.new(pkg).last
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
        versions = Node2RPM::History.new(k).all
        arr[k] = Semver.max_satisfying(versions, v)
      end
      arr
    end
  end
end
