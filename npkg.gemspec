# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'npkg/version'

Gem::Specification.new do |spec|
  spec.name          = "npkg"
  spec.version       = NPKG::VERSION
  spec.authors       = ["marguerite"]
  spec.email         = ["i@marguerite.su"]

  spec.summary       = %q{CLI tool for bundle packaging NodeJS modules in openSUSE}
  spec.description   = %q{openSUSE packages NodeJS modules and their dependencies in bundles to avoid maintenance headaches. The key is a json file that emulates the result of npm shrinkwrap (without actually install npm). This is the client that creates such json files on the packager's workstation. the server side is nodejs-packaging that runs only on openSUSE Build Service as a build time requirement.}
  spec.homepage      = "http://github.com/marguerite/npkg"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
	  spec.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "curb", ">= 0.9.0"
  spec.add_runtime_dependency "node-semver", "^1.0.0"
  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
