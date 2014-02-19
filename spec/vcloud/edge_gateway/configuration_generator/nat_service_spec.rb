require 'spec_helper'

module Vcloud
  module EdgeGateway
    module ConfigurationGenerator
      describe NatService do

        before(:each) do
          @base_nat_id = ID_RANGES::NAT_SERVICE[:min]
          @edge_id = '1111111-7b54-43dd-9eb1-631dd337e5a7'
          @mock_edge_gateway = double(
            :edge_gateway,
            :vcloud_gateway_interface_by_id => {
              Network: {
                type: 'application/vnd.vmware.admin.network+xml',
                name: 'ane012345',
                href: 'https://vmware.api.net/api/admin/network/2ad93597-7b54-43dd-9eb1-631dd337e5a7'
              }
            }
          )
          expect(Vcloud::Core::EdgeGateway).to receive(:get_by_name).with(@edge_id)
                                               .and_return(@mock_edge_gateway)
        end

        context "SNAT rule defaults" do

          before(:each) do
            input = { nat_rules: [{
              rule_type: 'SNAT',
              network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
              original_ip: "192.0.2.2",
              translated_ip: "10.10.20.20",
            }]} # minimum NAT configuration with a rule
            output = NatService.new(@edge_id, input).generate_fog_config
            @rule = output[:NatRule].first
          end

          it 'should default to the rule being enabled' do
            expect(@rule[:IsEnabled]).to eq('true')
          end

          it 'should have a RuleType of SNAT' do
            expect(@rule[:RuleType]).to eq('SNAT')
          end

          it 'should not include a Protocol' do
            expect(@rule[:GatewayNatRule].key?(:Protocol)).to be_false
          end

          it 'should completely match our expected default rule' do
            expect(@rule).to eq({
              :Id=>"#{@base_nat_id}",
              :IsEnabled=>"true",
              :RuleType=>"SNAT",
              :GatewayNatRule=>{
                :Interface=>{
                  :type => 'application/vnd.vmware.admin.network+xml',
                  :name => "ane012345",
                  :href => "https://vmware.api.net/api/admin/network/2ad93597-7b54-43dd-9eb1-631dd337e5a7"
                },
              :OriginalIp=>"192.0.2.2",
              :TranslatedIp=>"10.10.20.20"}
            })
          end

        end

        context "DNAT rule defaults" do

          before(:each) do
            input = { nat_rules: [{
              rule_type: 'DNAT',
              network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
              original_ip: "192.0.2.2",
              original_port: '22',
              translated_port: '22',
              translated_ip: "10.10.20.20",
              protocol: 'tcp',
            }]} # minimum NAT configuration with a rule
            output = NatService.new(@edge_id, input).generate_fog_config
            @rule = output[:NatRule].first
          end

          it 'should default to rule being enabled' do
            expect(@rule[:IsEnabled]).to eq('true')
          end

          it 'should have a RuleType of DNAT' do
            expect(@rule[:RuleType]).to eq('DNAT')
          end

          it 'should include a default Protocol of tcp' do
            expect(@rule[:GatewayNatRule][:Protocol]).to eq('tcp')
          end

          it 'should completely match our expected default rule' do
            expect(@rule).to eq({
              :Id=>"#{@base_nat_id}",
              :IsEnabled=>"true",
              :RuleType=>"DNAT",
              :GatewayNatRule=>{
                :Interface=>{
                  :type => 'application/vnd.vmware.admin.network+xml',
                  :name => "ane012345",
                  :href => "https://vmware.api.net/api/admin/network/2ad93597-7b54-43dd-9eb1-631dd337e5a7"
                },
                :OriginalIp=>"192.0.2.2",
                :TranslatedIp=>"10.10.20.20",
                :OriginalPort=>"22",
                :TranslatedPort=>"22",
                :Protocol=>"tcp"
              }
            })
          end

        end

        context "nat service config generation" do

          it 'should generate config for enabled nat service with single disabled DNAT rule' do
              input = {
                enabled: 'true',
                nat_rules: [
                  {
                    enabled: 'false',
                    id: '999',
                    rule_type: 'DNAT',
                    network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
                    original_ip: "192.0.2.2",
                    original_port: '22',
                    translated_port: '22',
                    translated_ip: "10.10.20.20",
                    protocol: 'tcp',
                  }
                ]
              }
              output = {
                :IsEnabled => 'true',
                :NatRule => [
                  {
                    :RuleType => 'DNAT',
                    :IsEnabled => 'false',
                    :Id => '999',
                    :GatewayNatRule => {
                      :Interface =>
                        {
                          :type => 'application/vnd.vmware.admin.network+xml',
                          :name => 'ane012345',
                          :href => 'https://vmware.api.net/api/admin/network/2ad93597-7b54-43dd-9eb1-631dd337e5a7'
                        },
                      :Protocol => 'tcp',
                      :OriginalIp => "192.0.2.2",
                      :OriginalPort => '22',
                      :TranslatedIp => "10.10.20.20",
                      :TranslatedPort => '22'
                    }
                  }
                ]
              }
            generated_config = NatService.new(@edge_id, input).generate_fog_config
            expect(generated_config).to eq(output)
          end

          it 'should handle specification of UDP based DNAT rules' do
              input = {
                enabled: 'true',
                nat_rules: [
                  {
                    rule_type: 'DNAT',
                    network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
                    original_ip: "192.0.2.25",
                    original_port: '53',
                    translated_port: '53',
                    translated_ip: "10.10.20.25",
                    protocol: 'udp',
                  }
                ]
              }
              output = {
                :IsEnabled => 'true',
                :NatRule => [
                  {
                    :RuleType => 'DNAT',
                    :IsEnabled => 'true',
                    :Id => "#{@base_nat_id}",
                    :GatewayNatRule => {
                      :Interface =>
                        {
                          :type => 'application/vnd.vmware.admin.network+xml',
                          :name => 'ane012345',
                          :href => 'https://vmware.api.net/api/admin/network/2ad93597-7b54-43dd-9eb1-631dd337e5a7'
                        },
                      :Protocol => 'udp',
                      :OriginalIp => "192.0.2.25",
                      :OriginalPort => '53',
                      :TranslatedIp => "10.10.20.25",
                      :TranslatedPort => '53'
                    }
                  }
                ]
              }
            generated_config = NatService.new(@edge_id, input).generate_fog_config
            expect(generated_config).to eq(output)
          end

          it 'should generate config for enabled nat service with single disabled SNAT rule' do
              input = {
                enabled: 'true',
                nat_rules: [
                  {
                    enabled: 'false',
                    rule_type: 'SNAT',
                    network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
                    original_ip: "192.0.2.2",
                    translated_ip: "10.10.20.20",
                  }
                ]
              }
              output = {
                :IsEnabled => 'true',
                :NatRule => [
                  {
                    :RuleType => 'SNAT',
                    :IsEnabled => 'false',
                    :Id => "#{@base_nat_id}",
                    :GatewayNatRule => {
                      :Interface =>
                        {
                          :type => 'application/vnd.vmware.admin.network+xml',
                          :name => 'ane012345',
                          :href => 'https://vmware.api.net/api/admin/network/2ad93597-7b54-43dd-9eb1-631dd337e5a7'
                        },
                      :OriginalIp => "192.0.2.2",
                      :TranslatedIp => "10.10.20.20",
                    }
                  }
                ]
              }
            generated_config = NatService.new(@edge_id, input).generate_fog_config
            expect(generated_config).to eq(output)
          end

          it 'should auto generate rule id if not provided' do
              input = {
                enabled: 'true',
                nat_rules: [
                  {
                    enabled: 'false',
                    rule_type: 'DNAT',
                    network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
                    original_ip: "192.0.2.2",
                    original_port: '22',
                    translated_port: '22',
                    translated_ip: "10.10.20.20",
                    protocol: 'tcp',
                  }
                ]
              }
              output = {
                :IsEnabled => 'true',
                :NatRule => [
                  {
                    :RuleType => 'DNAT',
                    :IsEnabled => 'false',
                    :Id => "#{@base_nat_id}",
                    :GatewayNatRule => {
                      :Interface =>
                        {
                          :type => 'application/vnd.vmware.admin.network+xml',
                          :name => 'ane012345',
                          :href => 'https://vmware.api.net/api/admin/network/2ad93597-7b54-43dd-9eb1-631dd337e5a7'
                        },
                      :Protocol => 'tcp',
                      :OriginalIp => "192.0.2.2",
                      :OriginalPort => '22',
                      :TranslatedIp => "10.10.20.20",
                      :TranslatedPort => '22'
                    }
                  }
                ]
              }
            generated_config = NatService.new(@edge_id, input).generate_fog_config
            expect(generated_config).to eq(output)
          end

          it 'should use default values for optional fields if they are missing' do
              input = {
                nat_rules: [
                  {
                    rule_type: 'DNAT',
                    network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
                    original_ip: "192.0.2.2",
                    original_port: '22',
                    translated_port: '22',
                    translated_ip: "10.10.20.20",
                  }
                ]
              }
              output = {
                :IsEnabled => 'true',
                :NatRule => [
                  {
                    :RuleType => 'DNAT',
                    :IsEnabled => 'true',
                    :Id => "#{@base_nat_id}",
                    :GatewayNatRule => {
                      :Interface =>
                        {
                          :type => 'application/vnd.vmware.admin.network+xml',
                          :name => 'ane012345',
                          :href => 'https://vmware.api.net/api/admin/network/2ad93597-7b54-43dd-9eb1-631dd337e5a7'
                        },
                      :Protocol => 'tcp',
                      :OriginalIp => "192.0.2.2",
                      :OriginalPort => '22',
                      :TranslatedIp => "10.10.20.20",
                      :TranslatedPort => '22'
                    }
                  }
                ]
              }
            generated_config = NatService.new(@edge_id, input).generate_fog_config
            expect(generated_config).to eq(output)
          end

          it 'output rule order should be same as the input rule order' do
              input = {
                nat_rules: [
                  {
                    rule_type: 'DNAT',
                    network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
                    original_ip: "192.0.2.2",
                    original_port: '8081',
                    translated_port: '8080',
                    translated_ip: "10.10.20.21",
                  },
                  {
                    rule_type: 'SNAT',
                    network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
                    original_ip: "192.0.2.2",
                    translated_ip: "10.10.20.20",
                  },
                  {
                    rule_type: 'DNAT',
                    network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
                    original_ip: "192.0.2.2",
                    original_port: '8082',
                    translated_port: '8080',
                    translated_ip: "10.10.20.22",
                  },
                  {
                    rule_type: 'SNAT',
                    network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
                    original_ip: "192.0.2.3",
                    translated_ip: "10.10.20.21",
                  },
                  {
                    rule_type: 'DNAT',
                    network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
                    original_ip: "192.0.2.2",
                    original_port: '8083',
                    translated_port: '8080',
                    translated_ip: "10.10.20.23",
                  },
                ],
              }
              output = {
                IsEnabled: 'true',
                NatRule: [
                  {
                    :Id => "#{@base_nat_id}",
                    :IsEnabled => 'true',
                    :RuleType => 'DNAT',
                    :GatewayNatRule => {
                      :Interface =>
                        {
                          :type => 'application/vnd.vmware.admin.network+xml',
                          :name => 'ane012345',
                          :href => 'https://vmware.api.net/api/admin/network/2ad93597-7b54-43dd-9eb1-631dd337e5a7'
                        },
                      :OriginalIp => "192.0.2.2",
                      :TranslatedIp => "10.10.20.21",
                      :OriginalPort => '8081',
                      :TranslatedPort => '8080',
                      :Protocol => 'tcp',
                    },
                  },
                  {
                    :Id => "#{@base_nat_id + 1}",
                    :IsEnabled => 'true',
                    :RuleType => 'SNAT',
                    :GatewayNatRule => {
                      :Interface =>
                        {
                          :type => 'application/vnd.vmware.admin.network+xml',
                          :name => 'ane012345',
                          :href => 'https://vmware.api.net/api/admin/network/2ad93597-7b54-43dd-9eb1-631dd337e5a7'
                        },
                      :OriginalIp => "192.0.2.2",
                      :TranslatedIp => "10.10.20.20",
                    },
                  },
                  {
                    :Id => "#{@base_nat_id + 2}",
                    :IsEnabled => 'true',
                    :RuleType => 'DNAT',
                    :GatewayNatRule => {
                      :Interface =>
                        {
                          :type => 'application/vnd.vmware.admin.network+xml',
                          :name => 'ane012345',
                          :href => 'https://vmware.api.net/api/admin/network/2ad93597-7b54-43dd-9eb1-631dd337e5a7'
                        },
                      :OriginalIp => "192.0.2.2",
                      :TranslatedIp => "10.10.20.22",
                      :OriginalPort => '8082',
                      :TranslatedPort => '8080',
                      :Protocol => 'tcp',
                    },
                  },
                  {
                    :Id => "#{@base_nat_id + 3}",
                    :IsEnabled => 'true',
                    :RuleType => 'SNAT',
                    :GatewayNatRule => {
                      :Interface =>
                        {
                          :type => 'application/vnd.vmware.admin.network+xml',
                          :name => 'ane012345',
                          :href => 'https://vmware.api.net/api/admin/network/2ad93597-7b54-43dd-9eb1-631dd337e5a7'
                        },
                      :OriginalIp => "192.0.2.3",
                      :TranslatedIp => "10.10.20.21",
                    },
                  },
                  {
                    :Id => "#{@base_nat_id + 4}",
                    :IsEnabled => 'true',
                    :RuleType => 'DNAT',
                    :GatewayNatRule => {
                      :Interface =>
                        {
                          :type => 'application/vnd.vmware.admin.network+xml',
                          :name => 'ane012345',
                          :href => 'https://vmware.api.net/api/admin/network/2ad93597-7b54-43dd-9eb1-631dd337e5a7'
                        },
                      :OriginalIp => "192.0.2.2",
                      :TranslatedIp => "10.10.20.23",
                      :OriginalPort => '8083',
                      :TranslatedPort => '8080',
                      :Protocol => 'tcp',
                    },
                  }
                ]
              }
            generated_config = NatService.new(@edge_id, input).generate_fog_config
            expect(generated_config).to eq(output)
          end

          it "should only make a single API call per network specified" do
            input = {
              nat_rules: [
                {
                  rule_type: 'DNAT',
                  network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
                  original_ip: "192.0.2.2",
                  original_port: '8081',
                  translated_port: '8081',
                  translated_ip: "10.10.20.21",
                },
                {
                  rule_type: 'DNAT',
                  network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
                  original_ip: "192.0.2.2",
                  original_port: '8082',
                  translated_port: '8082',
                  translated_ip: "10.10.20.22",
                },
                {
                  rule_type: 'DNAT',
                  network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
                  original_ip: "192.0.2.2",
                  original_port: '8083',
                  translated_port: '8083',
                  translated_ip: "10.10.20.23",
                },
              ]
            }
            expect(@mock_edge_gateway).
              to receive(:vcloud_gateway_interface_by_id).exactly(1).times
            NatService.new(@edge_id, input).generate_fog_config
          end

        end
      end
    end
  end
end
