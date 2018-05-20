module Node2RPM
  class Tree
    def initialize(pkg, version)
      @pkg = pkg
      @version = if Node2RPM::History.new(@pkg).include?(version)
                   version
                 else
                   Node2RPM::History.new(@pkg).latest
                 end
    end

    def generate(options)
      # extract options hash
      parent = options.fetch(:parent, '_root')
      parver = options.fetch(:parver, '0.0.0')
      exclusion = options.fetch(:exclusion, {})
      pkg = options.fetch(:pkg, @pkg)
      version = options.fetch(:version, @version)
      mega = options.fetch(:mega, {})
      Node2RPM::Logger.new("processing #{pkg},#{version},#{parent},#{parver}")

      dependencies = Node2RPM::Dependency.new(pkg, version).dependencies
      Node2RPM::Logger.new("dependencies of #{pkg}-#{version}: #{dependencies}")
      license = Node2RPM::Attr.new(pkg, version).license
      Node2RPM::Logger.new("license of #{pkg}: #{license}")

      deps = lambda do |pv|
        unless dependencies.nil?
          dependencies.each do |k, v|
            generate(pkg: k, version: v, exclusion: exclusion,
                     parent: pv, parver: version, mega: mega)
          end
        end
        return mega
      end

      if mega.empty?
        mega[pkg] = { version: version, parent: parent, parver: parver,
                      license: license, dependencies: {} }
	deps.call(pkg)
      elsif Node2RPM::Json.new(pkg, version, mega).include?
        # This indicates we have at least two modules rely on the same
        # dependency. usually we keep the shortest path, so we put
        # this dependency under the same parent of those two modules:
        # par_old finds the location of the existing one;
        # par_new uses the location of the parent of the pkg to be inserted,
        # because the new pkg hasn't been inserted, no way to use itself.
        par_old = Node2RPM::Json.new(pkg, version, mega).parents
        par_new = Node2RPM::Json.new(parent, parver, mega).parents
        par_new << parent # form parents for the same pkg
        intersected = intersect(par_old, par_new)

        oldpar = par_old[-1]
        newpar = intersected[-1]
        oldparver = get_version(par_old, mega)
        newparver = get_version(intersected, mega)

        # we need to insert the new one and delete the old one.
        # unless: 1. already been processed and moved.
        #         2. no need to move at all
        unless intersected.empty? || intersected == par_old
          Node2RPM::Logger.new("moving from #{par_old} to #{intersected}")
          Node2RPM::Json.new(oldpar, oldparver, mega).drop(pkg)

          if Node2RPM::Json.new(newpar, newparver, mega).nested[pkg].nil?
            to_add = pkg
          elsif Node2RPM::Json.new(newpar, newparver, mega).nested[pkg][:version] != version
            to_add = pkg + '@' + version
          end

          unless to_add.nil?
            mega = Node2RPM::Json.new(newpar, newparver, mega)
                                 .insert(to_add, version: version, parent: newpar,
                                                 parver: newparver, license: license,
                                                 dependencies: {})
            deps.call(to_add)
          end
        end
      elsif !Node2RPM::Exclusion.new(exclusion).exclude?(pkg, version)
        # occur the first time, so apply exclusion here.
        # we need to escape for some dependencies to allow package split.
        mega = Node2RPM::Json.new(parent, parver, mega)
                             .insert(pkg, version: version, parent: parent, parver: parver,
                                          license: license, dependencies: {})
        deps.call(pkg)
      end
      [mega, []]
    end

    private

    def get_version(arr, hash)
      return if arr.size <= 1
      (1..arr.size - 1).each do |i|
        next if i == arr.size - 1
        hash = hash[arr[i]][:dependencies]
      end
      hash[arr[-1]][:version]
    end

    def intersect(arr1, arr2)
      # ["_root", "gulp", ..., "is-descriptor", "lazy-cache"]
      # ["_root", "gulp", ..., "collection-visit", "lazy-cache"]
      # we need to stip "lazy-cache" from the intersected array.
      # because it is also a multi-occured pkg that needs to process later.
      # keeping it will lead to an invalid walk path.
      long = []
      short = []

      if arr1.size - arr2.size >= 0
        long = arr1.reverse
        short = arr2.reverse
      else
        long = arr2.reverse
        short = arr1.reverse
      end

      count = 0
      (0..(long.size - 1)).each do |i|
        # break if the short array reachs its end
        # or meet the first unmatch
        break if short[i].nil? || long[i] != short[i]
        count += 1 if long[i] == short[i]
      end

      count > 0 ? (arr1 & arr2)[0..(-1 * count - 1)] : arr1 & arr2
    end
  end
end
