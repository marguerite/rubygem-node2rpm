require 'node2rpm/dependency.rb'
require 'node2rpm/description.rb'
require 'node2rpm/download.rb'
require 'node2rpm/exception.rb'
require 'node2rpm/exclusion.rb'
require 'node2rpm/history.rb'
require 'node2rpm/homepage.rb'
require 'node2rpm/jsonobject.rb'
require 'node2rpm/license.rb'
require 'node2rpm/parent.rb'
require 'node2rpm/tree.rb'
require 'node2rpm/version.rb'

module Node2RPM
	def self.generate(pkg,ver,exclude)
		Node2RPM::Tree.new(pkg,ver).generate(exclude)
	end

	def self.name(json)
		# return the node module's name
		json.keys[0]
	end

	def self.version(json)
		# return the node module's version
		json.values[0][:version]
	end

	def self.sources(json,source=[])
		sourceobj = Struct.new(:name,:version)

		json.each do |k,v|
			source << sourceobj.new(k,v[:version])
			unless v[:dependencies].empty?
				sources(v[:dependencies],source)
			end
		end

		return source
	end

	def self.sourcedownload(sources,path=nil)
		path ||= "./"
		sources.each do |s|
			url = REGISTRY + s.name + "/-/" + s.name + "-" + s.version + ".tgz"
			tarball = File.join(path,s.name + "-" + s.version + ".tgz")
			unless File.exist?(tarball)
				exec("wget #{url} -O #{tarball}")
			end
		end
	end

	def self.licenses(json,license="")
		json.each_with_index do |(k, v), i|
			if v[:license].nil?
				puts "Warning: #{k} has no license, please confirm by visiting https://www.npmjs.org/package/#{k} and add it later to the specfile."
			else
				if v[:license] == "BSD"
					puts "Warning: #{k}'s license is BSD, please verify the clauses by visiting https://www.npmjs.org/package/#{k}."
				end

				if license.empty?
					license << v[:license]
				else
					unless license.index(v[:license])
						license << "\sAND\s" + v[:license]
					end
				end	
				unless v[:dependencies].empty?
					licenses(v[:dependencies],license)
				end
			end
		end

		return license
	end
end
