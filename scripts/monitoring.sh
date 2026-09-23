#!/bin/bash

# Architecture
arch=$(uname -a)

# Physical CPUs (sockets)
pcpu=$(lscpu -p=SOCKET | grep -v '^#' | sort -u | wc -l)

# Virtual CPUs
vcpu=$(grep -c "^processor" /proc/cpuinfo)

# RAM
ram_total=$(free -m | awk '/^Mem:/ {print $2}')
ram_used=$(free -m | awk '/^Mem:/ {print $3}')
ram_percent=$(free | awk '/^Mem:/ {printf "%.2f", $3/$2*100}')

# Disk
disk_total=$(df -BM -x tmpfs -x devtmpfs -x efivarfs --total | tail -n 1 | awk '{print $2}')
disk_used=$(df -BM -x tmpfs -x devtmpfs -x efivarfs --total | tail -n 1 | awk '{print $3}')
disk_percent=$(df -BM -x tmpfs -x devtmpfs -x efivarfs --total | tail -n 1 | awk '{print $5}')

# CPU load
read -r _ u1 n1 s1 idle1 io1 irq1 soft1 steal1 rest < /proc/stat

sleep 1

read -r _ u2 n2 s2 idle2 io2 irq2 soft2 steal2 rest < /proc/stat

total1=$((u1+n1+s1+idle1+io1+irq1+soft1+steal1))
total2=$((u2+n2+s2+idle2+io2+irq2+soft2+steal2))

delta_total=$((total2-total1))
delta_idle=$((idle2+io2-idle1-io1))

cpu_load=$(awk -v total="$delta_total" -v idle="$delta_idle" \
'BEGIN {
    if (total > 0)
        printf "%.1f", 100 * (total - idle) / total
    else
        printf "0.0"
}')

echo "=== Born2BeRoot Monitoring ==="
echo "Architecture: $arch"
echo "Physical CPUs: $pcpu"
echo "Virtual CPUs: $vcpu"
echo "RAM: ${ram_used}/${ram_total}MB (${ram_percent}%)"
echo "Disk: ${disk_used}/${disk_total} (${disk_percent})"
echo "CPU Load: ${cpu_load}%"

# Last boot
last_boot=$(uptime -s)

# LVM
if lsblk -o TYPE | grep -q lvm; then
    lvm="yes"
else
    lvm="no"
fi

# TCP connections
tcp=$(ss -tan | awk '$1 == "ESTAB" {n++} END {print n+0}')

# Logged-in users
users=$(who | awk '{print $1}' | sort -u | wc -l)

# Network
interface=$(ip -4 route show default | awk '{print $5; exit}')

if [ -n "$interface" ]; then
    ip_addr=$(ip -4 -o addr show dev "$interface" | awk '{print $4}' | cut -d/ -f1)
    mac_addr=$(cat "/sys/class/net/$interface/address")
else
    ip_addr="N/A"
    mac_addr="N/A"
fi

# Sudo command count
sudo_count=$(grep -c 'COMMAND=' /var/log/sudo/sudo.log 2>/dev/null || true)
sudo_count=${sudo_count:-0}

echo "Last boot: $last_boot"
echo "LVM: $lvm"
echo "TCP Connections: $tcp ESTABLISHED"
echo "Users: $users"
echo "IP Address: $ip_addr"
echo "MAC Address: $mac_addr"
echo "Sudo Commands: $sudo_count"
