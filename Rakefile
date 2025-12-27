# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'os'
require 'qbash'
require 'rake'
require 'rake/clean'
require 'rdoc'
require 'rubygems'
require 'shellwords'

def name
  @name ||= File.basename(Dir['*.gemspec'].first, '.*')
end

def version
  Gem::Specification.load(Dir['*.gemspec'].first).version
end

task default: %i[clean test picks features rubocop]

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  ENV['skip_live'] = 'yes'
  Rake::Cleaner.cleanup_files(['coverage'])
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = false
end

desc 'Run them via Ruby, one by one'
task :picks do
  next if OS.windows?
  %w[test lib].each do |d|
    Dir["#{d}/**/*.rb"].each do |f|
      qbash("bundle exec ruby #{Shellwords.escape(f)}", log: $stdout, env: { 'PICKS' => 'yes' })
    end
  end
end

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "#{name} #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

require 'rubocop/rake_task'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.fail_on_error = true
end

require 'cucumber/rake/task'
Cucumber::Rake::Task.new(:features) do
  Rake::Cleaner.cleanup_files(['coverage'])
end
Cucumber::Rake::Task.new(:'features:html') do |t|
  t.profile = 'html_report'
end
