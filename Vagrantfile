# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'json'

Vagrant.configure('2') do |config|
  current_dir = File.expand_path(File.dirname(__FILE__))
  project_config = JSON.parse(File.read("#{current_dir}/config.json"))

  nat_done = false

  project_config['virtual']['nodes'].each do |nodename, node_config|
    config.vm.define nodename do |node|
      node.vm.box = 'le-garff-yoann/debian9-compose'
      node.vm.box_version = '1.0.0'
  
      node.vm.hostname = nodename
      
      node.vm.provider 'virtualbox' do |vb|
        vb.cpus = node_config['cpus']
        vb.memory = node_config['memory']
      end

      node.vm.network 'private_network', ip: node_config['ip']
      node.vm.network 'forwarded_port', guest: 80, host: 80 unless nat_done
      node.vm.network 'forwarded_port', guest: 443, host: 443 unless nat_done

      nat_done = true

      node.vm.provision 'shell', privileged: true,
        inline: "mkdir -p '#{project_config['srvkube']['guest']}' && chown vagrant:vagrant '#{project_config['srvkube']['guest']}'" unless ENV.key?('VAGRANT_K8S_PROVISIONING_STEP')

      node.vm.provision 'file',
        source: "#{current_dir}/#{project_config['srvkube']['host']}",
        destination: project_config['srvkube']['guest']

      node.vm.provision 'shell', privileged: true,
        inline: "chmod -R g+r #{project_config['srvkube']['guest']}"
   
      if File.exists?("#{current_dir}/provisioning/ansible/#{ENV['VAGRANT_K8S_PROVISIONING_STEP']}.yml")
        node.vm.provision 'ansible_local' do |ansible|
          ansible.playbook = "provisioning/ansible/#{ENV['VAGRANT_K8S_PROVISIONING_STEP']}.yml"

          ansible.extra_vars = {
            project_config: project_config
          }    

          ansible.become = true
          ansible.verbose = true
        end
      end
    end
  end
end
