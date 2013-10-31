module Provisioner
  class Vapp
    attr_reader :vdc, :id

    def initialize vcloud
      @fog_interface = vcloud
    end

    def provision config, vdc_name, template
      @vdc = @fog_interface.vdc_object_by_name vdc_name 
      network_names = config[:vm][:network_connections].collect { |h| h[:name] }
      networks = @fog_interface.find_networks(network_names, vdc_name)
      vapp = @fog_interface.post_instantiate_vapp_template(
          @fog_interface.vdc(vdc_name),
          template[:href].split('/').last,
          config[:name],
          InstantiationParams: build_network_config(networks)
      ).body
      @id = vapp[:href].split('/').last
      vm = Provisioner::Vm.new(@fog_interface, vapp[:Children][:Vm].first, self)
      vm.customize(config[:vm])
      @fog_interface.get_vapp(vapp[:href].split('/').last)
    end

    private
    def build_network_config networks
      instantiation = {NetworkConfigSection: {NetworkConfig: []}}
      networks.compact.each do |network|
        instantiation[:NetworkConfigSection][:NetworkConfig] << {
            networkName: network[:name],
            Configuration: {
                ParentNetwork: {href: network[:href]},
                FenceMode: 'bridged',
            }
        }
      end
      instantiation
    end
  end
end
