module Node2RPM
  class Server
    def flatten_json(json, flattened = {})
      json.each do |k, v|
        if flattened.key?(k)
          flattened[k] << v['version']
        else
          flattened[k] = [v['version']]
        end
        unless v['dependencies'].nil? || v['dependencies'].empty?
          flatten_json(v['dependencies'], flattened)
        end
      end
      flattened
    end

    def source_matrix(source)
      matrix = {}
      source.each do |i|
        m = i.match(%r{^(.*?)-v?(\d+[^/]+)$})
        if matrix.key?(m[1])
          matrix[m[1]] << m[2]
        else
          matrix[m[1]] = [m[2]]
        end
      end
      matrix
    end

    # check if the pkg version in json is the same as the specfile or the source
    def json_consist?(sourcedir, json, specfile)
      source = Dir.glob(sourcedir + '/*.{gz,tgz,bz2,xz}')
                  .map { |i| File.basename(i, File.extname(i)) }
                  .reject { |j| j == 'bower_components' }
      source = source_matrix(source)
      json = flatten_json(json)
      keys = []
      versions = {}
      json.each do |k, v|
        if source.key?(k)
          diff = v - source[k]
          if diff.empty?
            if k == specfile.name && !v.include?(specfile.version)
              puts "Failed: #{k}, #{specfile.version} in specfile"
              versions[k] = specfile.version
            else
              puts "Passed: #{k}"
            end
          else
            puts "Failed: #{k}, #{diff}"
            versions[k] = diff
          end
        else
          puts "Failed: #{k}"
          keys << k
        end
      end
      return if keys.empty? && versions.empty?
      raise "The following keys/versions were not found in the sources:\n" \
            "keys: #{keys}\nversions: #{versions}"
    end
  end
end
