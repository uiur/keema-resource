# frozen_string_literal: true

require_relative "lib/keema/resource"

Gem::Specification.new do |spec|
  spec.name = "keema-resource"
  spec.version = Keema::Resource::VERSION
  spec.authors = ["Kazato Sugimoto"]
  spec.email = ["uiureo@gmail.com"]

  spec.summary = "keema-resource"
  spec.description = "keema-resource"
  spec.homepage = "https://github.com/uiur/keema-resource"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/uiur/keema-resource"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'standard', '~> 1.3'
  spec.add_development_dependency 'yard', '~> 0.9.0'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
