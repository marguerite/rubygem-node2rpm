require 'curb'
require 'open-uri'
require 'json'

module NPKG
	class Download
		def initialize(pkg)
			@url = REGISTRY + pkg
			@uri = URI.parse(@url)
			@filename = File.join("/tmp",/.*\/(.*)/.match(@uri.path)[1])
		end

		def self.get(pkg)
			# if the json file exists, then return the json
			# else download the json file and return the json
			# @param [String]
			# @return [Hash]
			NPKG::Download.new(pkg).get
		end

		def get
			if File.exists?(@filename)
				open(@filename,'r:UTF-8') do |f|
					json = JSON.parse!(f.read)
					return json
				end
			else
				if exist?
					r = Curl::Easy.new(@url)
					r.perform
					json = JSON.parse!(r.body_str)
					open(@filename,'w:UTF-8') {|f| f.write JSON.pretty_generate(json)}
					return json
				else
					raise NPKG::Exception.new("No such node module. please check your spelling.")
				end
			end
		end

		def exist?
			r = Curl::Easy.new(@url)
			r.perform
			if r.response_code == 404
				false
			else
				true
			end
		end
	end
end
