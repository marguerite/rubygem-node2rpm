module Node2RPM
  class Attribute
    def self.create(name)
      Object.const_set(name.capitalize,
                       Class.new do
                         define_method :parse do |pkg, ver|
                           json = Node2RPM::Download.new(pkg).get
                           version = if Node2RPM::History.new(pkg).include?(ver)
                                       ver
                                     else
                                       Node2RPM::History.new(pkg).last
                                     end
                           json['versions'][version][name]
                         end
                       end)
    end
  end
end
