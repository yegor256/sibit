# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT
Feature: Command Line Processing
  As a holder of BTC I want to use sibit in dry mode

  Scenario: Bitcoin price can be retrieved
    When I run bin/sibit with "price --dry --attempts=4"
    Then Exit code is zero

  Scenario: Bitcoin latest block hash can be retrieved
    When I run bin/sibit with "latest --dry --api=blockchain"
    Then Exit code is zero

  Scenario: Bitcoin balance can be checked
    When I run bin/sibit with "balance --dry 1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f --verbose --api=blockchain,btc"
    Then Exit code is zero

  Scenario: Bitcoin fees can be printed
    When I run bin/sibit with "fees --dry --verbose --api=fake"
    Then Exit code is zero

  Scenario: Bitcoin payment can be sent
    When I run bin/sibit with "pay --dry --verbose --api=fake --proxy=localhost:3128 999999 XL- 46feba063e9b59a8ae0dba68abd39a3cb8f52089e776576d6eb1bb5bfec123d1 1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f 1Fsyq5YGe8zbSjLS8YsDnZWM8U6AYMR6ZD"
    Then Exit code is not zero
    Then Stdout contains "UTXO arrived to 1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi is incorrect"

