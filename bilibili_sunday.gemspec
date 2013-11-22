# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bilibili_sunday/version'

Gem::Specification.new do |spec|
  spec.name          = "bilibili_sunday"
  spec.version       = BilibiliSunday::VERSION
  spec.authors       = ["Jiahao Li"]
  spec.email         = ["isundaylee.reg@gmail.com"]
  spec.description   = %q{A Bilibili downloader! }
  spec.summary       = %q{A Bilibili downloader! }
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

  spec.add_dependency "aria2-ruby"
  spec.add_dependency "nokogiri"
  spec.add_dependency "xml-simple"
  spec.add_dependency "webrick"
end
