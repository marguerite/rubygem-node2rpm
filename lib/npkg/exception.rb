module NPKG
	class Exception < StandardError
		def initialize(str)
			puts str
		end
	end
end
