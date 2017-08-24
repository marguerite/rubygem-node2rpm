# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'node2rpm/version'

Gem::Specification.new do |spec|
  spec.name          = "node2rpm"
  spec.version       = Node2RPM::VERSION
  spec.authors       = ["marguerite"]
  spec.email         = ["i@marguerite.su"]

  spec.summary       = %q{Command line tool for packaging a node module and their dependencies into RPM as bundle}
  spec.description   = %q{Node2RPM packages a node module and its dependencies into RPM as bundle to avoid maintenance headaches.}
  spec.homepage      = "http://github.com/marguerite/rubygem-node2rpm"
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

  spec.add_runtime_dependency 'curb', '~> 0.9'
  spec.add_runtime_dependency 'node_semver', '~>1.0'
  spec.add_runtime_dependency 'rpmspec', '~>1.0'
  spec.add_runtime_dependency 'nokogiri', '~>1.6'
  spec.add_development_dependency 'bundler', '~> 1.13'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end
