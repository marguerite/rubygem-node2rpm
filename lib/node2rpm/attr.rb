module Node2RPM
  # return Attributes of a JSON object.
  # mainly we need the license and the upstream url.
  class Attr
    def initialize(pkg, ver)
      @pkg = pkg
      @ver = ver
      @json = Node2RPM::Registry.new(@pkg).get
      @history = Node2RPM::History.new(@pkg)
      @version = @history.include?(@ver) ? @ver : @history.last
      @resp = @json['versions'][@version]
    end

    def method_missing(tag)
      if !@resp[tag.to_s].nil?
        @resp[tag.to_s]
      elsif tag == :license
        licenses
      elsif tag == :homepage
        repository
      else
        super
      end
    end

    def respond_to_missing?(tag)
      !@resp[tag.to_s].nil? || [:license, :homepage].include?(tag) || super
    end

    def licenses
      license = @resp['licenses']
      return if license.nil?
      if license.instance_of?(Array)
        license[0]['type']
      elsif license.instance_of?(Hash)
        license['type']
      else
        raise "unimplemented license #{license}"
      end
    end

    def repository
      repo = @resp['repository']
      return if repo.nil?
      repo['url'].sub!('git://', 'https://')
    end
  end
end
