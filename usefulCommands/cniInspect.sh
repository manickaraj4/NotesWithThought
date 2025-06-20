#!/bin/bash

IFS=$'\n'
mappings=( $'IPAddress\tPodMACAddress\tARPMACAddress\tVethMAC\tVethID\tVethCNI' )

for netns in $( ip netns list | cut -d " " -f 1)
  do 
    echo "${netns} ==============" 
    ip netns exec "${netns}" ip route show 
    outputline="" 
    outputline+="$(ip netns exec "${netns}" ip a | grep "global eth0" | awk '{print $2}')"
    outputline+=$'\t'
    outputline+="$(ip netns exec "${netns}" ip a | grep "link/ether" | awk '{print $2}')"
    outputline+=$'\t'
    outputline+="$(ip netns exec "${netns}" arp -n | awk '/([a-z0-9]{2}:){5}([a-z0-9]{2})/{ print $3}')"
    outputline+=$'\t'
    outputline+="$(ip a | grep "${netns}" | awk '{print $2}')"
    outputline+=$'\t'
    outputline+="$(ip a | grep -B 1 ${netns} | awk '/[a-z0-9]+@[a-z0-9]+:/{print $2}')"
    outputline+=$'\t'
    outputline+="${netns}"

    mappings+=( "$outputline" )
  done

echo "*****************"
for line in ${mappings[@]}
  do
    echo $line
  done