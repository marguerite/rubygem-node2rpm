module NPKG
	class JSONObject
		def initialize(list)
			@list = list
		end

		def parse(list=@list,json=[])
			jsonobject = Struct.new(:name,:version,:parent,:parentversion,:dependencies)

			list.each do |k,v|
				unless v[:dependencies].empty?
					json << jsonobject.new(k,v[:version],v[:parent],v[:parentversion],v[:dependencies].keys)
					parse(v[:dependencies],json)
				else
					json << jsonobject.new(k,v[:version],v[:parent],v[:parentversion],nil)
				end
			end

			return json
		end

		def has?(pkg,version)
			result = false
			json = parse
			json.each do |j|
				if j.name == pkg && j.version == version
					result = true
					break
				end
			end
			return result
		end
	end
end
