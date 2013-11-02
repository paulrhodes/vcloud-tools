require_relative '../spec_helper'

module Provisioner

  describe Provisioner::Vm do

    before(:each) do
      @vm_id   = '1'
      @vapp_name = 'test-vm-1'
      @fog_interface = double(:fog_interface)
      @mock_vapp     = double(:vapp)
      @mock_vapp.stub(:name).and_return(@vapp_name)
      @mock_vm = {
        :name => "#{@vapp_name}",
        :href => "vm-href/#{@vm_id}",
        :'ovf:VirtualHardwareSection' => {
          :'ovf:Item' => [
            { # memory
              :'rasd:ResourceType'    => '4',
              :'rasd:VirtualQuantity' => '1024',
            },
            { # cpu count
              :'rasd:ResourceType' => '3',
              :'rasd:ResourceType' => '1',
            }
          ]
        }
      }
    end

    describe '#update_memory_size_in_mb' do
      context "update memory in VM" do
        it "should not allow memory size < 64MB"
        it "should not update memory if is size has not changed"
        it "should not allow a nil memory size"
        it "should set any memory size >=64MB"
      end
    end

    describe '#update_cpu_count' do
      context "update the number of cpus in vm" do
        it "should gracefully handle nil cpu count"
        it "should not update cpu if is count has not changed"
        it "should increase if necessary" do
          #@fog_interface.should_receive(:put_cpu).with(@vm_id, 2)
          #Provisioner::Vm.new(
          #    @fog_interface,
          #    @mock_vm,
          #    @mock_vapp).update_cpu_count(2)
        end
        it "should not allow zero CPUs"
      end
    end

    describe '#generate_preamble' do
      context "configure vm network connections" do
        it "should handle empty facts hash"
        it "should interpolate facts hash into template"
        it "should be able to interpolate general scope into template"
      end
    end

    describe '#configure_network_interfaces' do

      context "configure vm network connections" do

        it "should configure single nic" do
          network_config = [{:name => 'Default', :ip_address => '192.168.1.1'}]
          @fog_interface.should_receive(:put_network_connection_system_section_vapp).with('1', {
              :PrimaryNetworkConnectionIndex => 0,
              :NetworkConnection => [
                  {
                      :network => 'Default',
                      :needsCustomization => true,
                      :NetworkConnectionIndex => 0,
                      :IsConnected => true,
                      :IpAddress => "192.168.1.1",
                      :IpAddressAllocationMode => "MANUAL"
                  }
              ]})

          Provisioner::Vm.new(
              @fog_interface,
              @mock_vm,
              @mock_vapp).configure_network_interfaces(network_config)
        end

        it "should configure multiple nics" do
          network_config = [{:name => 'Default', :ip_address => '192.168.1.1'}, {:name => 'Monitoring', :ip_address => '192.168.2.1'}]

          @fog_interface.should_receive(:put_network_connection_system_section_vapp).with('1', {
              :PrimaryNetworkConnectionIndex => 0,
              :NetworkConnection => [
                  {
                      :network => 'Default',
                      :needsCustomization => true,
                      :NetworkConnectionIndex => 0,
                      :IsConnected => true,
                      :IpAddress => "192.168.1.1",
                      :IpAddressAllocationMode => "MANUAL"
                  },
                  {
                      :network => 'Monitoring',
                      :needsCustomization => true,
                      :NetworkConnectionIndex => 1,
                      :IsConnected => true,
                      :IpAddress => "192.168.2.1",
                      :IpAddressAllocationMode => "MANUAL"
                  },
              ]})
          Provisioner::Vm.new(
            @fog_interface,
            @mock_vm,
            @mock_vapp).configure_network_interfaces(network_config)
        end

        it "should configure no nics" do
          network_config = nil

          @fog_interface.should_not_receive(:put_network_connection_system_section_vapp)
          Provisioner::Vm.new(
              @fog_interface,
              @mock_vm, @mock_vapp
          ).configure_network_interfaces(network_config)
        end
      end

    end

  end

end
