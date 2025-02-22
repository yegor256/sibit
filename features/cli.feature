# (The MIT License)
#
# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT
Feature: Command Line Processing
  As a newsletter author I want to be able to send a newsletter

  Scenario: Help can be printed
    When I run bin/sibit with "--help"
    Then Exit code is zero
    And Stdout contains "--help"

  Scenario: Bitcoin price can be retrieved
    When I run bin/sibit with "price --attempts=4"
    Then Exit code is zero

  Scenario: Bitcoin latest block hash can be retrieved
    When I run bin/sibit with "latest --api=blockchain"
    Then Exit code is zero

  Scenario: Bitcoin private key can be generated
    When I run bin/sibit with "generate"
    Then Exit code is zero

  Scenario: Bitcoin address can be created
    When I run bin/sibit with "create 46feba063e9b59a8ae0dba68abd39a3cb8f52089e776576d6eb1bb5bfec123d1"
    Then Exit code is zero

  Scenario: Bitcoin balance can be checked
    When I run bin/sibit with "balance 1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f --verbose --api=blockchain,btc"
    Then Exit code is zero

  Scenario: Bitcoin fees can be printed
    When I run bin/sibit with "fees --verbose --api=fake"
    Then Exit code is zero
