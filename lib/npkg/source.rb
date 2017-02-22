module NPKG
	class Source
		def initialize(pkg,version)
			@pkg = pkg
			@version = NPKG::History.new(pkg).has?(version) ? version : NPKG::History.new(pkg).last
		end

		def parse
			REGISTRY + @pkg + "/-/" + @pkg + "-" + @version + ".tgz"
		end
	end
end
