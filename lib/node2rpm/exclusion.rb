require 'node_semver'

module Node2RPM
  class Exclusion
    def initialize(pkgs)
      @pkgs = pkgs
    end

    def exclude?(pkg, version = nil)
      return false if @pkgs.nil?
      @pkgs.each do |k, v|
        if version.nil?
          return true if k == pkg
        elsif k == pkg && NodeSemver.satisfies(version, v)
          return true
        end
      end
      false
    end
  end
end
