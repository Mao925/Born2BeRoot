# Born2beRoot — 実際のVMの構築記録

以下は2026-09-30に学内のx86_64端末上で再構築し、実VMで確認した情報です。

| 項目 | 実VMで確認した状態 |
| --- | --- |
| 仮想化・OS | VirtualBox 7.0.26（学内x86_64ホスト）、Debian 13 AMD64 |
| hostname / user | mhashimo42 / mhashimo（sudo、user42所属） |
| Disk | EFI、/boot、LUKS2 → LVM root(/)、home(/home)、swap |
| SSH | 4242、PermitRootLogin no |
| UFW | active、incoming deny、4242/tcpのみ表示 |
| AppArmor/SSH/UFW/cron | 再起動後、enabled/active |
| Boot | multi-user.target |
| password | rootとmhashimoは30/2/7日、pam_pwqualityの設定値と不適合パスワードの拒否を確認 |
| sudo | /etc/sudoers.d/born2beroot、ログ /var/log/sudo/sudo.log |
| monitoring | VMの/usr/local/bin/monitoring.shはstdout出力、rootのcronがwallへパイプ |
| root cron | @reboot および */10 * * * * |

旧設計にあった/var、/var/log、/tmp等の別LVは実VMで確認されていないため、作成済みと記載しません。

## 最終検証の経過

再起動後にSSH・UFW・cron・AppArmorがenabled/activeであること、4242/TCPのSSH接続とrootログイン拒否、sudoの3回失敗制限・独自メッセージ・I/Oログ、不適合パスワードの拒否を確認しました。複数のSSH端末への手動 `wall` 配信と、cronの起動時および00・10・20分の実行履歴も確認済みです。デスクトップtaskと主なGUIパッケージは不在で、起動ターゲットは `multi-user.target` です。

2026-09-30にスナップショットがないことを確認し、VMを完全停止して `/sgoinfre/mhashimo/Born2BeRoot-x86/Born2BeRoot-amd64/Born2BeRoot-amd64.vdi` から取得したSHA-1を `submit/signature.txt` へ反映しました。VMを再起動・変更した場合は必ず再計算してください。

`scripts/monitoring.sh` をscpでVMへ転送し、root所有・0755で `/usr/local/bin/monitoring.sh` へ配置しました。
