# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dockit/version'

Gem::Specification.new do |spec|
  spec.name          = "dockit"
  spec.version       = Dockit::VERSION
  spec.authors       = ["Rick Frankel"]
  spec.email         = ["dockitk@rickster.com"]

  spec.summary       = %q{A configuration manager and builder for docker projects.}
  # spec.description   = %q{Dockit is a builder for complex docker projects. Think scriptable docker-composer.}
  spec.homepage      = "TODO: Put your gem's website or public repo URL here."

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = %w[bin/dockit]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "pry"

  spec.add_dependency "thor", ">= 0.19"
  spec.add_dependency "dotenv", ">= 2.0"
  spec.add_dependency "docker-api", ">= 1.21.4"
end
