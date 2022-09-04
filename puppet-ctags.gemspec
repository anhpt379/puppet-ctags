Gem::Specification.new do |spec|
  spec.name        = 'puppet-ctags'
  spec.version     = '0.9.0'
  spec.homepage    = 'https://github.com/anhpt379/puppet-ctags'
  spec.license     = 'Mozilla 2.0'
  spec.author      = 'Anh Pham'
  spec.email       = 'anhpt379@gmail.com'
  spec.files       = Dir[
    'README.md',
    'LICENSE',
    'lib/**/*',
    'spec/**/*',
  ]
  spec.test_files  = Dir['spec/**/*']
  spec.summary     = 'puppet ctags generator'
  spec.description = <<-EOF
    Generate ctags for puppet files
  EOF

  spec.add_dependency             'puppet-lint', '> 1.0'
  spec.add_development_dependency 'rake'
end
