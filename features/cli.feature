Feature: Command Line Processing
  As a newsletter author I want to be able to send a newsletter

  Scenario: Help can be printed
    When I run bin/sibit with "--help"
    Then Exit code is zero
    And Stdout contains "--help"
