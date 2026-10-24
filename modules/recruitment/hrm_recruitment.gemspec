Gem::Specification.new do |spec|
  spec.name = "hrm_recruitment"
  spec.version = "0.1.0"
  spec.authors = ["XinViec"]
  spec.summary = "XinViec HRM recruitment module"
  spec.required_ruby_version = ">= 3.4"
  spec.files = Dir.chdir(__dir__) { Dir.glob("{app,config,db,lib,test}/**/*").select { |file| File.file?(file) } }
  spec.require_paths = ["lib"]
  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "hrm_platform", "= 0.1.0"
end
