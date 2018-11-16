# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'json'

Vagrant.configure('2') do |vconfig|
  current_dir = File.expand_path(File.dirname(__FILE__))

  config = JSON.parse(File.read("#{current_dir}/config.json"))
  acme_config = JSON.parse(File.read("#{current_dir}acme.config.json")) rescue nil

  nat_done = false

  config['virtual']['nodes'].each do |nodename, node_config|
    vconfig.vm.define nodename do |node|
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
        inline: "mkdir -p '#{config['srvkube']['guest']}' && chown vagrant:vagrant '#{config['srvkube']['guest']}'" unless ENV.key?('VAGRANT_K8S_PROVISIONING_STEP')

      node.vm.provision 'file',
        source: "#{current_dir}/#{config['srvkube']['host']}",
        destination: config['srvkube']['guest']

      node.vm.provision 'shell', privileged: true,
        inline: "chmod -R g+r #{config['srvkube']['guest']}"

      features = []
   
      if File.exists?("#{current_dir}/provisioning/ansible/#{ENV['VAGRANT_K8S_PROVISIONING_STEP']}.yml") and
      ENV.key?('VAGRANT_K8S_EXCLUDE_ADDONS') || ! ENV['VAGRANT_K8S_EXCLUDE_ADDONS'].split(/\s+/).map { |x| "k8s.#{ENV['VAGRANT_K8S_PROVISIONING_STEP']}" }.include?(ENV['VAGRANT_K8S_PROVISIONING_STEP'])
        features.push($2) if ENV['VAGRANT_K8S_PROVISIONING_STEP'] =~ /^(k8s\.)(.*)/
        
        node.vm.provision 'ansible_local' do |ansible|
          ansible.playbook = "provisioning/ansible/#{ENV['VAGRANT_K8S_PROVISIONING_STEP']}.yml"

          ansible.extra_vars = {
            config: config.merge({ acme: {
              email: ENV['VAGRANT_K8S_ACME_EMAIL'],
              caServer: ENV['VAGRANT_K8S_ACME_CASERVER'] || 'https://acme-v02.api.letsencrypt.org/directory'
            }}),
            features: features
          }    

          ansible.become = true
          ansible.verbose = true
        end
      end
    end
  end
end
