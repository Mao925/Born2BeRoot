#!/usr/bin/env bash
# Born2beRoot monitoring script.
# Install as /usr/local/bin/monitoring.sh and run it as root.
set -u

architecture=$(uname -a)

physical_cpu=$(awk -F: '
  /^physical id/ { id=$2; gsub(/[[:space:]]/, "", id); seen[id]=1 }
  END { n=0; for (id in seen) n++; if (n == 0) n=1; print n }
' /proc/cpuinfo)

virtual_cpu=$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN)

read_cpu() {
  read -r _ user nice system idle iowait irq softirq steal _ _ < /proc/stat
  idle=$((idle + iowait))
  total=$((user + nice + system + idle + irq + softirq + steal))
  printf '%s %s\n' "$total" "$idle"
}

read -r total1 idle1 <<EOF
$(read_cpu)
EOF
sleep 1
read -r total2 idle2 <<EOF
$(read_cpu)
EOF

cpu_load=$(awk -v t1="$total1" -v t2="$total2" -v i1="$idle1" -v i2="$idle2" 'BEGIN {
  dt=t2-t1; di=i2-i1
  if (dt <= 0) printf "0.0"; else printf "%.1f", (1-di/dt)*100
}')

read -r memory_used memory_total memory_available memory_pct <<EOF
$(free -m | awk '/^Mem:/ {
  used=$3; total=$2; available=$7; pct=(total > 0 ? used/total*100 : 0)
  printf "%s %s %s %.2f\n", used, total, available, pct
}')
EOF

read -r disk_used disk_total disk_available disk_pct <<EOF
$(df -P -B1 -x tmpfs -x devtmpfs 2>/dev/null | awk '
  NR > 1 { used += $3; total += $2 }
  END { available=total-used; pct=(total > 0 ? used/total*100 : 0)
    printf "%d %d %d %.2f\n", used, total, available, pct
}')
EOF

last_boot=$(who -b 2>/dev/null | awk '{print $3 " " $4}')
[ -n "$last_boot" ] || last_boot=$(uptime -s 2>/dev/null || echo unknown)

if lsblk -nr -o TYPE 2>/dev/null | grep -qx lvm; then lvm_use=yes; else lvm_use=no; fi
tcp_connections=$(ss -Htan state ESTABLISHED 2>/dev/null | wc -l)
logged_users=$(who 2>/dev/null | wc -l)

interface=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
ipv4_address=""
mac_address=""
if [ -n "$interface" ]; then
  ipv4_address=$(ip -4 -o addr show dev "$interface" scope global 2>/dev/null | awk '{print $4; exit}' | cut -d/ -f1)
  mac_address=$(cat "/sys/class/net/$interface/address" 2>/dev/null || true)
fi
[ -n "$ipv4_address" ] || ipv4_address=unknown
[ -n "$mac_address" ] || mac_address=unknown

sudo_count=0
if [ -r /var/log/auth.log ]; then
  sudo_count=$(grep -hE 'sudo(\[[0-9]+\])?:.*COMMAND=' /var/log/auth.log* 2>/dev/null | wc -l)
fi
if [ "$sudo_count" -eq 0 ]; then
  sudo_count=$(journalctl --no-pager 2>/dev/null | grep -cE 'sudo(\[[0-9]+\])?:.*COMMAND=' || true)
fi

wall <<EOF
#Architecture: $architecture
#CPU physical : $physical_cpu
#vCPU : $virtual_cpu
#Memory Usage: ${memory_used}MB/${memory_total}MB (available: ${memory_available}MB, ${memory_pct}%)
#Disk Usage: $((disk_used / 1024 / 1024))MB/$((disk_total / 1024 / 1024))MB (available: $((disk_available / 1024 / 1024))MB, ${disk_pct}%)
#CPU load: ${cpu_load}%
#Last boot: $last_boot
#LVM use: $lvm_use
#Connections TCP : ${tcp_connections} ESTABLISHED
#User log: $logged_users
#Network: IP $ipv4_address ($mac_address)
#Sudo : ${sudo_count} cmd
EOF
