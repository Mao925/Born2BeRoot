*This project has been created as part of the 42 curriculum by mhashimo.*

# Born2beRoot

## Description

VirtualBox上にDebian 13 ARM64の仮想サーバーを構築し、暗号化ディスク、ユーザー・権限管理、SSH、ファイアウォール、定期監視を設定するシステム管理の課題です。GUIを使わず、設定の意味と動作を説明できることを目標とします。

提出物は、この `README.md` と `signature.txt` を**提出リポジトリのルート**に置いたものです。VM本体はGitに含めません。このREADMEだけで評価手順を追えるよう、下に実演コマンドと期待結果を記載しています。

### 確認状況

構成情報は2026-09-24の実VMの確認記録に基づきます。テストユーザーのSSH接続、数字なしパスワードの拒否、sudoの3回失敗制限とI/Oログ、VirtualBoxコンソールへの10分ごとの通知が確認されています。**SSH端末へのwall配信は未解決**であり、全端末への表示は未確認です。GUIの網羅的な不在と評価開始時のスナップショット状態も確認が必要です。**私用Macを評価端末として使えるかは未確認であり、評価予約前にキャンパスのスタッフへ確認します。**

`signature.txt` は2026-09-24に完全停止した `Born2BeRoot-Manual.vdi` のSHA-1です。以後原本を起動・変更していれば、提出前に完全停止して再計算する必要があります。以下の手順を記載したことは、すべての実演に合格したことを意味しません。

## Project description

### OSの選択と比較：Debian vs Rocky Linux

Debianを選んだ理由は、課題が初学者向けに推奨しており、APT・UFW・AppArmorを使って基本的なサーバー管理を学べるためです。

| 比較軸 | Debian（採用） | Rocky Linux |
| --- | --- | --- |
| 系統・管理 | Debian系、dpkg・APT、`.deb` | RHEL互換、RPM・DNF、`.rpm` |
| 長所 | stableの安定性、豊富なパッケージと資料 | RHEL互換の運用・企業向け環境を学べる |
| 短所・負担 | 安定性重視のため最新機能が必要な用途に合わない場合がある | 初学者にはSELinuxやfirewalldの設定も含め学習負担がある |
| この課題での保護機構 | AppArmor・UFW | SELinux・firewalld |

### 主な設計上の選択

| 項目 | 実VMの構成と目的 |
| --- | --- |
| 仮想化・起動 | VirtualBox、CUIで管理するDebian 13 ARM64 |
| パーティション | EFI、`/boot`、LUKS2内のLVM root/home/swap。暗号化と容量管理を組み合わせる |
| ユーザー管理 | rootとは別に `mhashimo` を作成し、`user42`・`sudo` に所属 |
| ホスト名 | `mhashimo42` |
| パスワード | 有効期限30日、変更間隔2日、警告7日前、PAMによる品質検査 |
| 権限昇格 | sudo、認証3回制限、独自エラー、入出力ログ、TTY、探索パス制限 |
| リモート管理 | OpenSSH、4242/TCP、rootのSSHログイン禁止 |
| ネットワーク制御 | UFW、受信は既定で拒否、許可は4242/TCP |
| プロセス制御 | 起動時からAppArmorを有効化 |
| 監視 | Bashの `monitoring.sh`、rootのcronとwallによる起動時・10分ごとの配信 |

```text
ディスク
├── EFI → /boot/efi
├── /boot
└── LUKS2 → LVM (mhashimo-vg)
             ├── root → /
             ├── home → /home
             └── swap
```

rootとhomeを分けて容量消費を分離します。ボーナス例の `/var`・`/srv`・`/tmp`・`/var/log` の個別LVは作成していません。

### AppArmor vs SELinux

どちらも通常のユーザー・グループ権限に加え、ポリシーで操作を制限する強制アクセス制御です。AppArmorはプログラムのパスを中心とするプロファイルで管理し、個別プログラムの制限を追いやすい点が利点です。SELinuxは主にラベルとポリシーで制御し、詳細な制御ができる一方、ラベルと許可関係の理解が必要です。このVMはDebianのAppArmorを採用しています。

### UFW vs firewalld

どちらもLinuxのパケットフィルタを管理するツールです。UFWはポートや接続元に対する許可・拒否を簡潔に記述でき、この課題の少数のルールに適しています。firewalldはゾーンとサービス単位の管理ができ、ネットワークごとに方針を分ける用途に向きますが、その概念とruntime/permanent設定の区別が必要です。このVMはUFWを採用しています。

### VirtualBox vs UTM

VirtualBoxは複数のホストOSに対応した仮想化ソフトウェアで、VM・ネットワーク・スナップショットをGUIで管理できます。UTMはmacOS向けで、QEMUやAppleの仮想化機能を利用します。異なるCPUアーキテクチャのエミュレーションも選べますが、実行方式によって速度や機能が異なります。いずれもホストとゲストのCPU対応を確認する必要があります。課題はVirtualBoxを基本とし、利用できない場合にUTMを認めているため、この構成はVirtualBoxを採用しました。

## Instructions

コンパイルは不要です。キャンパスが認める評価端末で、構築済みVMの確認を行います。評価票の `on their station` はGitのクローン先を指定していますが、私用PCを含むかは明記されていません。以下のMacホスト向け手順は現在の構築環境での操作例であり、私用Macでの受験が許可されているという意味ではありません。署名照合・VMの起動と再起動・スナップショット確認を同じ私用Macで行ってよいか、事前に確認してください。

以下はDebian用で、**ホスト側**と明記したもの以外はVM内の一般ユーザーから実行します。コードブロックは項目ごとに使い、再起動・対話編集・SSH接続を含む全体を一括実行しないでください。パスワードはプロンプトで入力します。

評価順：署名と起動 → README・概要 → 基本設定 → ユーザー → ホスト名・LVM → sudo → UFW → SSH → 監視 → ボーナス。

### 0. 起動前：正式な提出物・署名・スナップショット

本人立ち会いのもと、学生の端末で正式な提出リポジトリを空のディレクトリへクローンします。ホスト側でエイリアス・関数やGitの設定を確認し、補助スクリプトを使う場合は内容を一緒に読みます。

```sh
# ホスト側。URLを正式な提出先に置き換える。
type -a git shasum diff
alias
git config --show-origin --get-regexp '^alias\.'
git clone 'OFFICIAL_REPOSITORY_URL' born2beroot-evaluation
cd born2beroot-evaluation
git remote -v
ls -la
head -n 1 README.md
cat signature.txt
```

`born2beroot-evaluation` はまだ存在しない名前を使います。Git aliasがなければ `--get-regexp` は出力なし・終了値1となります。remoteのURLと提出者・課題の対応は評価者と確認します。

**ここではVMを起動しません。** VirtualBoxの画面で「電源オフ」（保存状態ではない）とスナップショットなしを確認し、接続されているディスクの実パスを調べます。Macホストで、そのパスに置き換えて比較します。

```sh
VM_DISK='/absolute/path/to/Born2BeRoot-Manual.vdi'
ACTUAL_SIGNATURE=$(mktemp)
shasum -a 1 "$VM_DISK" | awk '{print $1}' > "$ACTUAL_SIGNATURE"
diff -u signature.txt "$ACTUAL_SIGNATURE"
```

期待結果は `diff` の出力なし・終了値0です。不一致なら評価を止め、提出署名を書き換えてその場の照合を通すことはしません。

照合後、停止中の評価用スナップショットを作るか、ディスクを別ディレクトリへ複製してコピーから起動します。コピー方式ではVMがコピーを参照していることを確認します。原本を保護してから起動し、LUKSを解除して `mhashimo` でログインします。評価前から動いていたVMは受け入れないという評価票の条件に従います。

### 1. READMEと概要の説明

冒頭の斜体の作成者行、`Description`、`Project description`、4つの比較、`Instructions`、`Resources` を確認します。口頭ではVMの仕組みと用途、Debianを選んだ理由、Rockyとの違い、aptとaptitudeの違い、AppArmorの役割を説明します。

### 2. 基本設定・サービス

```sh
whoami
id
cat /etc/os-release
uname -m
hostnamectl
systemctl get-default
systemctl status display-manager --no-pager
systemctl is-enabled apparmor ssh ufw cron
systemctl is-active apparmor ssh ufw cron
sudo aa-status
sudo ufw status verbose
dpkg-query -W -f='${binary:Package}\t${db:Status-Status}\n' | grep -Ei 'xserver|xorg|wayland|gdm|lightdm|sddm|task-.*desktop|gnome-shell|plasma-desktop'
```

期待結果：ユーザーはrootではなく `mhashimo`、OSはDebian、ホスト名は `mhashimo42`。CUI起動で、AppArmor・SSH・UFW・cronがenabled/active、UFWはactiveです。display-managerがない場合の「Unit not found」は想定内です。パッケージ一覧は候補抽出であり、共有ライブラリとグラフィックサーバー本体を区別して確認します。`multi-user.target` だけでGUI未導入とは判断しません。

### 3. User step 1：既存ユーザー・新規作成・パスワード

この後の評価では一貫して `reviewer42` を新規ユーザーの例として使います。既に存在する場合は別の未使用名に読み替えてください。削除は全実演が終わるまで行いません。

```sh
id mhashimo
getent group sudo
getent group user42
getent passwd reviewer42
sudo adduser reviewer42
sudo chage -l reviewer42
```

`mhashimo` はsudo/user42の両方に所属すること、新規ユーザーのパスワード設定で要件を満たす候補が受理されることを確認します。作成前の `getent passwd reviewer42` は未使用なら出力なしです。

```sh
grep -E '^(PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_WARN_AGE)' /etc/login.defs
sudo chage -l mhashimo
sudo chage -l root
sudo cat /etc/pam.d/common-password
sudo cat /etc/security/pwquality.conf
sudo find /etc/security/pwquality.conf.d -maxdepth 1 -type f -exec cat {} \;
```

追加設定ディレクトリがなければ最後のコマンドはエラーになります。PAM行と追加設定による上書きも含め、次を確認します。

| 要件 | 確認する値・動作 |
| --- | --- |
| 期限 | 最大30日・最小2日・警告7日前。既存ユーザーとrootにも適用 |
| 最低長 | `minlen=10`、正の文字種creditで実長が短縮されないこと |
| 必須文字種 | `ucredit=-1`、`lcredit=-1`、`dcredit=-1` |
| 同一文字の連続 | `maxrepeat=3`、4連続は拒否 |
| ユーザー名 | `usercheck=1`、名前を含む候補を拒否 |
| 旧パスワードとの差 | `difok=7`、一般ユーザー自身による変更で検証 |
| rootへの品質強制 | `enforce_for_root` が有効で、不適合候補は警告だけでなく拒否 |

設定後にrootを含む既存アカウントのパスワードも変更したことを説明します。数字なし等の拒否テストは評価用ユーザーで行います。最小2日の制限による拒否と品質による拒否を混同しないでください。作成直後に旧新比較を追加検証するなら、評価者と確認したうえでテストユーザーの最終変更日を2日前に調整し、そのユーザーでログインして `passwd` を実行します。`sudo passwd reviewer42` では旧パスワードとの比較になりません。

### 4. User step 2：evaluatingグループ

```sh
getent group evaluating
sudo groupadd evaluating
sudo usermod -aG evaluating reviewer42
id reviewer42
getent group evaluating
```

グループ名が未使用であることを確認して作成し、所属を示します。パスワードポリシーの利点（推測しやすい候補の削減など）と負担（記憶・変更の手間や単純な変更パターンの誘発など）も説明します。

### 5. ホスト名の変更・再起動・パーティション

`EVALUATOR_LOGIN42` を評価者のログイン名に `42` を付けた値へ置き換えます。

```sh
hostnamectl --static
cat /etc/hostname
cat /etc/hosts
sudo hostnamectl set-hostname EVALUATOR_LOGIN42
sudoedit /etc/hosts
```

`/etc/hosts` の `127.0.1.1` などにある `mhashimo42` を新名に合わせ、localhostの行は保持します。その後、再起動します。

```sh
sudo reboot
```

コンソールでLUKSを解除し、再ログインして永続化を確認します。

```sh
hostnamectl --static
cat /etc/hostname
cat /etc/hosts
sudo hostnamectl set-hostname mhashimo42
sudoedit /etc/hosts
```

`/etc/hosts` の名前も `mhashimo42` に戻します。シェルプロンプトは古い名前のままの場合があるため、確認は `hostnamectl` で行います。

```sh
lsblk
lsblk -f
sudo pvs
sudo vgs
sudo lvs
findmnt /
findmnt /home
swapon --show
```

期待結果：暗号化領域の下にLVMのroot/home/swapがあり、`/`・`/home` とswapが利用されています。課題の必須例と構造を比べ、PV→VG→LVと暗号化の役割を説明します。図の容量は例示です。

### 6. SUDO：所属追加・設定・ログ更新

```sh
dpkg-query -W sudo
sudo usermod -aG sudo reviewer42
id reviewer42
sudo visudo -c
sudo cat /etc/sudoers.d/born2beroot
sudo -l
sudo ls -ld /var/log/sudo
sudo find /var/log/sudo -type f -print
```

期待結果：構文が正常で、`passwd_tries=3`、独自 `badpass_message`、`log_input`、`log_output`、`logfile`・`iolog_dir`、`requiretty`、`secure_path` が有効です。保存先は `/var/log/sudo/` 内です。新しいログインセッションではreviewer42もsudoを利用できます。

```sh
sudo tail -n 10 /var/log/sudo/sudo.log
sudo /usr/bin/id
sudo tail -n 10 /var/log/sudo/sudo.log
sudo sudoreplay -d /var/log/sudo -l
```

`id` の結果がrootで、ログに `COMMAND=/usr/bin/id` が追加されていることを確認します。I/Oログの実パスが下位ディレクトリなら、`sudoreplay -d` のパスを `iolog_dir` の値に合わせます。一覧にあるIDを指定して再生します。

```sh
# IDは一覧にある値へ置き換える。
sudo sudoreplay -d /var/log/sudo SESSION_ID
```

3回制限と独自メッセージの確認では、次を実行して意図的に3回誤入力し、実行されず終了することを確認します。認証キャッシュを無効にする `sudo -k` が必要です。

```sh
sudo -k
sudo /usr/bin/true
```

### 7. UFW：4242確認・8080追加・削除

```sh
dpkg-query -W ufw
systemctl is-enabled ufw
systemctl is-active ufw
sudo ufw status verbose
sudo ufw status numbered
sudo ufw allow 8080/tcp
sudo ufw status numbered
sudo ufw delete allow 8080/tcp
sudo ufw status numbered
```

開始時と終了時は4242/TCPだけが受信許可され、途中で8080/TCPのルールが増えることを確認します。IPv6有効時は対応するルールも確認します。8080に実際のサーバーを起動する必要はありません。既存ルールと重なる場合は、今回追加したものを特定して削除します。

### 8. SSH：4242のみ・新規ユーザー・root拒否

```sh
dpkg-query -W openssh-server
systemctl is-enabled ssh
systemctl is-active ssh
sudo /usr/sbin/sshd -t
sudo /usr/sbin/sshd -T | grep -E '^(port|permitrootlogin|passwordauthentication|pubkeyauthentication) '
sudo ss -ltnp
```

期待結果：構文エラーなし、`port 4242`、`permitrootlogin no`。`ss` でSSHプロセスの待受が4242のみで、22等にないことを確認します。IPv4とIPv6で複数行になっていても同一ポートなら構いません。`Match` 条件がある場合は対象ユーザー・接続元に対する実効設定も確認します。

**Macホストの別端末**から接続します。以下はNATでホスト4242→VM4242を転送している場合です。ブリッジ等の場合は `localhost` をVMのIPに置き換えます。

```sh
ssh -p 4242 reviewer42@localhost
```

新規ユーザーのセッション内で確認します。

```sh
whoami
id
sudo -l
exit
```

再びホストからroot接続を試し、拒否を確認します。

```sh
ssh -p 4242 root@localhost
```

正しい接続先に対して一般ユーザーは成功し、rootは拒否されることが必要です。rootの接続失敗だけでなく `PermitRootLogin no` も確認してください。

### 9. 監視：コード・10分周期・動的な値

```sh
sudo cat /usr/local/bin/monitoring.sh
sudo stat -c '%a %U:%G %n' /usr/local/bin/monitoring.sh
sudo /usr/local/bin/monitoring.sh
sudo crontab -l
systemctl is-enabled cron
systemctl is-active cron
```

rootのcrontabの通常設定は次の2行です。

```cron
@reboot /usr/local/bin/monitoring.sh | /usr/bin/wall
*/10 * * * * /usr/local/bin/monitoring.sh | /usr/bin/wall
```

スクリプトはBashで集計して標準出力へ出し、cronのパイプがwallに渡します。起動時に1回、その後は毎時0・10・20・30・40・50分に実行します。起動時刻から厳密な600秒間隔ではありません。

| 表示 | 比較する取得元 |
| --- | --- |
| アーキテクチャ・カーネル | `uname -a` |
| 物理CPU / vCPU | `lscpu`、`/proc/cpuinfo` |
| RAM量・使用率 | `free -m` |
| ディスク量・使用率 | `df -BM -x tmpfs -x devtmpfs -x efivarfs --total` |
| CPU使用率 | `/proc/stat` の1秒間の差分 |
| 最終起動 | `uptime -s` |
| LVM | `lsblk` |
| TCP接続数 | `ss -tan state established` |
| ログイン人数 | `who` のユーザー名を重複除去 |
| IPv4 / MAC | `ip -4 addr`、`ip link` |
| sudo実行回数 | `sudo grep -c 'COMMAND=' /var/log/sudo/sudo.log` |

表示は課題例と同じused/totalと割合です。取得時刻やsudo自身の記録で値が変わるため、同時刻での完全一致だけを判断基準にしません。SSH接続の追加・切断でTCP接続数、別ユーザーのログインで人数、`sudo id` でsudo件数が変わることなどを確認します。CPU使用率が固定文字列でなく実測差分から得られることもコードと実行で示します。

コンソールとSSH端末を開いたまま、配信先とエラーの有無を確認します。

```sh
who
mesg
sudo /usr/local/bin/monitoring.sh | sudo /usr/bin/wall
sudo journalctl -u cron --since '15 minutes ago' --no-pager
```

手動配信に成功してもcronからの配信確認は別途必要です。`who` にSSH端末が出ない、wallが届かない等は未解決として扱います。全端末への配信はこのVMで残っている確認点です。

### 10. 監視：毎分へ変更 → 停止 → 再起動して無変更確認

まずrootのcrontabと、スクリプトのハッシュ・所有者・権限を保存します。保存先が既にある場合は別名にし、同じ実演中はその名前を使ってください。

```sh
sudo sh -c 'crontab -l > /root/b2br-review-crontab.before'
sudo sh -c 'sha256sum /usr/local/bin/monitoring.sh > /root/b2br-monitoring.sha256'
sudo sh -c 'stat -c "%a %U:%G %n" /usr/local/bin/monitoring.sh > /root/b2br-monitoring.stat'
sudo crontab -e
```

`*/10` の行を次に置き換えます。元の10分行を重複して残さないでください。

```cron
* * * * * /usr/local/bin/monitoring.sh | /usr/bin/wall
```

```sh
sudo crontab -l
```

分の境界を2回以上またいで通知時刻と値の変化を確認します。次に `sudo crontab -e` で、起動時と毎分の**両方**をコメントアウトします。他の場所にも監視の登録があれば確認してください。

```cron
# @reboot /usr/local/bin/monitoring.sh | /usr/bin/wall
# * * * * * /usr/local/bin/monitoring.sh | /usr/bin/wall
```

```sh
sudo crontab -l
sudo reboot
```

LUKS解除・ログイン後、同じパスにファイルがあり、ハッシュ・権限・所有者が変わっていないことを確認します。

```sh
sudo sha256sum -c /root/b2br-monitoring.sha256
sudo sh -c 'stat -c "%a %U:%G %n" /usr/local/bin/monitoring.sh > /root/b2br-monitoring.after.stat'
sudo diff -u /root/b2br-monitoring.stat /root/b2br-monitoring.after.stat
sudo crontab -l
sudo journalctl -u cron -b --no-pager
```

期待結果：ハッシュは `OK`、`diff` は差分なし。起動後と分の境界を越えても監視通知が来ず、cronの実行記録も増えません。スクリプトの内容や実行権限を変更して止める操作は行いません。

### 11. ボーナスと終了後

必須が完全に合格した場合のみ、追加パーティション2点、lighttpd・MariaDB・PHPによるWordPress2点、自由選択サービス1点を評価します。NGINXとApache2は禁止です。この構成にはボーナス構築の確認記録はありません。

停止確認を終えてから、評価用の変更を戻します。原本を保護したコピーを破棄する場合は、コピー内の変更を原本に反映する必要はありません。作業VMを再利用する場合の復元例です。

```sh
sudo crontab /root/b2br-review-crontab.before
sudo crontab -l
hostnamectl --static
sudo ufw status numbered
```

評価用ユーザーのSSHセッションを終了後、**この評価で作成したユーザーとグループであることを確認して**削除します。

```sh
sudo deluser --remove-home reviewer42
sudo groupdel evaluating
sudo poweroff
```

スナップショット方式では、電源オフ後に評価開始前の状態へ復元してから評価用スナップショットを削除します。削除だけで変更をマージしないよう操作を確認し、最後にスナップショットなし・原本のSHA-1が提出値と同じであることを確認してください。

## Resources

- 課題本文：Born2beRoot Version 5.2。要件と評価票を併せて確認します。
- [Debian公式ドキュメント](https://www.debian.org/doc/)：OSと管理の基本。
- [apt(8)](https://manpages.debian.org/trixie/apt/apt.8.en.html)：aptの用途。
- [pam_pwquality(8)](https://manpages.debian.org/trixie/libpam-pwquality/pam_pwquality.8.en.html)：品質設定、rootへの適用、旧新比較。
- [sudoers(5)](https://manpages.debian.org/trixie/sudo/sudoers.5.en.html)：sudoの権限とログ設定。
- [crontab(5)](https://manpages.debian.org/trixie/cron/crontab.5.en.html)：時刻指定と起動時実行。
- VM内の `man sshd_config`、`man ufw`、`man lvm`、`man cryptsetup`、`man wall`：インストール済み版の設定・操作。

### AI usage

AIは、課題・評価票の整理と日本語訳、レビュー説明資料と本READMEの文章・確認コマンドの整理、監視シェルスクリプトのレビュー補助に使用しました。VMの構築・設定適用・実行結果の確認と、評価時の説明は自分で行います。AIによる資料更新を実機での合格確認の代わりにはしていません。
