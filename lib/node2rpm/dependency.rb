require 'node-semver'

module Node2RPM
  class Dependency
    def initialize(pkg, version)
      @json = Node2RPM::Download.new(pkg).get
      @version = if Node2RPM::History.new(pkg).has?(version)
                   version
                 else
                   Node2RPM::History.new(pkg).last
                 end
    end

    def dependencies
      dependencies = @json['versions'][@version]['dependencies']
      return if dependencies.nil? || dependencies.empty?
      dependencies.each do |k, v|
        versions = Node2RPM::History.new(k).all
        dependencies[k] = Semver.max_satisfying(versions, v)
      end
      dependencies
    end

    def dev_dependencies
      dev_dependencies = @json['versions'][@version]['devDependencies']
      return if dev_dependencies.nil? || dev_dependencies.empty?
      dev_dependencies.each do |k, v|
        versions = Node2RPM::History.new(k).all
        dev_dependencies[k] = Semver.max_satisfying(versions, v)
      end
      dev_dependencies
    end
  end
end
