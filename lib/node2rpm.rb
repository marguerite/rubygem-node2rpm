dir = File.basename(__FILE__, File.extname(__FILE__))
path = File.join(File.dirname(File.expand_path(__FILE__)), dir)
Dir.glob(path + '/*').each do |i|
  require dir + '/' + File.basename(i) if File.basename(i).end_with?('.rb')
end

require 'curb'

module Node2RPM
  def self.generate(pkg, ver, exclude)
    Node2RPM::Tree.new(pkg, ver).generate(exclusion: exclude)
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
      name, url = if s.name =~ %r{^(@[^/%]+)/(.*)$}
                    # @npmcorp/copy uses a specfial url
                    [Regexp.last_match(1) + '%2F' + Regexp.last_match(2),
                     REGISTRY + s.name + '/-/' + Regexp.last_match(2) \
                     + '-' + s.version + '.tgz']
                  elsif s.name =~ /(.*)@\d.*/
                    # remove '@version' from name@version
                    [Regexp.last_match(1),
                     REGISTRY + Regexp.last_match(1) + '/-/' + \
                       Regexp.last_match(1) + '-' + s.version + '.tgz']
                  else
                    [s.name,
                     REGISTRY + s.name + '/-/' + s.name + '-' + s.version + '.tgz']
                  end
      tarball = File.join(path, name + '-' + s.version + '.tgz')
      next if File.exist?(tarball)
      puts "Downloading #{tarball}"
      r = Curl::Easy.new(url)
      r.perform
      open(tarball, 'w') { |f| f.write r.body_str }
    end
  end

  def self.licenses(json)
    Node2RPM::Licenses.new(json).parse
  end
end
