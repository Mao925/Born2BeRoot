# Born2beRoot 実装設計書（Debian / VirtualBox）

> 対象: Born2beRoot の必須要件を、Linux 初学者が自分で構築・説明できる状態にするための設計書です。コマンドをそのまま実行する前に、何を変更するのかを理解してください。`<login>` は自分の 42 ログイン名に置き換えます。

## 1. ゴールと完成条件

VirtualBox 上に GUI なしの Debian サーバーを作り、暗号化 LVM、SSH、UFW、ユーザー・パスワード・sudo のセキュリティ設定、定期監視を動作させる。リポジトリに提出するものは `README.md` と `signature.txt` のみであり、仮想ディスクそのものはコミットしない。

必須部分の完了条件は次のとおりです。

- Debian の **latest stable** を GUI なしで起動できる。
- LUKS 暗号化された LVM 上に複数の論理ボリューム（最低 2 個）を持つ。
- SSH は TCP 4242 番で稼働し、root ではログインできない。
- UFW は起動時から有効で、外部から許可する受信ポートは 4242/TCP のみである。
- `<login>42` というホスト名、`<login>` ユーザー、`user42`・`sudo` グループがある。
- 指定のパスワードポリシー、sudo ポリシー、10 分ごとの監視表示が機能する。
- `README.md` と、停止した仮想ディスクから取得した SHA-1 を記した `signature.txt` を用意できる。

## 2. 採用する構成

| 項目 | 採用 | 理由 |
| --- | --- | --- |
| 仮想化 | VirtualBox | 課題で必須（利用不可の場合のみ UTM）。評価者も扱いやすい。 |
| OS | Debian stable（netinst） | 初学者向けの情報量が多く、apt・AppArmor・UFW を使える。testing/unstable は使わない。 |
| インストール種別 | 最小構成、SSH server のみ | X.org / Wayland / デスクトップ環境を入れない。GUI を入れると 0 点。 |
| ディスク保護 | LUKS + LVM | LUKS がディスク内容を暗号化し、LVM が `/`、`/home`、`/var` 等を柔軟に分割する。 |
| リモート接続 | OpenSSH（4242/TCP） | 標準の安全な管理経路。root の直接ログインを禁止する。 |
| ファイアウォール | UFW | Debian 用の簡潔なフロントエンド。受信は原則拒否にする。 |
| 定期実行 | cron | 10 分おきの `monitoring.sh` 実行と、評価中に止める操作が明快。 |

### 用語の最小理解

```
物理ディスク
├─ /boot                 … 起動に必要。暗号化しない（GRUB が読むため）
└─ LUKS 暗号化コンテナ  … パスフレーズで開く「金庫」
   └─ LVM volume group  … 金庫の中の容量プール（例: vg0）
      ├─ lv_root  → /       … OS 本体
      ├─ lv_home  → /home   … ユーザーファイル
      ├─ lv_var   → /var    … ログ・パッケージの可変データ
      ├─ lv_log   → /var/log
      ├─ lv_tmp   → /tmp
      └─ lv_swap  → swap    … メモリ不足時の退避領域
```

LUKS コンテナの中に複数の LV を置くため、少なくとも 2 つの LVM パーティション（論理ボリューム）が暗号化保護されます。評価で `lsblk` と `lsblk -f` を見せ、`crypto_LUKS` の下に LVM/LV があることを説明できるようにします。

## 3. 実装の順序

順序を崩すと、自分を SSH や sudo から締め出す事故が起こりやすくなります。

1. VirtualBox と Debian stable ISO を用意する。
2. Debian を最小構成・暗号化 LVM でインストールする。
3. OS を更新し、必要パッケージを導入する。
4. ホスト名、ユーザー、SSH、UFW を設定する。**SSH の動作を別ターミナルから確認してから現在の接続を閉じる**。
5. パスワードポリシーと sudo ポリシーを設定し、全アカウントのパスワードを更新する。
6. 監視スクリプトと cron を設定する。
7. 再起動試験、評価用チェック、README、signature の順に仕上げる。

## 4. VirtualBox と Debian のインストール

### 4.1 VM の作成

- 新規 VM 名: 例 `born2beroot`（ホスト名とは別物）
- Type: Linux / Debian (64-bit)
- メモリ: 1 GB 以上を目安にする。
- 仮想ディスク: VDI、動的割り当て、12〜20 GB 程度を目安にする。
- Network: 最初は NAT でよい。ホストから SSH 接続したい場合は、NAT のポートフォワーディングで **ホスト 4242 → ゲスト 4242** を追加する。ブリッジ接続を使う場合は LAN に直接公開される点を理解する。

ISO は Debian 公式の stable netinst を使用する。インストール中に「Graphical install」を選ばず、テキストの `Install` を選ぶと意図が明確です。

### 4.2 インストール時の重要項目

- hostname: `<login>42`
- root パスワード: 強いものを設定する（後でポリシー適用後に変更する）。
- 一般ユーザー: `<login>`。root とは別に必ず作る。
- software selection: **Debian desktop environment を選ばない**。`SSH server` と `standard system utilities` は選択してよい。
- partitioning: `Guided - use entire disk and set up encrypted LVM` を選ぶ。これは LUKS の内側に LVM を作る。

インストーラに論理ボリュームの手動編集画面がある場合は、下表のように分けます。数値は小さな学習 VM 向けの例であり、仮想ディスク容量に合わせて調整します。`/boot` 以外は暗号化 LVM の中に置きます。

| マウント先 | LV 名の例 | 目安 | 分離する意味 |
| --- | --- | ---: | --- |
| `/boot` | — | 512 MB〜1 GB | 起動用。LUKS の外側。 |
| `/` | `root` | 4 GB | OS 本体。 |
| `/home` | `home` | 2 GB | ユーザーデータを OS と分離。 |
| `/var` | `var` | 2 GB | パッケージ・キャッシュ等の増加を分離。 |
| `/var/log` | `log` | 1〜2 GB | ログ肥大化が OS 領域を埋めるのを防ぐ。 |
| `/tmp` | `tmp` | 1 GB | 一時ファイルを分離。 |
| `/srv` | `srv` | 1 GB | 将来サービス用データを置ける。 |
| swap | `swap` | 1〜2 GB | VM のメモリ量に応じて設定。 |

使用済み容量を合計しても、VG に少し未割り当て容量を残します。将来 `/var` などが足りなくなったときに LV を拡張できるためです。インストール完了後、初回ログインして `sudo -v` が成功することを確認します。

## 5. 基本パッケージとアカウント

root または sudo 可能な一般ユーザーで、まず OS を最新化します。

```bash
sudo apt update
sudo apt upgrade
sudo apt install openssh-server ufw sudo libpam-pwquality
```

`openssh-server` は SSH サーバー、`ufw` はファイアウォール、`libpam-pwquality` はパスワード品質検査、`sudo` は一般ユーザーに管理操作を限定して許可する仕組みです。AppArmor は Debian の標準インストールで入ることが多いですが、状態を必ず確認します。

```bash
systemctl is-enabled apparmor
systemctl is-active apparmor
sudo aa-status
getent passwd <login>
id <login>
```

`user42` グループがない場合は作成し、一般ユーザーを両グループへ入れます。

```bash
sudo groupadd user42
sudo usermod -aG user42,sudo <login>
id <login>
```

グループ変更は次回ログインから反映されます。一度ログアウトしてログインし直し、`groups` で確認します。すでにグループが存在する場合、`groupadd` は失敗するため、先に `getent group user42` で確認しても構いません。

### ホスト名

```bash
sudo hostnamectl set-hostname <login>42
hostnamectl
```

`/etc/hosts` の `127.0.1.1` 行が旧ホスト名を指していれば、`<login>42` に直します。再起動後も `hostname` が `<login>42` であることを確認します。評価では変更を求められるので、`hostnamectl set-hostname 新しい名前` と `/etc/hosts` 更新の両方を説明できるようにします。

## 6. SSH と UFW

### 6.1 SSH を 4242 番へ移し、root を禁止する

Debian では `/etc/ssh/sshd_config` または `/etc/ssh/sshd_config.d/*.conf` を設定する。1 か所に明示するため、次のファイルを作ります。

```bash
sudoedit /etc/ssh/sshd_config.d/42-security.conf
```

内容:

```conf
Port 4242
PermitRootLogin no
```

設定文が複数ファイルに重複すると、読み込み順で意図しない値になることがあります。確認には以下を使います。

```bash
sudo sshd -t
sudo systemctl enable --now ssh
sudo systemctl restart ssh
sudo sshd -T | grep -E 'port|permitrootlogin'
sudo ss -ltnp | grep 4242
```

`sshd -t` がエラーなしで終わることを確認してから再起動します。許可されている認証方式の範囲で、別のホスト端末から以下を試します。

```bash
ssh -p 4242 <login>@<VMのIPアドレス>
ssh -p 4242 root@<VMのIPアドレス>
```

前者は接続でき、後者は拒否されるのが正しい状態です。先に別セッションの成功を確認するまでは、VM のコンソールや現在の SSH セッションを閉じないでください。

### 6.2 UFW

SSH を 4242 に移してから、次の順で UFW を設定します。

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 4242/tcp
sudo ufw enable
sudo systemctl enable ufw
sudo ufw status verbose
```

期待値は `Status: active` と `4242/tcp ALLOW` だけです。`22/tcp` の既存ルールがあれば、接続確認後に `sudo ufw delete allow 22/tcp` で削除します。DHCP に必要な通信など、外向き通信を止めないため、既定の送信は許可する設計です。

## 7. 強いパスワードポリシー

この節では「新しいパスワードを決めるルール」と「有効期限」を別々に設定します。設定前に必ず VM のスナップショットではなく、コンソールから root で復旧できる状態を確保します（評価開始時にはスナップショットを残さない）。

### 7.1 有効期限

`/etc/login.defs` で以下を設定します。

```conf
PASS_MAX_DAYS   30
PASS_MIN_DAYS   2
PASS_WARN_AGE   7
```

これは新規ユーザーの既定値です。すでに存在する root と `<login>` にも反映するため、次を実行します。

```bash
sudo chage -M 30 -m 2 -W 7 root
sudo chage -M 30 -m 2 -W 7 <login>
sudo chage -l <login>
```

`chage -l` の出力で、最大日数 30・最小日数 2・警告 7 が確認できればよいです。

### 7.2 文字種と禁止条件

`/etc/security/pwquality.conf` に、少なくとも次を設定します（既存の同名設定は重複させず、最終的に 1 つの値にする）。

```conf
minlen = 10
ucredit = -1
lcredit = -1
dcredit = -1
maxrepeat = 3
usercheck = 1
difok = 7
```

意味は、10 文字以上・大文字/小文字/数字を各 1 文字以上・同一文字の 4 連続を禁止・ユーザー名を含めない・前回と異なる文字を最低 7 文字、です。`difok = 7` は課題文どおり root には適用しない扱いにします。root もそれ以外の強度条件を満たすパスワードを手作業で選びます。

PAM がこの設定を読むことを確認します。Debian の `/etc/pam.d/common-password` に `pam_pwquality.so` が含まれているか確認してください。

```bash
grep -n 'pam_pwquality' /etc/pam.d/common-password
```

入っていなければ、既存の `pam_unix.so` より前に次の行を追加します。ファイルは認証全体に影響するため、編集は VM コンソールから行い、別の root セッションを閉じずに検証します。

```conf
password requisite pam_pwquality.so retry=3
```

最後に root と全ユーザーのパスワードを変更します。ポリシーは変更前のパスワードには遡って適用されません。

```bash
sudo passwd root
passwd
```

`<login>` 以外の一般アカウントを作った場合も `sudo passwd ユーザー名` で変更します。わざと短い・ユーザー名入りの候補を入力して拒否されること、要件を満たす候補が受理されることをテストします。

## 8. sudo のセキュリティ設計

設定は `/etc/sudoers` を直接編集せず、構文検証を行う `visudo` で専用ファイルに書きます。

```bash
sudo install -d -m 700 /var/log/sudo
sudo visudo -f /etc/sudoers.d/42-security
```

ファイル内容:

```sudoers
Defaults        passwd_tries=3
Defaults        badpass_message="Authentication failed. Please try again."
Defaults        log_input, log_output
Defaults        iolog_dir="/var/log/sudo"
Defaults        requiretty
Defaults        secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"
```

保存時に `visudo` は構文を検査します。さらに権限を確認します。

```bash
sudo chmod 440 /etc/sudoers.d/42-security
sudo visudo -c
sudo -k
sudo ls /root
sudo find /var/log/sudo -type f | head
```

確認ポイントは、誤った sudo パスワードが 3 回までであること、独自メッセージが出ること、`/var/log/sudo/` に入出力ログが作られることです。`requiretty` により、TTY のない自動実行では sudo が拒否されます。これはセキュリティ要件であり、SSH の通常の対話ログインでは TTY があるため利用できます。

## 9. 監視スクリプトと cron

### 9.1 設計方針

スクリプトは root が実行し、結果だけを `wall` でログイン中の全端末に配信します。`wall` に渡す文字列を標準出力へ組み立てるため、個別の一時ファイルは不要です。配置先を `/usr/local/bin/monitoring.sh` とし、root 以外は変更できない権限にします。

以下は、要求された 12 項目を出す実装例です。環境差が出やすい CPU 使用率は `/proc/stat` を 1 秒間隔で 2 回読み、差分から計算します。

```bash
#!/usr/bin/env bash
set -u

architecture=$(uname -a)
physical_cpu=$(grep 'physical id' /proc/cpuinfo | awk -F: '{print $2}' | sort -u | wc -l)
[ "$physical_cpu" -gt 0 ] || physical_cpu=1
virtual_cpu=$(nproc)

memory_used=$(free -m | awk '/Mem:/ {print $3}')
memory_total=$(free -m | awk '/Mem:/ {print $2}')
memory_pct=$(free | awk '/Mem:/ {printf "%.2f", $3 / $2 * 100}')

disk_used=$(df -BM --total | awk '$1 == "total" {gsub("M", "", $3); print $3}')
disk_total=$(df -h --total | awk '$1 == "total" {print $2}')
disk_pct=$(df -P --total | awk '$1 == "total" {gsub("%", "", $5); print $5}')

read -r _ user1 nice1 system1 idle1 iowait1 irq1 softirq1 steal1 _ < /proc/stat
idle1=$((idle1 + iowait1))
total1=$((user1 + nice1 + system1 + idle1 + irq1 + softirq1 + steal1))
sleep 1
read -r _ user2 nice2 system2 idle2 iowait2 irq2 softirq2 steal2 _ < /proc/stat
idle2=$((idle2 + iowait2))
total2=$((user2 + nice2 + system2 + idle2 + irq2 + softirq2 + steal2))
cpu_pct=$(awk -v t1="$total1" -v t2="$total2" -v i1="$idle1" -v i2="$idle2" 'BEGIN {printf "%.1f", (1 - (i2-i1)/(t2-t1))*100}')

last_boot=$(who -b | awk '{print $3 " " $4}')
lvm_use=$(if lsblk -no TYPE | grep -qx lvm; then echo yes; else echo no; fi)
tcp_connections=$(ss -tan state established | tail -n +2 | wc -l)
user_log=$(who | wc -l)

interface=$(ip route show default | awk '{print $5; exit}')
ip_address=$(ip -4 addr show "$interface" | awk '/inet / {print $2}' | cut -d/ -f1)
mac_address=$(cat "/sys/class/net/$interface/address")
sudo_count=$(journalctl _COMM=sudo --no-pager 2>/dev/null | grep -c 'COMMAND=')

wall <<EOF
#Architecture: $architecture
#Physical CPU: $physical_cpu
#vCPU: $virtual_cpu
#Memory Usage: ${memory_used}/${memory_total}MB (${memory_pct}%)
#Disk Usage: ${disk_used}M/${disk_total} (${disk_pct}%)
#CPU load: ${cpu_pct}%
#Last boot: $last_boot
#LVM use: $lvm_use
#TCP Connections: $tcp_connections ESTABLISHED
#User log: $user_log
#Network: IP $ip_address ($mac_address)
#Sudo: $sudo_count cmd
EOF
```

> 補足: 物理 CPU は仮想環境により `physical id` が見えないことがあります。その場合は `lscpu -p` を使う実装に差し替えるなど、**自分の VM 上で値が妥当か確認して説明できること**を優先してください。また `journalctl` の sudo 件数は Debian のログ設定により異なるため、実機の sudo ログで件数が増えるか必ず試験します。

インストールと手動テスト:

```bash
sudoedit /usr/local/bin/monitoring.sh
sudo chown root:root /usr/local/bin/monitoring.sh
sudo chmod 700 /usr/local/bin/monitoring.sh
sudo /usr/local/bin/monitoring.sh
```

表示エラーを出さず、すべての項目が埋まることを先に確認します。なお、上のサンプルでは root の cron から呼ぶため `sudo_count` の取得に root 権限が必要です。

### 9.2 10 分ごと・起動時の実行

`/etc/crontab` に次の 2 行を追加します。

```cron
@reboot root /usr/local/bin/monitoring.sh
*/10 * * * * root /usr/local/bin/monitoring.sh
```

続けて cron を有効化します。

```bash
sudo systemctl enable --now cron
sudo systemctl restart cron
systemctl status cron --no-pager
```

評価で「スクリプトを変更せず停止して」と言われたら、`/etc/crontab` の該当行の先頭に `#` を付け、`sudo systemctl restart cron` を実行します。再開時は `#` を外して同じく再起動します。cron を理解していることの確認であり、スクリプトを消したり chmod で無効化したりしません。

## 10. 起動後の受け入れテスト

すべて設定したら VM を再起動し、暗号化ボリュームの解除から各サービスの起動までを確認します。

```bash
sudo reboot
```

ログイン後のチェックリスト:

- `hostnamectl` が `<login>42` を示す。
- `lsblk -f` で LUKS と、その配下の複数の LVM logical volume が見える。
- `systemctl is-active apparmor ssh ufw cron` がすべて `active`。
- `sudo ufw status numbered` で 4242/TCP 以外の受信許可がない。
- `sudo sshd -T | grep -E 'port|permitrootlogin'` が `port 4242` と `permitrootlogin no`。
- 別端末から `ssh -p 4242 <login>@<IP>` が成功し、`ssh -p 4242 root@<IP>` が失敗する。
- `id <login>` に `sudo` と `user42` が含まれる。
- `chage -l <login>` と `sudo chage -l root` が 30 / 2 / 7 のポリシーを示す。
- `sudo -k` 後に誤ったパスワードを試すと独自メッセージと 3 回制限を確認できる。`/var/log/sudo/` にログが作られる。
- `sudo /usr/local/bin/monitoring.sh` の表示に要求された全項目があり、10 分後にも `wall` 配信される。

## 11. 評価で説明するポイント

| 質問されやすい項目 | 短い説明 |
| --- | --- |
| `apt` と `aptitude` | どちらも Debian 系のパッケージ管理ツール。`apt` は標準的でスクリプト・日常運用向け、`aptitude` は依存関係解決の対話機能が強い別フロントエンド。混在を避ける。 |
| AppArmor | プログラムごとのプロファイルで「許可した操作だけ」を制限する MAC。Debian で標準的。 |
| SELinux | ラベルとポリシーに基づく強制アクセス制御（MAC）。Rocky では起動時から enforcing を維持する。 |
| UFW | iptables/nftables を簡単に設定する Debian 向けフロントエンド。 |
| firewalld | Rocky で使う、ゾーン・サービス単位で管理できる動的ファイアウォール。 |
| VirtualBox と UTM | VirtualBox は複数 OS で使える一般的なハイパーバイザ。UTM は主に macOS/Apple Silicon で QEMU を利用し、ディスク形式は `.qcow2`。 |
| LUKS と LVM | LUKS は暗号化、LVM はボリューム管理。目的が違い、組み合わせることで安全に柔軟な分割ができる。 |
| `cron` と `wall` | cron は時刻指定の定期実行、wall はログイン中の全端末へのメッセージ配信。 |

## 12. README と提出物

### README.md の必須構成

リポジトリ直下の `README.md` は、先頭行を次にします。

```md
*This project has been created as part of the 42 curriculum by <login>.*
```

少なくとも以下を含めます。

1. **Description**: サーバー仮想化の学習目的、Debian を選んだ理由、構成の概要。
2. **Instructions**: VirtualBox での起動方法、SSH 接続例、監視表示の確認方法。
3. **Design choices**: パーティション、LUKS/LVM、ユーザー管理、SSH/UFW/sudo/パスワード方針、導入サービス。
4. **Comparisons**: Debian vs Rocky Linux、AppArmor vs SELinux、UFW vs firewalld、VirtualBox vs UTM の比較。
5. **Resources**: Debian・OpenSSH・UFW・LVM・cron の公式資料等。
6. **AI usage**: AI を使った場合は、使用箇所（例: 用語の調査、文章の推敲）と、最終的な構築・検証・理解を自分で行ったことを具体的に記す。

### signature.txt の作成

最終確認後に VM を**完全に停止**し、VirtualBox の `.vdi` を SHA-1 でハッシュ化します。Linux ホストの例:

```bash
sha1sum "$HOME/VirtualBox VMs/<VM名>/<VM名>.vdi"
```

出力された 40 桁のハッシュ値だけを `signature.txt` に書きます。仮想マシンを再起動すると仮想ディスクが変化し、ハッシュも変わります。提出後や評価直前に VM を起動したなら、停止後にハッシュを再取得して `signature.txt` を更新します。評価開始時にはスナップショットを残しません。

## 13. ボーナスの扱い

ボーナスは必須部分が完全に動作してから着手します。必須に不具合が一つでもあるとボーナスは評価されません。

- パーティションを課題の図に近い細分化構成にする。
- `lighttpd`、MariaDB、PHP による WordPress を稼働させる。
- NGINX / Apache2 以外から有用なサービスを一つ選び、選定理由を説明できるようにする。
- 必要な追加ポートのみを UFW で明示的に開け、README に理由を書く。

WordPress を SSH と同居させると攻撃面が増えます。必須の UFW 設定を壊さず、サービスごとの動作確認・再起動後の自動起動・不要なポートがないことを追加で検証します。

## 14. よくある失敗と復旧の考え方

- **GUI を選んでしまった**: デスクトップ環境や X.org / Wayland が入った構成は要件違反。作り直しが最も確実。
- **SSH の設定後に接続不能**: `sshd -t` を先に実行し、コンソールを残す。UFW は 4242 を許可してから有効化する。
- **sudo を壊した**: `/etc/sudoers.d` は必ず `visudo -f` で編集する。コンソールの root から `visudo -c` で直す。
- **パスワード変更が通らない**: `pwquality.conf` の同名設定重複、PAM 行の順序、既存パスワードとの差分を確認する。
- **監視の値が空**: `ip route` が返す既定インターフェース名、`journalctl` の sudo ログ、`df --total` の出力を VM 上で個別に実行し、取得元を一つずつ確かめる。
- **signature が一致しない**: 起動後にハッシュを取り直す。Git に `.vdi` や `.qcow2` を入れない。

この設計書のコマンドは「設定する → 構文確認する → サービスを再起動する → 外部から動作確認する」の順で使います。各設定について、変更したファイル・目的・確認コマンドを自分の言葉で説明できれば、評価中の小さな変更要求にも対応しやすくなります。
