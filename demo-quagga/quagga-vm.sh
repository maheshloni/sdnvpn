#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018 Ericsson and Others.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
SDNVPN_PLAYBOOKS="$(dirname $(realpath ${BASH_SOURCE[0]}))/playbooks"

echo "Info: Install and Start Quagga process on the localhost"
echo "-----------------------------------------------------------------------"
cd $SDNVPN_PLAYBOOKS
ansible-playbook -v -i "localhost," -c local setup-quagga.yml
echo "-----------------------------------------------------------------------"
echo "Info: Configured localhost host for Quagga"

echo "Info: Configure Quagga with BGP neighbor and VRFs"
echo "-----------------------------------------------------------------------"
(sleep 1;echo "sdncbgpc";sleep 1;cat /tmp/quagga-config;sleep 1; echo "exit") |nc -q1 localhost 2605
echo "Info: Configured Quagga with BGP neighbor and VRFs"

echo "Info: Configure External network for Quagga VM"
echo "-----------------------------------------------------------------------"
ovs-vsctl add-br br-int
ip netns add n1
ip link add vn1 type veth peer name peer1
ip link set peer1 netns n1
ip link set vn1 up
ip netns exec n1 ip addr add 30.1.1.1/24 dev peer1
ip netns exec n1 ip link set peer1 up
ip netns exec n1 ip route add default via 30.1.1.100
ip netns exec n1 arp -s 30.1.1.100 00:0c:29:c0:94:bf
echo "Info: External network is configured with IP Network namespace"

echo "Info: Attach the external network with OVS"
echo "-----------------------------------------------------------------------"
ovs-vsctl add-port br-int vn1
ovs-vsctl add-port br-int gre-tun -- set Interface gre-tun type=gre options:remote_ip=172.29.240.12 options:key=flow options:layer3=true
ovs-ofctl add-flow br-int dl_type=0x800,nw_src=30.1.1.1/32,nw_dst=11.0.1.1/32,actions=push_mpls:0x8847,set_field:0x100-\>mpls_label,output:"gre-tun"
ovs-ofctl add-flow br-int dl_type=0x8847,in_port="gre-tun",actions=pop_mpls:0x8847,output:"vn1"
echo "Info: External network is attached to OVS for L3 communication"
