module NPKG
	class License
		def initialize(pkg,version)
			@json = NPKG::Download.get(pkg)
			@version = NPKG::History.new(pkg).has?(version) ? version : NPKG::History.new(pkg).last
		end

		def parse
			@json["versions"][@version]["license"]	
		end	
	end
end
