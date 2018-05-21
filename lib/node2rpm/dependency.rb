require 'node_semver'

module Node2RPM
  # recursively parse dependencies
  class Dependency
    def initialize(pkg, ver)
      @pkg = pkg
      @ver = ver
      @bower_pkg = {}
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
        opt.json = json_default(opt, l)
	lam.call(opt.pkg)
      elsif Node2RPM::Json.new(opt.pkg, opt.version, opt.json).include?
        # This indicates we have at least two modules rely on the same
	# dependency. usually we keep the shortest path, so we put
	# this dependency under the same parent of those two modules:
        dedupe_parents, dedupe_opt = dedupe(opt)
	pkg = to_insert(dedupe_opt, opt)
	unless dedupe_parents || pkg
          opt.json = Node2RPM::Json.new(opt.parent, opt.parentversion, opt.json).drop(pkg)
	  opt.json = Node2RPM::Json.new(dedupe_opt.parent, dedupe_opt.version, opt.json).insert(pkg, json_new(l, dedupe_opt))
	  lam.call(pkg)
	end
      elsif Node2RPM::Exclusion.new(exclusion).without?(pkg, version)
	opt.json = Node2RPM::Json.new(opt.parent, opt.parentversion, opt.json)
		                 .insert(pkg, json_new(l, opt))
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

    def dedupe(opt)
      # old: the parents of the existing pkg in the tree
      # new: the parents of the parent of the pkg to be added
      #      since the pkg to be added hasn't been in the tree
      #      yet, thus no way to find parents
      old = Node2RPM::Json.new(opt.pkg, opt.version, opt.json).parents
      new = Node2RPM::Json.new(opt.parent, opt.parentversion, opt.json).parents << opt.parent
      # ["_root", "gulp", ..., "is-descriptor", "lazy-cache"]
      # ["_root", "gulp", ..., "collection-visit", "lazy-cache"]
      # the "lazy-cache" has to be stripped from the intersected path  
      # because it is also a multi-occured pkg that needs to be deduped later.
      # keeping it will lead to an invalid path.
      # [1,2,3,4,6,7] - [1,2,3,4,5,7,10] = [6]
      i = old.find_index((old - new)[1]) - 1
      d = old[0..i]
      return [nil, nil] if d.empty? || d == old
      parent = d[-1]
      version = parent_version(parent, opt.json)
      [d, OpenStruct.new(parent: parent, version: opt.version, parentversion: version)]
    end

    def parent_version(parents, json)
      path = intersperse(parents, :dependencies)
      json.dig(*path)[:version]
    end

    def intersperse(parents, sym)
      # ['_root', 'gulp', 'is-descriptor', 'lazy-cache']
      parents[1..-1].flat_map {|i| [i, sym] }.tap(&:pop)
    end

    def to_insert(dedupe_opt, opt)
      # delete old chain from tree
      json = Node2RPM::Json.new(dedupe_opt.parent, dedupe_opt.parentversion, opt.json).locate(opt.pkg)
      if json.nil?
	opt.pkg
      elsif json[:version] != opt.version
	opt.pkg + '@' + opt.version
      else
	nil
      end
    end
  end
end
