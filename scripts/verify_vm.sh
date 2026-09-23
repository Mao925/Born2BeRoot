#!/usr/bin/env bash
# Read-only PARTIAL checks: interactive requirements and signature still require manual verification.
# Run as root or with sudo. This script does not modify the VM.
set -u

pass=0
warn=0
fail=0

ok() { printf '[PASS] %s\n' "$1"; pass=$((pass + 1)); }
warning() { printf '[WARN] %s\n' "$1"; warn=$((warn + 1)); }
bad() { printf '[FAIL] %s\n' "$1"; fail=$((fail + 1)); }
section() { printf '\n== %s ==\n' "$1"; }

section "Identity"
hostname_now=$(hostname 2>/dev/null || true)
[ "$hostname_now" = "mhashimo42" ] && ok "hostname is mhashimo42" || bad "hostname is $hostname_now"

getent passwd mhashimo >/dev/null 2>&1 && ok "user mhashimo exists" || bad "user mhashimo is missing"
groups_now=$(id -nG mhashimo 2>/dev/null || true)
case " $groups_now " in *" user42 "*) ok "mhashimo belongs to user42";; *) bad "mhashimo is not in user42";; esac
case " $groups_now " in *" sudo "*) ok "mhashimo belongs to sudo";; *) bad "mhashimo is not in sudo";; esac

section "Operating system"
[ -f /etc/os-release ] && grep -q '^ID=debian$' /etc/os-release && ok "Debian detected" || bad "Debian not detected"
default_target=$(systemctl get-default 2>/dev/null || true)
[ "$default_target" != "graphical.target" ] && ok "non-graphical target: $default_target" || bad "graphical.target is enabled"
if dpkg-query -W -f='${Status}\n' task-desktop 2>/dev/null | grep -q 'install ok installed'; then
  bad "task-desktop is installed"
else
  ok "task-desktop is not installed"
fi

section "Storage"
lsblk -f 2>/dev/null | grep -q 'crypto_LUKS' && ok "crypto_LUKS detected" || bad "crypto_LUKS not detected"
lvm_count=$(lsblk -nr -o TYPE 2>/dev/null | awk '$1 == "lvm" {n++} END {print n + 0}')
[ "$lvm_count" -ge 2 ] && ok "at least two LVs detected: $lvm_count" || bad "fewer than two LVs detected: $lvm_count"
swapon --show --noheadings 2>/dev/null | grep -q . && ok "swap is active" || warning "swap is not active"

section "Services"
for service in ssh ufw cron apparmor; do
  enabled=$(systemctl is-enabled "$service" 2>/dev/null || true)
  active=$(systemctl is-active "$service" 2>/dev/null || true)
  [ "$enabled" = "enabled" ] && ok "$service is enabled" || warning "$service enabled state: $enabled"
  [ "$active" = "active" ] && ok "$service is active" || bad "$service active state: $active"
done

section "SSH"
ssh_port=$(sshd -T 2>/dev/null | awk '$1 == "port" {print $2; exit}')
[ "$ssh_port" = "4242" ] && ok "effective SSH port is 4242" || bad "effective SSH port is $ssh_port"
root_login=$(sshd -T 2>/dev/null | awk '$1 == "permitrootlogin" {print $2; exit}')
[ "$root_login" = "no" ] && ok "root SSH login is disabled" || bad "permitrootlogin is $root_login"
ss -ltn 2>/dev/null | awk '$4 ~ /:4242$/ {found=1} END {exit found ? 0 : 1}' && ok "TCP 4242 is listening" || bad "TCP 4242 is not listening"

section "Firewall"
ufw_status=$(ufw status 2>/dev/null | head -n 1 || true)
[ "$ufw_status" = "Status: active" ] && ok "UFW is active" || bad "UFW status: $ufw_status"
ufw status 2>/dev/null | grep -Eq '(^|[[:space:]])4242(/tcp)?[[:space:]]+ALLOW' && ok "UFW allows 4242" || bad "UFW 4242 rule missing"
ufw status 2>/dev/null | grep -Eq '(^|[[:space:]])22(/tcp)?[[:space:]]+ALLOW' && bad "UFW still allows 22" || ok "UFW does not allow 22"

section "AppArmor"
if command -v aa-status >/dev/null 2>&1; then
  aa-status 2>/dev/null | grep -q 'apparmor module is loaded' && ok "AppArmor module is loaded" || warning "AppArmor load state needs manual review"
else
  bad "aa-status is missing"
fi

section "Password policy"
for key in PASS_MAX_DAYS PASS_MIN_DAYS PASS_WARN_AGE; do
  value=$(awk -v key="$key" '$1 == key {print $2; exit}' /etc/login.defs 2>/dev/null || true)
  case "$key:$value" in
    PASS_MAX_DAYS:30|PASS_MIN_DAYS:2|PASS_WARN_AGE:7) ok "$key=$value";;
    *) bad "$key=$value";;
  esac
done
for key in minlen ucredit lcredit dcredit maxrepeat usercheck difok; do
  value=$(awk -F= -v key="$key" '$1 ~ "^[[:space:]]*" key "[[:space:]]*$" {gsub(/[[:space:]]/, "", $2); print $2; exit}' /etc/security/pwquality.conf 2>/dev/null || true)
  [ -n "$value" ] && ok "pwquality defines $key=$value" || warning "pwquality does not define $key"
done
grep -Eq 'pam_pwquality\.so' /etc/pam.d/common-password 2>/dev/null && ok "pam_pwquality is active" || bad "pam_pwquality is not in common-password"

section "Sudo"
visudo -c >/dev/null 2>&1 && ok "sudoers syntax is valid" || bad "sudoers syntax check failed"
sudo_policy=/etc/sudoers.d/born2beroot
[ -f "$sudo_policy" ] && ok "$sudo_policy exists" || bad "$sudo_policy is missing"
if [ -f "$sudo_policy" ]; then
  mode=$(stat -c '%a' "$sudo_policy" 2>/dev/null || true)
  [ "$mode" = "440" ] && ok "$sudo_policy mode is 440" || warning "$sudo_policy mode is $mode"
fi
for key in passwd_tries badpass_message log_input log_output iolog_dir requiretty secure_path; do
  grep -Rqs "$key" /etc/sudoers /etc/sudoers.d 2>/dev/null && ok "sudo policy contains $key" || warning "sudo policy needs review: $key"
done

section "Monitoring"
monitor=/usr/local/bin/monitoring.sh
[ -x "$monitor" ] && ok "monitoring.sh is executable" || bad "monitoring.sh is missing or not executable"
if crontab -l 2>/dev/null | grep -Eq '^[^#].*/usr/local/bin/monitoring\.sh'; then
  ok "monitoring.sh is active in /etc/crontab"
else
  warning "active monitoring cron entry not found"
fi

section "Summary"
printf 'PASS=%s WARN=%s FAIL=%s\n' "$pass" "$warn" "$fail"
[ "$fail" -eq 0 ]
