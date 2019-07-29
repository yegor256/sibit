Feature: Command Line Processing
  As a newsletter author I want to be able to send a newsletter

  Scenario: Help can be printed
    When I run bin/sibit with "--help"
    Then Exit code is zero
    And Stdout contains "--help"

  Scenario: Bitcoin price can be retrieved
    When I run bin/sibit with "price"
    Then Exit code is zero

  Scenario: Bitcoin latest block hash can be retrieved
    When I run bin/sibit with "latest"
    Then Exit code is zero

  Scenario: Bitcoin private key can be generated
    When I run bin/sibit with "generate"
    Then Exit code is zero

  Scenario: Bitcoin address can be created
    When I run bin/sibit with "create 46feba063e9b59a8ae0dba68abd39a3cb8f52089e776576d6eb1bb5bfec123d1"
    Then Exit code is zero

  Scenario: Bitcoin balance can be checked
    When I run bin/sibit with "balance 1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f --verbose"
    Then Exit code is zero

  Scenario: Bitcoin fees can be printed
    When I run bin/sibit with "fees --verbose"
    Then Exit code is zero

  Scenario:
    # @todo #35:30m For now, there is a warning when I run the test.
    #  Needs to replace the current call to not deprecated one.
    When I run "ruby ../../bin/sibit balance --api=11234,124"
    Then the exit status should be 1
    And the stderr should contain:
    """
    NOT IMPLEMENTED YET
    """
