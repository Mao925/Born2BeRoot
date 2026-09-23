# Born2beRoot — 実際のVMの構築記録

以下は2026-09-24にユーザーが共有したVMのSSH出力に基づく情報です。旧DESIGN.mdの仮想設計ではありません。

| 項目 | 実VMで確認した状態 |
| --- | --- |
| 仮想化・OS | VirtualBox（私用Mac）、Debian 13 ARM64 |
| hostname / user | mhashimo42 / mhashimo（sudo、user42所属） |
| Disk | EFI、/boot、LUKS2 → LVM root(/)、home(/home)、swap |
| SSH | 4242、PermitRootLogin no |
| UFW | active、incoming deny、4242/tcpのみ表示 |
| AppArmor/SSH/UFW/cron | 再起動後、enabled/active |
| Boot | multi-user.target |
| password | rootとmhashimoは30/2/7日、pam_pwqualityの設定値を確認 |
| sudo | /etc/sudoers.d/born2beroot、ログ /var/log/sudo/sudo.log |
| monitoring | VMの/usr/local/bin/monitoring.shはstdout出力、rootのcronがwallへパイプ |
| root cron | @reboot および */10 * * * * |

旧設計にあった/var、/var/log、/tmp等の別LVは実VMで確認されていないため、作成済みと記載しません。

## 残る検証

GUIの網羅的な不在、SSHの新規ユーザー実演、パスワード強制、sudoの3回制限とI/Oログ、10分ごとのwall配信、評価時スナップショット、完全停止後のディスクSHA-1一致。現在のsubmit/signature.txtは古いハッシュの暫定コピーであり、最終提出に使わないでください。

scripts/monitoring.shは共有された端末の表示から転記したものです。VMファイルとのバイト単位の一致は未検証です。
