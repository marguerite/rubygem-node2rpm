module Node2RPM
  class History
    def initialize(pkg)
      @json = Node2RPM::Download.new(pkg).get
    end

    def all
      @all = {}
      # can't use @json['time'] directly, eg is-extglob,
      # some versions there doesn't exist in @json['versions']
      @json['versions'].keys.each do |k|
        @all[k] = Time.parse(@json['time'][k])
      end
      @all.keys
    end

    def last
      all
      last = @all.values[0]
      @all.values.each do |v|
        last = v.utc if v.utc > last.utc
      end
      @all.key(last)
    end

    def has?(version)
      all
      @all.keys.include?(version) ? true : false
    end
  end
end
