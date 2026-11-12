Gem::Specification.new do |spec|
  spec.name = "hrm_organization"
  spec.version = "0.1.0"
  spec.authors = [ "XinViec" ]
  spec.summary = "Company-scoped organization structure and staffing"
  spec.required_ruby_version = ">= 3.4"
  spec.files = Dir.chdir(__dir__) { Dir.glob("{app,config,db,lib,test}/**/*").select { |f| File.file?(f) } }
  spec.require_paths = [ "lib" ]
  spec.add_dependency "csv", "~> 3.3"
  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "hrm_platform", "= 0.1.0"
  spec.add_dependency "hrm_identity", "= 0.1.0"
  spec.add_dependency "hrm_workforce", "= 0.1.0"
end
