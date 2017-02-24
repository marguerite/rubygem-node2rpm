module Node2RPM
  class Parent
    def initialize(pkg, version, list)
      @pkg = pkg
      @version = version
      @json = Node2RPM::JSONObject.new(list).parse
    end

    def parents(pkg = @pkg, version = @version, arr = [])
      @json.each do |j|
        if j.name == pkg && j.version == version
          arr << j.parent
          parents(j.parent, j.parentversion, arr)
        end
      end
      arr.reverse
    end

    def walk(str)
      arr = parents
      if arr.size > 1
        (1..(arr.size - 1)).each do |i|
          str << "[\"#{arr[i]}\"][:dependencies]"
        end
      end
      str << "[\"#{@pkg}\"][:dependencies]"
      str
    end
  end
end
