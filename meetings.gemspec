require_relative "lib/meetings/version"

# The gemspec's name is the plugin's key and its table prefix (bin/rename changes it).
Gem::Specification.new do |spec|
  spec.name = "meetings"
  spec.version = Meetings::VERSION
  spec.summary = "Meetings with agendas, daily priorities and end-of-day reports for Runwell"
  spec.authors = [ "Runwell" ]
  spec.homepage = "https://github.com/Martin-Business-Consultants/runwell-meetings"
  spec.license = "FSL-1.1-MIT"
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
