module Node2RPM
  class Parent
    def initialize(pkg, version, list)
      @pkg = pkg
      @version = version
      @json = Node2RPM::JSONObject.new(list).parse
    end

    def parents(pkg = @pkg, version = @version, arr = [])
      @json.each do |j|
        # .parents method are used to find parents for existing
        # pkg in json. name@version format should be treated the
        # same as name.
        if j.name =~ /^#{pkg}(@\d.*)?/ && j.version == version
          arr << j.parent
          parents(j.parent, j.parentversion, arr)
        end
      end
      arr.reverse
    end

    def walk(hash)
      arr = parents
      if arr.size > 1
        (1..(arr.size - 1)).each do |i|
          hash = hash[arr[i]][:dependencies]
        end
      end
      hash[@pkg][:dependencies]
    end
  end
end
