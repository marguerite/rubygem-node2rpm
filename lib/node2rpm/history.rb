module Node2RPM
  class History
    def initialize(pkg)
      json = Node2RPM::Registry.new(pkg).get
      # can't use json['time'] blindly, eg is-extglob,
      # some versions there don't exist in json['versions']
      @history = Hash[json['versions'].map { |k, v| [k, Time.parse(json['time'][k])] }]
      # sort_by time
      @history_sorted = Hash[@history.sort_by {|k,v| v}]
    end

    def versions
      @history.keys
    end

    def latest
      @history_sorted.keys[-1]
    end

    def include?(version)
      versions.include?(version)
    end
  end
end
