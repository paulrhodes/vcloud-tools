module Provisioner
  class Vm

    attr_reader :vm, :vapp, :id

    def initialize fog_interface, vm, vapp
      @vm = vm
      @fog_interface = fog_interface
      @vapp = vapp
      @id = vm[:href].split('/').last
    end

    def customize vm_config
      configure_network_interfaces vm_config[:network_connections]
      if hardware_config = vm_config[:hardware_config]
        update_cpu_count(hardware_config[:cpu])
        update_memory_size_in_mb(hardware_config[:memory])
      end
      add_extra_disks(vm_config[:disks])
      configure_guest_customization_section(
            @vapp.name,
            vm_config[:bootstrap][:script_path],
            vm_config[:bootstrap][:facts] 
            )
    end

    def update_memory_size_in_mb(new_memory)
      return if new_memory.nil?
      return if new_memory.to_i < 64 
      unless memory.to_i == new_memory.to_i
        @fog_interface.put_memory(id, new_memory)
      end
    end

    def memory
      memory_item = virtual_hardware_section.detect { |i| i[:'rasd:ResourceType'] == '4' }
      memory_item[:'rasd:VirtualQuantity']
    end

    def cpu
      cpu_item = virtual_hardware_section.detect { |i| i[:'rasd:ResourceType'] == '3' }
      cpu_item[:'rasd:VirtualQuantity']
    end

    def update_cpu_count(new_cpu_count)
      return if new_cpu_count.nil?
      return if new_cpu_count.to_i == 0
      unless cpu.to_i == new_cpu_count.to_i
        @fog_interface.put_cpu(id, new_cpu_count)
      end
    end

    def add_extra_disks extra_disks
      vdc = self.vapp.vdc
      fog_vapp = vdc.vapps.get(vapp.id)
      vm = fog_vapp.vms.first
      if extra_disks
        extra_disks.each do |extra_disk|
          VCloud.logger.info("adding a disk of size #{extra_disk[:size]}MB into VM #{vm.id}")
          vm.disks.create(extra_disk[:size])
        end
      end
    end

    def configure_network_interfaces networks_config
      return unless networks_config
      section = {PrimaryNetworkConnectionIndex: 0}
      section[:NetworkConnection] = networks_config.compact.each_with_index.map do |network, i|
        connection = {
            network: network[:name],
            needsCustomization: true,
            NetworkConnectionIndex: i,
            IsConnected: true
        }
        ip_address = network[:ip_address]
        connection[:IpAddress] = ip_address unless ip_address.nil?
        connection[:IpAddressAllocationMode] = ip_address ? 'MANUAL' : 'DHCP'
        connection
      end
      begin
        @fog_interface.put_network_connection_system_section_vapp(id, section)
      rescue
        puts "\n"
        puts "=== networks_config:"
        pp networks_config
        puts "=== PUT request data section:"
        pp section
        raise
      end
    end

    def configure_guest_customization_section name, preamble_path, facts={}
      interpolated_preamble = generate_preamble(preamble_path, facts)
      begin
        @fog_interface.put_guest_customization_section(@id, name, interpolated_preamble)
      rescue
        puts "\n"
        puts "=== facts:"
        pp facts
        puts "=== interpolated preamble:"
        pp interpolated_preamble
        raise
      end
    end

    def generate_preamble(script_path, facts)
      root = '.'
      vapp_name = vapp.name
      script = ERB.new(File.read(script_path), nil, '>-').result(binding)
      Open3.capture2(File.join(root, 'bin/minifier.py'), stdin_data: script).first
    end

    def virtual_hardware_section
      vm[:'ovf:VirtualHardwareSection'][:'ovf:Item']
    end

  end
end
