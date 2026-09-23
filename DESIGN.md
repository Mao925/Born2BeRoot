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

## 最終検証の経過

追加検証で、テストユーザーのSSH接続・削除、数字を含まないパスワードの拒否、sudoの3回失敗制限、sudo I/Oログ、VirtualBoxコンソールへの10分ごとのcron配信を確認しました。GUIの網羅的な不在、SSH端末へのwall配信（未解決）、評価開始時のスナップショット状態と私用Macを使う評価運用は、なお確認事項です。

2026-09-24にVMを完全停止し、Mac上のBorn2BeRoot-Manual.vdiで取得したSHA-1をsubmit/signature.txtへ反映しました。VMを再起動・変更した場合は必ず再計算してください。

scripts/monitoring.shは元々共有された端末の表示から転記されたものでしたが、その後ユーザーがVMのオリジナルをscpで取得してGitHubへpushしたと報告しています。
