module Node2RPM
	class License
		def initialize(pkg,version)
			@json = Node2RPM::Download.new(pkg).get
			@version = Node2RPM::History.new(pkg).has?(version) ? version : Node2RPM::History.new(pkg).last
		end

		def parse
			@json["versions"][@version]["license"]	
		end	
	end
end
