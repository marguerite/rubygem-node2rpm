module Node2RPM
  class JSONObject
    def initialize(list)
      @list = list
    end

    def parse(list = @list, json = [])
      jsonobject = Struct.new(:name,
                              :version,
                              :parent,
                              :parentversion,
                              :dependencies)
      list.each do |k, v|
        if v[:dependencies].empty?
          json << jsonobject.new(k,
                                 v[:version],
                                 v[:parent],
                                 v[:parentversion],
                                 nil)
        else
          json << jsonobject.new(k,
                                 v[:version],
                                 v[:parent],
                                 v[:parentversion],
                                 v[:dependencies].keys)
          parse(v[:dependencies], json)
        end
      end
      json
    end

    def include?(pkg, version)
      result = false
      json = parse
      json.each do |j|
        # the name@version should be considered as include.
        if j.name =~ /^#{pkg}(@\d.*)?$/ && j.version == version
          result = true
          break
        end
      end
      result
    end
  end
end
