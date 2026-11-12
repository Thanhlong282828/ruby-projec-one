Gem::Specification.new do |spec|
  spec.name = "hrm_payroll"
  spec.version = "0.1.0"
  spec.authors = [ "XinViec" ]
  spec.summary = "XinViec HRM payroll module"
  spec.required_ruby_version = ">= 3.4"
  spec.files = Dir.chdir(__dir__) { Dir.glob("{app,config,db,lib,test}/**/*").select { |file| File.file?(file) } }
  spec.require_paths = [ "lib" ]
  spec.add_dependency "sorbet-runtime", "~> 0.6"
  spec.add_dependency "csv", "~> 3.3"
  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "hrm_platform", "= 0.1.0"
end
