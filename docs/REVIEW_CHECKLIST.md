> 実VMに合わせた確認: root/home/swap、sudoers.d/born2beroot、root crontab、sudo.log、最終署名を参照してください。

# Review checklist

Born2beRootの評価前にVM上で実行する確認手順。出力の意味を説明できることを合格条件にする。

## Safety

- VMコンソールを復旧経路として残す。
- SSH設定はsshd -t、sudo設定はvisudo -cで検証してから再起動する。
- 4242を許可してからUFWを有効化する。
- passwordとLUKS passphraseをリポジトリに保存しない。
- signature取得後はVMを起動しない。

## Basic system

~~~bash
hostnamectl
cat /etc/hostname
cat /etc/hosts
cat /etc/os-release
systemctl get-default
~~~

確認:

- hostnameはmhashimo42
- Debian stable
- graphical.targetではない
- デスクトップ環境、X.org、Waylandを導入していない

## Storage

~~~bash
lsblk
lsblk -f
findmnt /
findmnt /home
findmnt /var
swapon --show
~~~

確認:

- crypto_LUKSがある
- その下に複数のLVM logical volumeがある
- mount pointが意図どおり
- swapが有効

説明:

- /bootは通常GRUBが読むためLUKSの外側
- LUKSは暗号化、LVMはlogical volume管理
- 分離は容量枯渇の影響範囲を小さくし、拡張を柔軟にする

## Users

~~~bash
id mhashimo
getent group user42
getent group sudo
getent passwd mhashimo
~~~

確認:

- mhashimoがuser42とsudoに所属
- 新規ユーザー作成とグループ追加を説明できる

実演例:

~~~bash
sudo adduser reviewer42
sudo usermod -aG user42 reviewer42
id reviewer42
sudo deluser --remove-home reviewer42
~~~

## SSH and UFW

~~~bash
sudo sshd -T | grep -E '^(port|permitrootlogin) '
sudo ss -ltnp
sudo ufw status numbered
sudo ufw status verbose
~~~

確認:

- SSHは4242
- permitrootlogin no
- UFW active
- incoming default deny
- 4242/TCP以外に不要な受信許可がない

別端末からmhashimoの接続成功とrootの接続拒否を確認する。動作するセッションを閉じる前に新しい接続を確認する。

## Password policy

~~~bash
grep -E '^(PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_WARN_AGE)' /etc/login.defs
sudo chage -l mhashimo
sudo chage -l root
grep -E '^(minlen|ucredit|lcredit|dcredit|maxrepeat|usercheck|difok)' /etc/security/pwquality.conf
grep -n pam_pwquality /etc/pam.d/common-password
~~~

期待値:

- max 30 days
- minimum 2 days
- warning 7 days
- minimum length 10
- uppercase、lowercase、digitが各1以上
- 同一文字4連続を禁止
- usernameを含めない
- difok=7は非rootで確認

実際のpasswordは見せず、無効な候補と有効な候補の結果だけを説明する。

## sudo

~~~bash
sudo visudo -c
sudo stat -c '%A %U:%G %n' /etc/sudoers.d/born2beroot
sudo grep -R -E 'passwd_tries|badpass_message|log_input|log_output|iolog_dir|requiretty|secure_path' /etc/sudoers /etc/sudoers.d
sudo -k
sudo -l
sudo find /var/log/sudo -maxdepth 2 -type f -print
~~~

確認:

- sudoers syntaxがvalid
- policy fileはroot所有・一般ユーザー書き込み不可
- password試行は3回
- 独自メッセージが表示される
- I/Oログが/var/log/sudo/に生成される
- TTYとsecure_pathが設定されている

## AppArmor and services

~~~bash
systemctl is-enabled apparmor ssh ufw cron
systemctl is-active apparmor ssh ufw cron
sudo aa-status
~~~

AppArmor、SSH、UFW、cronが起動時有効かつactiveであることを確認する。

## Monitoring

~~~bash
sudo /usr/local/bin/monitoring.sh
sudo crontab -l
sudo stat -c '%A %U:%G %n' /usr/local/bin/monitoring.sh
~~~

以下の12項目が空欄なく表示されることを確認する。

1. architecture and kernel version
2. physical processors
3. virtual processors
4. available/used RAM and rate
5. available/used storage and rate
6. CPU utilization
7. last reboot
8. LVM status
9. established TCP connections
10. logged-in users
11. IPv4 and MAC address
12. sudo command count

「スクリプトを変更せず停止」では、cron行だけをコメントアウトする。

## Signature

1. VMを完全停止する。
2. 必要ならsnapshotを削除する。
3. 対象の仮想ディスクをSHA-1計算する。
4. 40桁のhex digestだけをsignature.txtに書く。
5. その後VMを起動しない。

~~~bash
grep -Eq '^[0-9a-fA-F]{40}
~~~
 submit/signature.txt
~~~
