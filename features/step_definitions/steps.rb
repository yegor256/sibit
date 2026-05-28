# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'English'
require 'nokogiri'
require 'tmpdir'
require_relative '../../lib/sibit'

Before do
  @cwd = Dir.pwd
  @dir = Dir.mktmpdir('test')
  FileUtils.mkdir_p(@dir)
  Dir.chdir(@dir)
end

After do
  Dir.chdir(@cwd)
  FileUtils.rm_rf(@dir)
end

Given(/^I have a "([^"]*)" file with content:$/) do |file, text|
  FileUtils.mkdir_p(File.dirname(file)) unless File.exist?(file)
  File.write(file, text.gsub('\\xFF', 0xFF.chr))
end

When(%r{^I run bin/sibit with "([^"]*)"$}) do |arg|
  home = File.join(File.dirname(__FILE__), '../..')
  @stdout = `ruby -I#{home}/lib #{home}/bin/sibit #{arg} 2>&1`
  @exitstatus = $CHILD_STATUS.exitstatus
end

Then(/^Stdout contains "([^"]*)"$/) do |txt|
  raise(StandardError, "STDOUT doesn't contain '#{txt}':\n#{@stdout}") unless @stdout.include?(txt)
end

Then(/^Stdout is empty$/) do
  raise(StandardError, "STDOUT is not empty:\n#{@stdout}") unless @stdout == ''
end

Then(/^Exit code is zero$/) do
  raise(StandardError, "Non-zero exit #{@exitstatus}:\n#{@stdout}") unless @exitstatus.zero?
end

Then(/^Exit code is not zero$/) do
  raise(StandardError, 'Zero exit code') if @exitstatus.zero?
end

When(/^I run bash with "([^"]*)"$/) do |text|
  FileUtils.copy_entry(@cwd, File.join(@dir, 'sibit'))
  @stdout = `#{text}`
  @exitstatus = $CHILD_STATUS.exitstatus
end

When(/^I run bash with:$/) do |text|
  FileUtils.copy_entry(@cwd, File.join(@dir, 'sibit'))
  @stdout = `#{text}`
  @exitstatus = $CHILD_STATUS.exitstatus
end

Given(/^It is Unix$/) do
  pending if Gem.win_platform?
end

Given(/^It is Windows$/) do
  pending unless Gem.win_platform?
end
