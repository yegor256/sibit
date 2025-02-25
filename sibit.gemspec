# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'English'

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require_relative 'lib/sibit/version'
Gem::Specification.new do |s|
  if s.respond_to? :required_rubygems_version=
    s.required_rubygems_version = Gem::Requirement.new('>= 0')
  end
  s.required_ruby_version = '>= 2.5'
  s.name = 'sibit'
  s.version = Sibit::VERSION
  s.license = 'MIT'
  s.summary = 'Simple Bitcoin Client'
  s.description =
    'This is a simple Bitcoin client, to use from command line ' \
    'or from your Ruby app. You don\'t need to run any Bitcoin software, ' \
    'no need to install anything, etc. All you need is just a command line ' \
    'and Ruby 2.5+.'
  s.authors = ['Yegor Bugayenko']
  s.email = 'yegor256@gmail.com'
  s.homepage = 'http://github.com/yegor256/sibit'
  s.files = `git ls-files`.split($RS)
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.rdoc_options = ['--charset=UTF-8']
  s.extra_rdoc_files = ['README.md', 'LICENSE.txt']
  s.add_runtime_dependency 'backtrace', '~> 0.3'
  s.add_runtime_dependency 'bitcoin-ruby', '0.0.20'
  s.add_runtime_dependency 'iri', '~> 0.5'
  s.add_runtime_dependency 'json', '~> 2'
  s.add_runtime_dependency 'openssl', '~>2.0'
  s.add_runtime_dependency 'retriable_proxy', '~> 1.0'
  s.add_runtime_dependency 'slop', '~> 4.6'
end
