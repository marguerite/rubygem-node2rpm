require 'node-semver'

module Node2RPM
	class Dependency
		def initialize(pkg,version)
			@json = Node2RPM::Download.get(pkg)
			@version = Node2RPM::History.new(pkg).has?(version) ? version : Node2RPM::History.new(pkg).last
		end

		def dependencies
			dependencies = @json["versions"][@version]["dependencies"]
			unless dependencies.nil? || dependencies.empty?
				dependencies.each do |k,v|
					versions = Node2RPM::History.new(k).all
					dependencies[k] = Semver.maxSatisfying(versions,v)
				end
				dependencies
			else
				nil
			end
		end

		def devDependencies
			devDependencies = @json["versions"][@version]["devDependencies"]
			unless devDependencies.nil? || devDependencies.empty?
				devDependencies.each do |k,v|
					versions = Node2RPM::History.new(k).all
					devDependencies[k] = Semver.maxSatisfying(versions,v)
				end
				devDependencies
			else
				nil
			end
		end
	end
end
