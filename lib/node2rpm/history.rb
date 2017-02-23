module Node2RPM
	class History
		def initialize(pkg)
			@json = Node2RPM::Download.new(pkg).get
		end

		def all
			@all = Hash.new

			# can't use @json['time'] directly, eg is-extglob,
			# some versions there doesn't exist in @json['versions']
			@json['versions'].keys.each do |k|
				@all[k] = Time.parse(@json['time'][k])
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
