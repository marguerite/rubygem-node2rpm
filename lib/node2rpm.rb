dir = File.basename(__FILE__, File.extname(__FILE__))
path = File.join(File.dirname(File.expand_path(__FILE__)), dir)
Dir.glob(path + '/*').each do |i|
  next unless i.end_with?('.rb')
  require i.sub(File.split(path)[0] + '/', '').sub(/\.rb$/, '')
end

require 'ostruct'

module Node2RPM
  def self.generate(pkg, ver, exclude)
    Node2RPM::Tree.new(pkg, ver).generate(exclusion: exclude)
  end

  def self.version(json)
    # return the node module's version
    json.values[0][:version]
  end

  def self.sources(json, source = [])
    json.each do |k, v|
      s = OpenStruct.new
      s.url = if k =~ %r{^(@[^/%]+)/(.*)$}
                REGISTRY + k + '/-/' + Regexp.last_match(2) + '-' + \
                  v[:version] + '.tgz'
              elsif k =~ /(.*)@\d.*/
                # remove '@version' from name@version
                REGISTRY + Regexp.last_match(1) + \
                  '/-/' + Regexp.last_match(1) + '-' + v[:version] + '.tgz'
              else
                REGISTRY + k + '/-/' + k + '-' + v[:version] + '.tgz'
              end
      s.tarball = File.basename(s.url)
      source << s
      v[:dependencies].empty? || sources(v[:dependencies], source)
    end

    source
  end

  def self.sourcedownload(sources, path = nil)
    path ||= './'
    sources.each do |s|
      next if File.exist?(s.tarball)
      puts "Downloading #{s.tarball}"
      IO.popen("wget -c #{s.url} -O #{File.join(path, s.tarball)}").close
    end
  end

  def self.licenses(json)
    Node2RPM::Licenses.new(json).parse
  end
end
