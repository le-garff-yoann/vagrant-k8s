# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'

Vagrant.configure('2') do |vconfig|
  config = YAML.parse_file("#{File.expand_path(File.dirname(__FILE__))}/config.yml").to_ruby

  nat_done = false

  nodes = ENV['_VAGRANT_K8S_NODES_ADDR'].split(',').map { |x| x.split(':') }.to_h

  nodes.each_with_index do |node_addr, i|
    vconfig.vm.define node_addr[0] do |node|
      node.vm.box = 'debian/buster64'
      node.vm.box_version = '10.3.0'
  
      node.vm.hostname = node_addr[0]
      
      node.vm.provider :virtualbox do |vb|
        vb.cpus = config['virtual']['nodes']['cpus']
        vb.memory = config['virtual']['nodes']['memory']
      end

      node.vm.network :private_network, ip: node_addr[1]
      node.vm.network :forwarded_port, guest: 80, host: 80 unless nat_done
      node.vm.network :forwarded_port, guest: 443, host: 443 unless nat_done

      nat_done = true

      node.vm.provision 'shell', privileged: true, # TODO: Do it with Ansible.
        inline: "cp -r '/vagrant/#{config['srvkube']['host']}' '#{config['srvkube']['guest']}' && chmod 644 '#{config['srvkube']['guest']}'/* && chmod 755 '#{config['srvkube']['guest']}'"

      if i+1 == nodes.length
        node.vm.provision :ansible do |ansible|
          ansible.playbook = 'provisioning/ansible/site.yml'
          ansible.limit = 'all'
          ansible.become = true

          ansible.extra_vars = {
            k8s_config: config.merge({
              _virtual: {
                vip: ENV['_VAGRANT_K8S_NODES_VIP'],
                inventory: nodes # The auto-generated inventory is filled with NAT infos. # TODO: Use ansible.host_vars (https://www.vagrantup.com/docs/provisioning/ansible_common.html#host_vars).
              },
              _k8s: {
                excluded_addons: (ENV['VAGRANT_K8S_EXCLUDE_ADDONS'].split(/\s+/) rescue []),
                services: { traefik1: { acme: {
                  email: ENV['VAGRANT_K8S_ACME_EMAIL'],
                  caServer: ENV['VAGRANT_K8S_ACME_CASERVER'] || 'https://acme-v02.api.letsencrypt.org/directory'
                }}}
              }
            })
          }
        end
      end
    end
  end
end
