Gem::Specification.new do |s|
  s.name                    = "nailed"
  s.version                 = "0.0.1"
  s.date                    = Time.now.strftime("%Y-%m-%d")
  s.summary                 = "Nailed CLI and WebUI"
  s.description             = "Collect and visualize OpenStack SUSE Cloud and Crowbar related data from Bugzilla and Github"
  s.authors                 = ["Maximilian Meister"]
  s.email                   = "mmeister@suse.de"
  s.files                   = `git ls-files`.split("\n")
  s.executables             = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.bindir                  = "bin"
  s.require_paths           = ["lib"]
  s.homepage                = "http://github.com/MaximilianMeister/nailed"
  s.license                 = "MIT"
  s.add_dependency("octokit", ["3.7.0"])
  s.add_dependency("trollop", ["2.0"])
  s.add_dependency("bicho", ["0.0.8"])
  s.add_dependency("data_mapper", ["1.2.0"])
  s.add_dependency("dm-sqlite-adapter", ["1.2.0"])
  s.add_dependency("netrc", ["0.10.2"])
end
