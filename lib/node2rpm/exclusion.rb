require 'node_semver'

module Node2RPM
  class Exclusion
    def initialize(pkgs)
      @pkgs = pkgs
    end

    def exclude?(pkg, version = nil)
      result = false
      unless @pkgs.nil?
        @pkgs.each do |k, v|
          if version.nil?
            if k == pkg
              result = true
              break
            end
          elsif k == pkg && NodeSemver.satisfies(version, v)
            result = true
            break
          end
        end
      end
      result
    end
  end
end
