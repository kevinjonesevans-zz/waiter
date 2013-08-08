# Ensure we require the local version and not one we might have installed already
require File.join([File.dirname(__FILE__),'lib','waiter','version.rb'])
spec = Gem::Specification.new do |s| 
  s.name = 'waiter'
  s.version = Waiter::VERSION
  s.author = 'Your Name Here'
  s.email = 'your@email.address.com'
  s.homepage = 'http://your.website.com'
  s.platform = Gem::Platform::RUBY
  s.summary = 'A description of your project'
# Add your other files here if you make them
  s.files = %w(
bin/waiter
lib/waiter/version.rb
lib/waiter.rb
  )
  s.require_paths << 'lib'
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.rdoc','waiter.rdoc']
  s.rdoc_options << '--title' << 'waiter' << '--main' << 'README.rdoc' << '-ri'
  s.bindir = 'bin'
  s.executables << 'waiter'
  s.add_development_dependency('rake')
  s.add_development_dependency('rdoc')
  s.add_development_dependency('aruba')
  s.add_runtime_dependency('gli','2.7.0')
end