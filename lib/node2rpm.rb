dir = File.basename(__FILE__, File.extname(__FILE__))
path = File.join(File.dirname(File.expand_path(__FILE__)), dir)
Dir.glob(path + '/*').each do |i|
  require dir + '/' + File.basename(i) if File.basename(i).end_with?('.rb')
end

require 'curb'

module Node2RPM
  def self.generate(pkg, ver, exclude)
    Node2RPM::Tree.new(pkg, ver).generate(exclude)
  end

  def self.version(json)
    # return the node module's version
    json.values[0][:version]
  end

  def self.sources(json, source = [])
    sourceobj = Struct.new(:name, :version)

    json.each do |k, v|
      source << sourceobj.new(k, v[:version])
      v[:dependencies].empty? || sources(v[:dependencies], source)
    end

    source
  end

  def self.sourcedownload(sources, path = nil)
    path ||= './'
    sources.each do |s|
      url = REGISTRY + s.name + '/-/' + s.name + '-' + s.version + '.tgz'
      tarball = File.join(path, s.name + '-' + s.version + '.tgz')
      next if File.exist?(tarball)
      r = Curl::Easy.new(url)
      r.perform
      open(tarball, 'w') { |f| f.write r.body_str }
    end
  end

  def self.licenses(json, license = '')
    json.each do |k, v|
      if v[:license].nil?
        puts "Warning: #{k} has no license" \
             ', please confirm by visiting' \
              " https://www.npmjs.org/package/#{k}" \
             ' and add it later to the specfile.'
      else
        if v[:license] == 'BSD'
          puts "Warning: #{k}'s license is BSD" \
               ', please verify the clauses by visiting' \
                " https://www.npmjs.org/package/#{k}."
        end

        if license.empty?
          license << v[:license]
        else
          license.index(v[:license]) || license << "\sAND\s" + v[:license]
        end
        v[:dependencies].empty? || licenses(v[:dependencies], license)
      end
    end

    license
  end
end
