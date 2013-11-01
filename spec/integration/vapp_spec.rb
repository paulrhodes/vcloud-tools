require_relative '../spec_helper'

describe Provisioner::Vapp do
  before(:all) do
    @fog_interface = FogInterface.new
    TEST_VDC = 'GDS Networking API Testing (IL0-DEVTEST-BASIC)'
    template = @fog_interface.template('walker-ci', 'nick-method-precise64')
    
    script_path = File.join(File.dirname(__FILE__), "../data/default_preamble.sh.erb")
    @vapp_config = {
        :name => "vapp-vcloud-tools-tests-#{Time.now.strftime('%s')}",
        :vm => {
          :hardware_config => {
              :memory => 4096,
              :cpu => 2
          },
          :disks => [{:size => '1024', :name => 'Hard disk 2'  }, {:size => '2048', :name => 'Hard disk 3'}],
          :network_connections => [{:name => 'Default', :ip_address => '192.168.2.10'}, {:name => 'NetworkTest2', :ip_address => '192.168.1.10'}],
          :bootstrap => {:script_path => script_path , :facts => { :message => 'hello world' } },
        },
    }

    @vapp = Provisioner::Vapp.new(@fog_interface).provision(@vapp_config, TEST_VDC, template)
    @vm = @vapp[:Children][:Vm].first
  end

  context 'provision vapp' do
    it 'should create a vapp' do
      @vapp[:name].should == @vapp_config[:name]
      @vapp[:'ovf:NetworkSection'][:'ovf:Network'].count.should == 2
      vapp_networks = @vapp[:'ovf:NetworkSection'][:'ovf:Network'].collect {|connection| connection[:ovf_name]}
      vapp_networks.should =~ ['Default', 'NetworkTest2']
    end

    it "should create vm within vapp" do
      @vm.should_not be_nil
    end

  end

  context "customize vm" do
    it "change cpu for given vm" do
      extract_memory(@vm).should == @vapp_config[:vm][:hardware_config][:memory].to_s
      extract_cpu(@vm).should == @vapp_config[:vm][:hardware_config][:cpu].to_s
    end

    it "should attach extra hard disks to vm" do
      disks = extract_disks(@vm)
      disks.count.should == 3
      @vapp_config[:vm][:disks].each do |new_disk|
         disks.should include(new_disk)
      end
    end

    it "should configure the vm network interface" do
      vm_network_connection = @vm[:NetworkConnectionSection][:NetworkConnection]
      vm_network_connection.should_not be_nil
      vm_network_connection.count.should == 2

      primary_nic = vm_network_connection.detect{|connection| connection[:network] == 'Default'}
      primary_nic[:network].should == 'Default'
      primary_nic[:NetworkConnectionIndex].should == @vm[:NetworkConnectionSection][:PrimaryNetworkConnectionIndex]
      primary_nic[:IpAddress].should == '192.168.2.10'
      primary_nic[:IpAddressAllocationMode].should == 'MANUAL'

      second_nic = vm_network_connection.detect{|connection| connection[:network] == 'NetworkTest2'}
      second_nic[:network].should == 'NetworkTest2'
      second_nic[:NetworkConnectionIndex].should == '1'
      second_nic[:IpAddress].should == '192.168.1.10'
      second_nic[:IpAddressAllocationMode].should == 'MANUAL'

    end

    it 'should assign guest customization script to a VM' do
      @vm[:GuestCustomizationSection][:CustomizationScript].should =~ /message: hello world/
      @vm[:GuestCustomizationSection][:ComputerName].should == @vapp_config[:name]
    end

  end

  after(:all) do
    unless ENV['VCLOUD_TOOLS_RSPEC_NO_DELETE_VAPP']
      @fog_interface.delete_vapp(@vapp[:href].split('/').last).should == true
    end
  end

end

def extract_memory(vm)
  vm[:'ovf:VirtualHardwareSection'][:'ovf:Item'].detect { |i| i[:'rasd:ResourceType'] == '4' }[:'rasd:VirtualQuantity']
end

def extract_cpu(vm)
  vm[:'ovf:VirtualHardwareSection'][:'ovf:Item'].detect { |i| i[:'rasd:ResourceType'] == '3' }[:'rasd:VirtualQuantity']
end

def extract_disks vm
  vm[:'ovf:VirtualHardwareSection'][:'ovf:Item'].collect{|d|
    { :name => d[:"rasd:ElementName"] , :size => d[:"rasd:HostResource"][:ns12_capacity] } if d[:'rasd:ResourceType'] == '17'
  }.compact
end
