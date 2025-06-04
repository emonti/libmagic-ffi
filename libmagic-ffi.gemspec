
require 'pry'

Gem::Specification.new do |s|
    s.name          = "libmagic-ffi"
    s.version       = "1.0.0"
    s.summary       = "LibMagic FFI"
    s.description   = "LibMagic FFI bindings with some helper sugar"
    s.authors       = ["Eric Monti"]
    s.email         = "esmonti@gmail.com"
    s.files         = ["lib/libmagic.rb"]
    s.homepage      = "https://github.com/emonti/libmagic-ffi"
    s.metadata      = { "source_code_uri" => s.homepage }
    s.license       = "MIT"

    s.add_dependency 'ffi',   '~> 1.15'
    s.add_development_dependency 'minitest', '~> 5.25'
end

