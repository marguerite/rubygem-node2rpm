require 'json'

module Node2RPM
  class Tool
    def self.drop_dependency(json)
      json = JSON.parse(open(json, 'r:UTF-8').read)
      p json
    end
  end
end

file = 'tryton-sao-3.8.13.json'

Node2RPM::Tool.drop_dependency(file)
