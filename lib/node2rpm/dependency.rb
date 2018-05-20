require 'node_semver'

module Node2RPM
  # recursively parse dependencies
  class Dependency
    def initialize(pkg, ver)
      @pkg = pkg
      @ver = ver
      @bower_pkg = {}
    end

    def dependencies
      process_dependency(@pkg, @ver, 'dependencies')
    end

    def get(**options)
      opt = fill_options(@pkg, @ver, options)
      d = process_dependency(opt.pkg, opt.version)
      Node2RPM::Logger.new("#{opt.pkg}'s dependencies: #{d}")
      l = Node2RPM::Attribute.new(opt.pkg, opt.version).license
      lam = lambda do |i|
        return opt.json if d.nil?
        d.each do |k, v|
          generate(**options_new(k, v, i, opt))
        end
      end

      if opt.json.empty?
        opt.json = json_default(opt, license)
	lam.call(opt.pkg)
      #elsif

      elsif Node2RPM::Exclusion.new(exclusion).without?(pkg, version)
	opt.json = Node2RPM::Json.new(opt.parent, opt.parentversion, opt.json)
		                 .insert(pkg, json_new(license, opt))
	lam.call(opt.pkg)
      end

      [opt.json, @bower_pkgs]
    end

    private

    def confident_version(pkg, ver)
      h = Node2RPM::History.new(pkg)
      if ver.nil?
        h.latest
      elsif h.include?(ver)
        ver
      else
        raise pkg + ': no such version ' + ver
      end
    end

    def fill_options(pkg, ver, opts)
      version = confident_version(pkg, ver)
      default = { pkg: pkg, version: version, exclusion: {},
                  parent: '_root', parentversion: '0.0.0', json: {} }
      OpenStruct.new(Hash[default.map do |k, v|
        [k, opts.key?(k) ? opts[k] : v]
      end])
    end

    def options_new(pkg, ver, parent, opt)
      { pkg: pkg, version: ver, exclusion: opt.exclusion,
        parent: parent, parentversion: opt.version,
        json: opt.json }
    end

    def json_default(opt, license)
      { "#{opt.pkg}": { version: opt.version,
		    parent: opt.parent,
		    parentversion: opt.parentversion,
		    license: license,
                    dependencies: {}}}
    end

    def json_new(license, opt)
      { version: opt.version, parent: opt.parent,
	parentversion: opt.parentversion,
	license: license,
	dependencies: {}}
    end

    def process_dependency(pkg, ver, type)
      registry = Node2RPM::Registry.new(pkg).get
      depends = registry['versions'][ver][type]
      if depends.nil?
        Node2RPM::Logger.new('No such dependency type: ' + type)
        return
      end
      return if depends.empty?
      d = apply_bower_filter(pkg, ver, depends)
      Hash[d.map { |k, v| [k, match_version(k, v)] }]
    end

    def apply_bower_filter(pkg, ver, dependencies)
      @bower_pkg[pkg] = ver if dependencies.key?('bower')
      dependencies.reject { |k, _v| k == 'bower' }
    end

    def match_version(pkg, ver)
      reg = Node2RPM::History.new(pkg).versions
      m = NodeSemver.max_satisfying(reg, ver)
      if m.nil?
        raise "#{pkg} has no matched version #{ver} from" \
      	      "range: #{reg}"
      end
      m
    end
  end
end
