module NPKG
	class History
		def initialize(pkg)
			@json = NPKG::Download.get(pkg)
		end

		def all
			@all = @json['time'].delete_if do |k,v|
				/[0-9].*/.match(k).nil?
			end
		
			@all.each do |k,v|
				@all[k] = Time.parse(v)
			end

			return @all.keys
		end

		def last
			all

			last = @all.values[0]
			@all.values.each do |v|
				if v.utc > last.utc
					last = v.utc
				end
			end

			return @all.key(last)
		end

		def has?(version)
			all
			
			@all.keys.include?(version) ? true : false
		end
	end
end
