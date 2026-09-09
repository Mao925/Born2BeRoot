*This project has been created as part of the 42 curriculum by mhashimo.*

# Born2beRoot

42 Born2beRootのレビュー・提出準備用リポジトリです。VirtualBox上にGUIなしのDebianサーバーを構築し、仮想化、LUKS/LVM、ユーザー管理、SSH、UFW、sudo、AppArmor、cronを実践します。

## Current status

- 要件PDFとDESIGN.mdを確認済み
- README、レビュー用チェックリスト、VM検証スクリプト、monitoring.sh、レビュイー向け解説を追加済み
- 実VM上の設定検証は未実施
- 実VMの停止後にしか作れない signature.txt は未生成

実VMを確認できない状態でsignatureを捏造していません。VMの最終検証後、README末尾の手順で作成してください。

## File structure

~~~text
.
├── Born2beRoot.pdf
├── DESIGN.md
├── README.md
├── docs/
│   ├── DEFENSE_GUIDE.md
│   └── REVIEW_CHECKLIST.md
├── scripts/
│   └── verify_vm.sh
├── src/
│   └── monitoring.sh
├── .gitignore
└── signature.txt.example
~~~

仮想ディスク、ISO、OVA、ログなどは.gitignoreで除外します。42の提出物として必要なsignature.txtは、実VMのディスクから取得した後に別途追加します。

## Description

### Required configuration

- Debian latest stable、GUIなし
- LUKS暗号化コンテナ内のLVM
- 複数のlogical volume
- SSHはTCP 4242、rootのSSHログインは禁止
- UFWは有効、受信許可は4242/TCPのみ
- hostnameはmhashimo42
- mhashimoユーザーはuser42とsudoに所属
- パスワード有効期限・強度ポリシー
- sudoの3回制限、独自失敗メッセージ、I/Oログ、TTY、secure_path
- AppArmorは起動時から有効
- monitoring.shを起動時と10分ごとにcron実行し、wallで全端末に表示

### Chosen design

| 項目 | 採用 | 理由 |
| --- | --- | --- |
| 仮想化 | VirtualBox | 課題指定で評価者も確認しやすい |
| OS | Debian stable | apt、UFW、AppArmorを利用できる |
| storage | LUKS + LVM | 暗号化と論理ボリューム管理を分離できる |
| remote access | OpenSSH / 4242 | rootを直接公開せず管理できる |
| firewall | UFW | Debianでルールを簡潔に管理できる |
| scheduler | cron + wall | 課題の10分間隔・全端末表示に対応 |

### Storage model

~~~text
virtual disk
├── /boot                  # 起動用。通常は暗号化の外側
└── LUKS container
    └── LVM volume group
        ├── root -> /
        ├── home -> /home
        ├── var -> /var
        ├── log -> /var/log
        ├── tmp -> /tmp
        └── swap -> swap
~~~

LUKSは暗号化、LVMは容量プールとlogical volumeの管理です。評価ではlsblk -fでcrypto_LUKS、LVM、filesystem、mount pointを順に示します。

## Instructions

### VMへの配置

VM上でリポジトリを取得し、次を実行します。

~~~bash
sudo install -o root -g root -m 700 src/monitoring.sh /usr/local/bin/monitoring.sh
sudo install -o root -g root -m 700 scripts/verify_vm.sh /usr/local/sbin/verify_born2beroot.sh
sudo /usr/local/sbin/verify_born2beroot.sh
sudo /usr/local/bin/monitoring.sh
~~~

スクリプトの値が空の場合は、取得元コマンドを単体で確認します。monitoring.shは最終的にrootのcronから実行します。

### cron

/etc/crontabに次を追加します。

~~~cron
@reboot root /usr/local/bin/monitoring.sh
*/10 * * * * root /usr/local/bin/monitoring.sh
~~~

~~~bash
sudo systemctl enable --now cron
sudo systemctl restart cron
~~~

評価者から停止を求められた場合はmonitoring.shを変更・削除せず、cronエントリをコメントアウトしてcronを再起動します。

### SSH

現在の接続を閉じる前に、別端末から確認します。

~~~bash
ssh -p 4242 mhashimo@<VMのIPアドレス>
ssh -p 4242 root@<VMのIPアドレス>
~~~

一般ユーザーは接続でき、rootは拒否される必要があります。

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
| password quality | pwquality.conf、PAM | 10文字・3文字種等 |
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
- https://www.debian.org/releases/stable/amd64/
- https://man.openbsd.org/sshd_config
- https://manpages.debian.org/stable/ufw/ufw.8.en.html
- https://man7.org/linux/man-pages/man8/cryptsetup.8.html
- https://man7.org/linux/man-pages/man8/lvm.8.html
- https://man7.org/linux/man-pages/man5/crontab.5.html
- https://man7.org/linux/man-pages/man5/sudoers.5.html

## AI usage

AIは、要件の整理、レビュー観点の分類、文章の推敲、シェルスクリプトのレビュー補助に使用しています。VMの構築、設定適用、実行結果の確認、評価時の説明は自分で行います。

## Signature

VMを完全に停止した後、仮想ディスクのSHA-1を計算します。VMを起動・変更したら再取得が必要です。

~~~bash
# Linux
sha1sum "$HOME/VirtualBox VMs/<VM名>/<VM名>.vdi"

# macOS
shasum "$HOME/VirtualBox VMs/<VM名>/<VM名>.vdi"
~~~

出力の40桁のハッシュ値だけをsignature.txtに保存してください。現在は実VMがこの環境にないため、signature.txtは未生成です。
