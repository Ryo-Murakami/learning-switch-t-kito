Feature: "Learning Switch" sample application

  In order to learn how to implement software L2 switch
  As a developer using Trema
  I want to execute "Learning Switch" sample application

  @slow_process
  Scenario: Run Learning Switch
    Given a file named "trema.conf" with:
      """
      vswitch("learning") { datapath_id "0xabc" }

      vhost("host1") { ip "192.168.0.1" }
      vhost("host2") { ip "192.168.0.2" }

      link "learning", "host1"
      link "learning", "host2"
      """
    Given I run `trema run ../../learning_switch.rb -c trema.conf -d`
     And wait until "LearningSwitch" is up
    When I send 1 packet from host1 to host2
     And I run `trema show_stats host1 --tx`
     And I run `trema show_stats host2 --rx`
    Then the output from "trema show_stats host1 --tx" should contain "192.168.0.2,1,192.168.0.1,1,1,50"
     And the output from "trema show_stats host2 --rx" should contain "192.168.0.2,1,192.168.0.1,1,1,50"
