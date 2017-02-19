require 'node-semver'

module NPKG
	class Dependency
		def initialize(pkg,version=nil)
			@json = NPKG::Download.get(pkg)
			@version = NPKG::History.new(pkg).has?(version) ? version : NPKG::History.new(pkg).last
		end

		def dependencies
			dependencies = @json["versions"][@version]["dependencies"]
			unless dependencies.nil? || dependencies.empty?
				dependencies.each do |k,v|
					versions = NPKG::History.new(k).all
					p k,versions,v
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
					versions = NPKG::History.new(k).all
					devDependencies[k] = Semver.maxSatisfying(versions,v)
				end
				devDependencies
			else
				nil
			end
		end
	end
end

require './version.rb'
require './download.rb'
require './history.rb'

#NPKG::Dependency.new("glob-stream").dependencies
