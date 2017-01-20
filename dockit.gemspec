# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |s|
  s.name          = "dockit"
  s.version       = File.read("VERSION").chomp # file managed by version gem...
  s.authors       = ["Rick Frankel"]
  s.email         = ["dockit@cybercode.nyc"]

  s.summary       = %q{A configuration manager and builder for docker projects.}
  s.description   = %q{Dockit is a builder for complex docker projects. Think scriptable docker-composer.}
  s.homepage      = "https://github.com/cybercode/dockit"
  s.licenses      = ["MIT"]

  s.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  s.test_files    = `git ls-files -z -- spec/*`.split("\x0")
  s.bindir        = "bin"
  s.executables   = %w[dockit]
  s.require_paths = ["lib"]

  s.add_development_dependency "bundler"   , "~> 1.9"
  s.add_development_dependency "rake"      , "~> 10.4"
  s.add_development_dependency "rspec"     , "~> 3.2"
  s.add_development_dependency "simplecov" , "~> 0.10"
  s.add_development_dependency "pry"       , "~> 0.10"

  s.add_dependency "thor", "~> 0.19"
  s.add_dependency "dotenv", "~> 2.0"
  s.add_dependency "docker-api", "~> 1.21"
  s.add_dependency "version", "~> 1.0"
end
