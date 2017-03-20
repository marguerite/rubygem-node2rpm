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
                           if json['versions'][version][name].nil?
                             case name
                             when 'license'
                               fallback = json['versions'][version]['licenses']
                               fallback.nil? ? nil : fallback[0]['type']
                             when 'homepage'
                               fallback = json['versions'][version]['repository']
                               fallback.nil? ? nil : fallback['url'].sub('git://', 'https://')
                             end
                           else
                             json['versions'][version][name]
                           end
                         end
                       end)
    end
  end
end
