*This project has been created as part of the 42 curriculum by mhashimo.*

# Born2beRoot

VirtualBoxを私用Macで使用し、Debian 13 ARM64の仮想サーバーを構築しました。端末で確認した実環境を以下に記録します。

## Verification status

This README describes the VM shown in terminal output on 2026-09-24. It does **not** claim that every interactive evaluation requirement has passed.

The accompanying signature.txt records the SHA-1 reported from the fully powered-off Born2BeRoot-Manual.vdi on 2026-09-24. If the VM disk is changed or booted again, shut it down fully and recompute the signature.

The submission consists only of this README.md and signature.txt, at the root of the **separate 42 submission repository**. Other learning materials live in the working GitHub repository.

## Description

### Required configuration

- Debian 13 ARM64、CUI起動。検査したGUI関連パッケージは見つからず、display-manager.serviceも存在しない（網羅的な不在は評価時にも確認）
- LUKS2内のLVM（root/home/swap）
- 複数のlogical volume
- SSHはTCP 4242、rootのSSHログインは禁止
- UFWは有効、受信許可は4242/TCPのみ
- hostnameはmhashimo42
- mhashimoユーザーはuser42とsudoに所属
- パスワード有効期限・強度ポリシー（数字不足の拒否動作を確認）
- sudoの3回制限、独自失敗メッセージ、I/Oログ、TTY、secure_path
- AppArmorは起動時から有効
- rootのcronで@rebootと10分ごとにmonitoring.shをwallへパイプ

### Chosen design

| 項目 | 採用 | 理由 |
| --- | --- | --- |
| 仮想化 | VirtualBox | 課題指定で評価者も確認しやすい |
| OS | Debian stable | apt、UFW、AppArmorを利用できる |
| storage | LUKS + LVM | 暗号化と論理ボリューム管理を分離できる |
| remote access | OpenSSH / 4242 | rootを直接公開せず管理できる |
| firewall | UFW | Debianでルールを簡潔に管理できる |
| scheduler | cron + wall | 課題の10分間隔・全端末表示に対応 |

### Storage model (observed VM)

~~~text
EFI -> /boot/efi
/boot
LUKS2 -> mhashimo-vg -> root (/), home (/home), swap
~~~

当初想定していた/var、/var/log、/tmpの個別LVは実際には作成していません。

## Instructions

### 実際のVMへの接続と監視

VirtualBoxでVMを起動しLUKSを解除してください。NATの4242転送設定があるMacからは次でSSH接続できます。

~~~bash
ssh -p 4242 mhashimo@localhost
~~~

VMにある監視スクリプトは標準出力へ表示し、rootのcrontabがwallへパイプしています。

~~~bash
sudo /usr/local/bin/monitoring.sh
sudo crontab -l
~~~

~~~cron
@reboot /usr/local/bin/monitoring.sh | /usr/bin/wall
*/10 * * * * /usr/local/bin/monitoring.sh | /usr/bin/wall
~~~

VM内のsudo設定ファイルは /etc/sudoers.d/born2beroot、コマンドログは /var/log/sudo/sudo.log です。cronによる10分ごとのVirtualBoxコンソールへの表示は確認済みです。一方、Debian 13のSSH端末へのwall配信は未解決で、全端末に届くことまでは確認できていません。

## Acceptance matrix

| 要件 | コマンド | 期待値 |
| --- | --- | --- |
| GUIなし | systemctl get-default、パッケージ確認 | graphical.targetでない |
| hostname | hostnamectl | mhashimo42 |
| groups | id mhashimo | user42とsudo |
| LUKS/LVM | lsblk -f | crypto_LUKS配下に複数LV |
| SSH | sshd -T、ss -ltnp | port 4242、PermitRootLogin no |
| UFW | ufw status verbose | active、受信は4242のみ |
| AppArmor | aa-status | module loaded |
| aging | chage -l | 30 / 2 / 7 |
| password quality | pwquality.conf、PAM | 10文字以上、大文字・小文字・数字必須等 |
| sudo | visudo -c、実演 | 3回、メッセージ、I/Oログ、TTY、secure_path |
| monitoring | 手動実行、cron | 12項目、起動時・10分ごと |
| signature | VM完全停止後のSHA-1 | 40桁のみ |

## Comparisons

| 比較 | Debian / 採用 | Rocky Linux |
| --- | --- | --- |
| package manager | apt / aptitude | dnf |
| MAC | AppArmor | SELinux |
| firewall | UFW | firewalld |
| 課題上の設定 | UFWとAppArmor | firewalldとSELinux |

AppArmorはパス中心のプロファイル、SELinuxはラベルとポリシー中心です。UFWはiptables/nftablesのフロントエンド、firewalldはゾーン・サービス単位の管理です。VirtualBoxは課題指定の標準選択肢で、UTMはmacOS/Apple SiliconでQEMUを使う選択肢です。

## Resources

- https://www.debian.org/
- https://www.debian.org/releases/stable/
- https://man.openbsd.org/sshd_config
- https://manpages.debian.org/stable/ufw/ufw.8.en.html
- https://man7.org/linux/man-pages/man8/cryptsetup.8.html
- https://man7.org/linux/man-pages/man8/lvm.8.html
- https://man7.org/linux/man-pages/man5/crontab.5.html
- https://man7.org/linux/man-pages/man5/sudoers.5.html

## AI usage

AIは、要件の整理、レビュー観点の分類、文章の推敲、シェルスクリプトのレビュー補助に使用しています。VMの構築、設定適用、実行結果の確認、評価時の説明は自分で行います。

## Signature

2026-09-24、VirtualBoxで電源オフを確認後、Mac上で実際のBorn2BeRoot-Manual.vdiに対してshasum -a 1を実行し、得られた40桁の値をsignature.txtへ保存しました。**以後VMを起動・変更した場合は再度完全停止してハッシュを更新してください。**
