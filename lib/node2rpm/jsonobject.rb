require 'ostruct'

module Node2RPM
  class JSONObject
    def initialize(list)
      @list = list
    end

    def parse(list = @list, json = [])
      list.each do |k, v|
        obj = OpenStruct.new
        obj.name = k
        obj.version = v[:version]
        obj.parent = v[:parent]
        obj.parver = v[:parver]
        obj.dependencies = v[:dependencies].empty? ? nil : v[:dependencies].keys
        json << obj
        parse(v[:dependencies], json) unless obj.dependencies.nil?
      end
      json
    end

    def include?(pkg, version)
      json = parse
      json.each do |j|
        # the name@version should be considered as include.
        return true if j.name =~ /^#{pkg}(@\d.*)?$/ && j.version == version
      end
      false
    end
  end
end
