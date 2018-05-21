# define dig for ruby < 2.3
class Hash
  def dig(*path)
    path.inject(self) do |location, key|
      location.is_a?(Hash) ? location[key] : nil
    end
  end
end

module Node2RPM
  # parse parents and write dependencies
  class Json
    attr_reader :parents, :json
    def initialize(pkg, ver, json)
      @pkg = pkg
      @ver = ver
      @json = json
      @struct = struct_new(@json)
      @parents = process_parents(@pkg, @ver)
      @path = path_new(@parents, @pkg)
    end

    def include?
      !@struct.reject! { |i| i.pkg =~ /^#{@pkg}(@\d+)?$/ && i.version == @ver }
              .nil?
    end

    def locate(pkg)
      @json.dig(*@path)[:dependencies][pkg]
    end

    def insert(pkg, hash)
      @json.dig(*@path)[:dependencies][pkg] = hash
      @json
    end

    def drop(pkg)
      @json.dig(*@path)[:dependencies].delete(pkg)
      @json
    end

    private

    def struct_new(json, struct = [])
      return unless json
      json.each do |k, v|
        depends = v[:dependencies].empty? ? nil : v[:dependencies].keys
        struct << OpenStruct.new(
          pkg: k, version: v[:version], parent: v[:parent],
          parentversion: v[:parentversion], dependencies: depends
        )
        struct_new(v[:dependencies], struct) unless depends.nil?
      end
      struct
    end

    def process_parents(pkg, ver, parents = [])
      @struct.each do |i|
        if i.pkg =~ /^#{pkg}(@\d+)?$/ && i.version == ver
          parents << i.parent
          process_parents(i.parent, i.parentversion, parents)
        end
      end
      parents.reverse
    end

    def path_new(parents, pkg)
      return if parents.empty?
      return [pkg] if parents.size == 1
      path = ''
      parents[1..-1].each { |i| path += ".#{i}.:dependencies" }
      path += '.' + pkg
      # without the first dot
      path[1..-1].split('.').map! do |i|
        i.start_with?(':') ? i[1..-1].to_sym : i
      end
    end
  end
end
