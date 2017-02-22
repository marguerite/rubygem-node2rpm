require 'node-semver'

module NPKG
	class Exclusion
		def initialize(pkgs)
			@pkgs = pkgs
		end

		def exclude?(pkg,version=nil)
			result = false
			@pkgs.each do |k,v|
				if version.nil?
					if k == pkg
						result = true
						break
					end
				else
					if k == pkg && Semver.satisfies(version,v)
						result = true
						break
					end
				end
			end
			return result
		end
	end
end
