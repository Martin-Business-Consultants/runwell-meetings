require_relative "lib/my_plugin/version"

# The gemspec's name is the plugin's key and its table prefix (bin/rename changes it).
Gem::Specification.new do |spec|
  spec.name = "my_plugin"
  spec.version = MyPlugin::VERSION
  spec.summary = "A Runwell plugin"
  spec.authors = [ "You" ]
  spec.homepage = "https://github.com/you/runwell-my-plugin"
  spec.license = "FSL-1.1-MIT"
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
