# -*- mode: ruby -*-
# vi: set ft=ruby :

def env(name)
  ENV[name] || ''
end

def addrStrToInventory(val)
  return val.split(',').map { |x|
    fqdn, ip = x.split(':')
    hostname, domain = fqdn.split('.')

    [ hostname, { ip: ip, domain: domain } ]
  }.to_h
end

Vagrant.configure('2') do |vconfig|
  box_name = 'debian/buster64'
  box_version = '10.3.0'

  ansible_host_vars = {}

  masters = addrStrToInventory(env('_VAGRANT_K8S_MASTERS_ADDR'))
  nodes = addrStrToInventory(env('_VAGRANT_K8S_NODES_ADDR'))

  nodes_port_forwarding = env('VAGRANT_K8S_NODES_PORT_FORWARDING').split(':').map { |x|
    x.split(',').map { |x| x.split('=') }
  }

  ansible_host_vars = masters.merge(nodes)

  certs_hostdir_fullpath = File.join(
    File.dirname(__FILE__), env('VAGRANT_K8S_CERTS_HOSTDIR'))

  masters.each do |nodename, nodevars| 
    vconfig.vm.define nodename do |node|
      node.vm.box = box_name
      node.vm.box_version = box_version
  
      node.vm.hostname = "#{nodename}.#{nodevars[:domain]}"
      
      node.vm.provider :virtualbox do |vb|
        vb.cpus = env('VAGRANT_K8S_MASTERS_CPUS')
        vb.memory = env('VAGRANT_K8S_MASTERS_MEMORY')
      end

      node.vm.network :private_network, ip: nodevars[:ip]

      ansible_host_vars[nodename][:etcd_certfile_srcpath] = "#{certs_hostdir_fullpath}/#{nodename}-etcd.crt"
      ansible_host_vars[nodename][:etcd_keyfile_srcpath] = "#{certs_hostdir_fullpath}/#{nodename}-etcd.key"
      ansible_host_vars[nodename][:k8s_kubelet_certfile_srcpath] = "#{certs_hostdir_fullpath}/#{nodename}-kubelet.crt"
      ansible_host_vars[nodename][:k8s_kubelet_keyfile_srcpath] = "#{certs_hostdir_fullpath}/#{nodename}-kubelet.key"
    end
  end

  nodes.each_with_index do |nodevars, i|
    vconfig.vm.define nodevars[0] do |node|
      node.vm.box = box_name
      node.vm.box_version = box_version
  
      node.vm.hostname = "#{nodevars[0]}.#{nodevars[1][:domain]}"
      
      node.vm.provider :virtualbox do |vb|
        vb.cpus = env('VAGRANT_K8S_NODES_CPUS')
        vb.memory = env('VAGRANT_K8S_NODES_MEMORY')
      end

      node.vm.network :private_network, ip: nodevars[1][:ip]
      if nodes_port_forwarding.length > i
        nodes_port_forwarding[i].each do |portpair|
          node.vm.network :forwarded_port, guest: portpair[0], host: portpair[1]
        end
      end

      ansible_host_vars[nodevars[0]][:etcd_certfile_srcpath] = "#{certs_hostdir_fullpath}/#{nodevars[0]}-etcd.crt"
      ansible_host_vars[nodevars[0]][:etcd_keyfile_srcpath] = "#{certs_hostdir_fullpath}/#{nodevars[0]}-etcd.key"
      ansible_host_vars[nodevars[0]][:k8s_kubelet_certfile_srcpath] = "#{certs_hostdir_fullpath}/#{nodevars[0]}-kubelet.crt"
      ansible_host_vars[nodevars[0]][:k8s_kubelet_keyfile_srcpath] = "#{certs_hostdir_fullpath}/#{nodevars[0]}-kubelet.key"

      if i+1 == nodes.length
        node.vm.provision :ansible do |ansible|
          ansible.playbook = 'provisioning/ansible/site.yml'
          ansible.limit = 'k8s'
          ansible.become = true

          ansible.host_vars = ansible_host_vars

          ansible.groups = {
            k8s_masters: masters.keys,
            k8s_nodes: nodes.keys,
            'k8s:children' => [ 'k8s_masters', 'k8s_nodes' ],
            'k8s:vars' => {
              common_cacertfile_srcpath: "#{certs_hostdir_fullpath}/ca.crt",
              etcd_cacertfile_srcpath: "#{certs_hostdir_fullpath}/ca.crt",
              k8s_domain: ENV['VAGRANT_K8S_K8S_DOMAIN'],
              k8s_masters_vip: ENV['_VAGRANT_K8S_MASTERS_VIP'],
              k8s_masters_vip_name: ENV['VAGRANT_K8S_MASTERS_VIP_NAME'],
              k8s_kubeapiserver_cacertfile_srcpath: "#{certs_hostdir_fullpath}/ca.crt",
              k8s_kubeapiserver_certfile_srcpath: "#{certs_hostdir_fullpath}/kube-apiserver.crt",
              k8s_kubeapiserver_keyfile_srcpath: "#{certs_hostdir_fullpath}/kube-apiserver.key",
              k8s_kubecontrollermanager_cacertfile_srcpath: "#{certs_hostdir_fullpath}/ca.crt",
              k8s_kubecontrollermanager_certfile_srcpath: "#{certs_hostdir_fullpath}/kube-controller-manager.crt",
              k8s_kubecontrollermanager_keyfile_srcpath: "#{certs_hostdir_fullpath}/kube-controller-manager.key",
              k8s_kubescheduler_cacertfile_srcpath: "#{certs_hostdir_fullpath}/ca.crt",
              k8s_kubescheduler_certfile_srcpath: "#{certs_hostdir_fullpath}/kube-scheduler.crt",
              k8s_kubescheduler_keyfile_srcpath: "#{certs_hostdir_fullpath}/kube-scheduler.key",
              k8s_kubeproxy_cacertfile_srcpath: "#{certs_hostdir_fullpath}/ca.crt",
              k8s_kubeproxy_certfile_srcpath: "#{certs_hostdir_fullpath}/kube-proxy.crt",
              k8s_kubeproxy_keyfile_srcpath: "#{certs_hostdir_fullpath}/kube-proxy.key",
              k8s_kubelet_cacertfile_srcpath: "#{certs_hostdir_fullpath}/ca.crt",
              k8s_kubectl_admin_cacertfile_srcpath: "#{certs_hostdir_fullpath}/ca.crt",
              k8s_kubectl_admin_certfile_srcpath: "#{certs_hostdir_fullpath}/admin.crt",
              k8s_kubectl_admin_keyfile_srcpath: "#{certs_hostdir_fullpath}/admin.key"
            }
          }
        end
      end
    end
  end
end
