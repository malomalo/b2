require File.expand_path("../lib/b2/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "b2"
  s.version     = B2::VERSION
  s.authors     = ["Jon Bracy"]
  s.email       = ["jonbracy@gmail.com"]
  s.homepage    = "https://github.com/malomalo/b2"
  s.summary     = %q{Backblaze B2 Client}
  s.description = %q{Backblaze B2 Client}
  s.licenses    = ['MIT']

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # Developoment 
  s.add_development_dependency 'rake'
end
