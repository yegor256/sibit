# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'donce'
require 'loog'
require 'qbash'
require 'shellwords'
require 'tmpdir'
require_relative 'test__helper'

# Cross-platform installation tests using Docker.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestCross < Minitest::Test
  Dir.glob(File.join(__dir__, '..', 'cross', '*.df')).each do |df|
    name = File.basename(df, '.df')
    define_method("test_works_on_#{name}") do
      skip unless docker?
      Dir.mktmpdir do |tmp|
        qbash(
          "gem build sibit.gemspec -o #{Shellwords.escape(File.join(tmp, 'sibit.gem'))}",
          chdir: File.expand_path('..', __dir__)
        )
        stdout = donce(
          dockerfile: File.read(df),
          volumes: { tmp => '/pkg' },
          command: 'bash -c "gem install --no-document /pkg/sibit.gem && sibit generate"',
          root: true,
          stdout: Loog::NULL, stderr: Loog::NULL
        )
        assert_match(/sibit/, stdout, 'sibit generate must mention sibit')
      end
    end
  end

  private

  def docker?
    qbash('docker info', accept: nil).include?('Version:')
  end
end
