# Born2beRoot Review Guide（Mandatory only）

> このファイルをレビュー準備の主資料として使う。Bonusは実施していないため、本書では扱わない。
>
> 対象VM: VirtualBox / Debian 13 ARM64 / hostname `mhashimo42` / user `mhashimo`

レビューでは、設定結果を見せるだけでは不十分である。各項目について、次の3点を自分の言葉で説明できる状態を目指す。

1. 何を設定したか
2. なぜその設定が必要か
3. どのコマンド・ファイルで確認または変更できるか

---

## 0. このVMの構成

| 項目 | 実VMの構成 |
| --- | --- |
| 仮想化 | VirtualBox（私用Mac） |
| OS | Debian 13 ARM64、CUI起動 |
| hostname | `mhashimo42` |
| user | `mhashimo`（`sudo`、`user42`所属） |
| storage | EFI、`/boot`、LUKS2 → LVM root・home・swap |
| SSH | TCP 4242、root login禁止 |
| UFW | active、incoming deny、4242/tcpのみ許可 |
| password | rootと`mhashimo`に30/2/7日のaging、PAM品質規則 |
| sudo | `/etc/sudoers.d/born2beroot`、ログは`/var/log/sudo/` |
| services | AppArmor、SSH、UFW、cronがenabledかつactive |
| monitoring | `/usr/local/bin/monitoring.sh`をroot crontabから`wall`へ渡す |
| schedule | `@reboot`および10分ごと |

実VMに存在するLVはroot、home、swapである。`/var`、`/var/log`、`/tmp`などを個別LVにしたとは説明しない。

---

## 1. レビュー開始前の確認

### 1.1 署名と仮想ディスク

- [ ] `submit/signature.txt`が40桁のSHA-1である
- [ ] レビュー対象の`.vdi`から計算したSHA-1と完全に一致する
- [ ] VMは保存状態ではなく、完全に電源OFFになっている
- [ ] snapshotを使用していない
- [ ] SHA-1取得後に対象VMを起動・変更していない
- [ ] VMの場所とVirtualBoxでの起動方法を把握している

署名はGitのcommit hashではない。電源を切った仮想ディスクファイルそのものに対するSHA-1である。

```bash
# macOS側
shasum "/path/to/Born2BeRoot-Manual.vdi"

# リポジトリ内の形式確認
grep -Eq '^[0-9a-fA-F]{40}$' submit/signature.txt
```

VMを起動すると仮想ディスクが変更される可能性がある。起動または設定変更をした場合は、完全停止後にSHA-1を取り直す。

### 1.2 起動後の一括確認

レビュー練習時は、次のコマンドで基本状態を確認する。

```bash
hostnamectl
cat /etc/os-release
systemctl get-default
lsblk -f
id mhashimo
sudo chage -l mhashimo
sudo visudo -c
sudo ufw status numbered
sudo systemctl status ssh --no-pager
sudo sshd -t
sudo crontab -l
sudo /usr/local/bin/monitoring.sh
```

---

## 2. Project overview

### 2.1 仮想マシンとは何か

短い回答例:

> 仮想マシンは、物理PCのCPU、メモリ、ディスク、ネットワークなどをソフトウェアで仮想化し、独立したゲストOSを動かす環境です。このVMではMacがホスト、Debianがゲスト、VirtualBoxがハイパーバイザーです。

説明できること:

- ホストOS: VirtualBoxを動かしている側のOS
- ゲストOS: VM内で動作するOS
- ハイパーバイザー: 仮想ハードウェアを提供し、VMを管理するソフトウェア
- 利点: 隔離、再現性、検証のしやすさ、複数OSの利用
- 欠点: CPU・RAM・ストレージのオーバーヘッド、ホスト障害の影響

### 2.2 Debianを選んだ理由

短い回答例:

> Debianは安定性を重視し、情報とパッケージが豊富で、初めてのサーバー管理でも構成を理解しやすいため選びました。

### 2.3 DebianとRocky Linuxの違い

| Debian | Rocky Linux |
| --- | --- |
| Debian系 | RHEL互換系 |
| `.deb` | `.rpm` |
| APT / dpkg | DNF / RPM |
| AppArmorが一般的 | SELinuxが一般的 |
| コミュニティ主導 | Enterprise Linux互換を重視 |

### 2.4 `apt`と`aptitude`

- `apt`: 日常的なパッケージ操作向けの標準的なCLIフロントエンド
- `aptitude`: 対話UIを持ち、依存関係の解決候補を確認しやすいフロントエンド
- どちらも低レベルではdpkgやAPTの仕組みを利用する

```bash
apt --version
aptitude --version
```

### 2.5 AppArmor

短い回答例:

> AppArmorはLinux Security Modulesを利用する強制アクセス制御です。プログラムごとのprofileで、読み書きや実行を許可するパスや操作を制限します。通常のUNIX権限を突破された場合にも追加の制限として働きます。

```bash
sudo aa-status
systemctl is-enabled apparmor
systemctl is-active apparmor
```

UFWはネットワーク通信を制御し、AppArmorはプロセスの操作を制御する。役割は異なる。

---

## 3. OS、hostname、GUI

```bash
hostnamectl
cat /etc/hostname
cat /etc/hosts
cat /etc/os-release
uname -a
systemctl get-default
systemctl status display-manager --no-pager
```

確認事項:

- hostnameは`mhashimo42`
- OSはDebian 13 ARM64
- 起動targetは`multi-user.target`
- display managerやデスクトップ環境を導入していない

CUIのみなのは、GUIに頼らずサーバー管理を学ぶ課題であり、不要なパッケージや攻撃対象を増やさないためでもある。

### hostname変更の実演

レビューではhostnameを変更し、再起動後も反映されているか確認される可能性がある。

```bash
sudo hostnamectl set-hostname evaluator42
sudoedit /etc/hosts
sudo reboot

# 再ログイン後
hostnamectl
cat /etc/hostname
cat /etc/hosts
```

`/etc/hosts`内の旧hostnameも更新する。確認後、指示に従って`mhashimo42`へ戻す。

---

## 4. LUKS、LVM、パーティション

### 4.1 全体構造

```text
physical disk
└── partition
    └── LUKS encrypted container
        └── PV (Physical Volume)
            └── VG (Volume Group)
                ├── LV root  -> /
                ├── LV home  -> /home
                └── LV swap  -> swap
```

- LUKS: ブロックデバイスを暗号化し、保存データを保護する
- PV: LVMが利用する物理領域
- VG: 1つ以上のPVをまとめた容量プール
- LV: VGから必要な容量を切り出した論理ボリューム
- filesystem: LV上に作られ、ファイルを保存する形式
- mount point: filesystemをディレクトリツリーへ接続する場所

LUKSは暗号化を担当し、LVMは容量管理を担当する。LVMだけでは暗号化されず、LUKSだけでは柔軟な論理ボリューム管理にならない。

### 4.2 確認コマンド

```bash
lsblk
lsblk -f
findmnt /
findmnt /home
swapon --show
sudo pvs
sudo vgs
sudo lvs
```

説明できること:

- `crypto_LUKS`の内側にLVMがあること
- root、home、swapの役割
- `/boot`が暗号化領域の外側にある理由
- LVを分けると容量管理や影響範囲の分離がしやすいこと
- swapはRAM不足時の退避領域だが、RAMより遅いこと

---

## 5. ユーザーとグループ

```bash
id mhashimo
getent passwd mhashimo
getent group sudo
getent group user42
```

`mhashimo`が`sudo`と`user42`に所属していることを示す。

### 新規ユーザーとグループの実演

```bash
sudo adduser reviewer42
sudo groupadd evaluating
sudo usermod -aG evaluating reviewer42

id reviewer42
getent group evaluating
sudo chage -l reviewer42
```

説明できること:

- `adduser`: Debianの対話的な高レベルツール
- `useradd`: より低レベルなユーザー作成コマンド
- `/etc/passwd`: アカウント情報
- `/etc/shadow`: password hashとaging情報
- `/etc/group`: グループ情報
- `usermod -aG`: 既存の補助グループを維持して追加する
- `-a`なしの`usermod -G`は既存の補助グループを失わせる危険がある

テストユーザーを削除する場合は、評価者の指示を確認してから実行する。

```bash
sudo deluser --remove-home reviewer42
```

---

## 6. パスワードポリシー

password agingとpassword qualityは別の仕組みである。

| 設定場所 | 役割 |
| --- | --- |
| `/etc/login.defs` | 新規ユーザーに対するagingのデフォルト |
| `chage` | 既存ユーザーごとのaging |
| PAM | password変更時の認証処理 |
| `pam_pwquality` | passwordの文字構成や強度を検査 |
| `/etc/security/pwquality.conf` | 品質規則の設定値 |

### 6.1 課題の設定値

| 項目 | 設定 |
| --- | --- |
| 最大有効日数 | 30日 |
| 最小変更間隔 | 2日 |
| 期限警告 | 7日前 |
| 最小文字数 | 10文字 |
| 文字種 | 大文字・小文字・数字を各1文字以上 |
| 同一文字の連続 | 最大3文字 |
| username | passwordに含めない |
| 旧passwordとの差 | 7文字以上 |
| root | 品質規則を適用。ただし旧passwordとの差の検証は非rootで確認する |

### 6.2 確認コマンド

```bash
grep -E '^(PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_WARN_AGE)' /etc/login.defs
sudo chage -l mhashimo
sudo chage -l root
grep -Ev '^\s*(#|$)' /etc/security/pwquality.conf
grep -n pam_pwquality /etc/pam.d/common-password
```

期待する主要値:

```text
PASS_MAX_DAYS 30
PASS_MIN_DAYS 2
PASS_WARN_AGE 7
minlen = 10
ucredit = -1
lcredit = -1
dcredit = -1
maxrepeat = 3
usercheck = 1
difok = 7
```

注意点:

- `login.defs`の変更は既存ユーザーへ自動反映されるとは限らないため、`chage`で設定する
- `ucredit=-1`などの負数は、その文字種を最低1文字要求する
- `maxrepeat=3`は同一文字4連続を拒否する
- passwordそのものはリポジトリ、メモ、画面共有へ出さない
- 強いpasswordは推測・総当たりを難しくする一方、過度な定期変更は使い回しやメモを誘発する欠点もある

---

## 7. sudo

短い回答例:

> sudoは、許可された一般ユーザーが必要なコマンドだけを一時的に別ユーザー、通常はrootの権限で実行する仕組みです。常時rootで作業するより、誤操作を減らし、誰が何を実行したか記録できます。

`su`は別ユーザーのshellへ切り替え、`su -`はそのユーザーのlogin環境も読み込む。`sudo`は許可された個別コマンドを昇格して実行する。

### 7.1 設定の意味

| 設定 | 意味 |
| --- | --- |
| `passwd_tries=3` | password入力を3回に制限 |
| `badpass_message` | 認証失敗時の独自メッセージ |
| `log_input` / `log_output` | sudoセッションの入出力を記録 |
| `iolog_dir` | I/Oログの保存先 |
| `logfile` | sudoイベントのログファイル |
| `requiretty` | TTYのないsudo実行を拒否 |
| `secure_path` | sudo実行時のPATHを信頼済みパスに固定 |

### 7.2 確認コマンド

```bash
sudo visudo -c
sudo stat -c '%A %U:%G %n' /etc/sudoers.d/born2beroot
sudo grep -R -E 'passwd_tries|badpass_message|log_input|log_output|iolog_dir|logfile|requiretty|secure_path' \
  /etc/sudoers /etc/sudoers.d
sudo -l
sudo find /var/log/sudo -maxdepth 3 -type f -print
```

`visudo`を使うのは、保存前にsudoersの構文を検証し、同時編集を防ぐためである。設定変更には次を使う。

```bash
sudo visudo -f /etc/sudoers.d/born2beroot
```

レビューではsudoコマンドを1回実行し、`/var/log/sudo/`のログが更新されたことを説明できるようにする。

---

## 8. UFW

短い回答例:

> UFWはnetfilterのルール管理を簡単にするファイアウォール用フロントエンドです。このVMでは受信を原則拒否し、SSHに必要なTCP 4242だけを許可しています。

```bash
sudo systemctl is-enabled ufw
sudo systemctl is-active ufw
sudo ufw status verbose
sudo ufw status numbered
```

確認事項:

- UFWがactive
- default incomingがdeny
- 4242/tcpがallow
- 不要な受信許可がない

### ルール追加・削除の実演

```bash
sudo ufw allow 8080/tcp
sudo ufw status numbered
sudo ufw delete <8080のルール番号>
sudo ufw status numbered
```

番号は追加・削除のたびに変わり得るため、表示を確認してから削除する。SSH設定中は、4242/tcpの許可を消さない。

---

## 9. SSH

短い回答例:

> SSHは、暗号化された通信でリモートマシンへログインし、コマンドを実行するプロトコルです。`ssh`がクライアント、`sshd`がサーバーです。このVMでは4242番ポートを使用し、rootの直接ログインを禁止しています。

ポートを22から4242へ変更するだけで強固な認証になるわけではない。不要な自動スキャンを減らす補助的な対策であり、root login禁止、強いpassword、UFWなどと組み合わせる。

### 9.1 VM内での確認

```bash
sudo systemctl is-enabled ssh
sudo systemctl is-active ssh
sudo sshd -t
sudo sshd -T | grep -E '^(port|permitrootlogin) '
sudo ss -lntp
```

期待する状態:

```text
port 4242
permitrootlogin no
```

- `sshd -t`: 設定ファイルの構文を検証する
- `sshd -T`: includeやdefaultを含めた有効設定を表示する
- `ss -lntp`: 実際にlistenしているTCPポートとprocessを表示する

### 9.2 ホストMacからの接続

VirtualBoxのNAT port forwardingを使用している場合:

```bash
ssh -p 4242 mhashimo@127.0.0.1
ssh -p 4242 reviewer42@127.0.0.1
ssh -p 4242 root@127.0.0.1
```

確認事項:

- 一般ユーザーで接続できる
- レビュー中に作成したユーザーでも接続できる
- rootでは接続できない

SSH設定を変更するときは、VMコンソールと現在のSSH接続を復旧経路として残し、`sshd -t`後にreloadまたはrestartし、別端末から新規接続を確認する。

---

## 10. monitoring.sh、cron、wall

### 10.1 構成

`/usr/local/bin/monitoring.sh`は情報を標準出力へ表示し、rootのcrontabが出力を`wall`へ渡す。

```cron
@reboot /usr/local/bin/monitoring.sh | /usr/bin/wall
*/10 * * * * /usr/local/bin/monitoring.sh | /usr/bin/wall
```

- `cron`: 指定した時刻・間隔でコマンドを実行するdaemon
- `@reboot`: 起動時に1回実行
- `*/10`: 毎時0、10、20、30、40、50分に実行
- `wall`: ログイン中の端末へ標準入力の内容をbroadcastする

### 10.2 表示する12項目

| 項目 | 主な取得元 | 説明 |
| --- | --- | --- |
| architecture / kernel | `uname -a` | OSアーキテクチャとkernel version |
| physical CPU | `lscpu`、`/proc/cpuinfo` | 物理CPU・socket数 |
| vCPU | `lscpu`、`/proc/cpuinfo` | VMへ割り当てた論理CPU数 |
| RAM | `free` | 使用量、総量、使用率 |
| storage | `df` | 使用量、総量、使用率 |
| CPU load | `/proc/stat`など | 現在のCPU使用率 |
| last boot | `uptime -s`、`who -b` | 最終起動日時 |
| LVM | `lsblk`など | LVMが有効か |
| TCP connections | `ss` | ESTABLISHED状態の接続数 |
| users | `who` | ログイン中のユーザー数 |
| IPv4 / MAC | `ip` | ネットワークアドレス |
| sudo count | sudo log | 実行されたsudo command数 |

スクリプト内で使用している`grep`、`awk`、`sed`、`wc`なども、各optionを含めて説明できるようにする。

### 10.3 確認コマンド

```bash
sudo /usr/local/bin/monitoring.sh
sudo crontab -l
sudo stat -c '%A %U:%G %n' /usr/local/bin/monitoring.sh
systemctl is-enabled cron
systemctl is-active cron
```

確認事項:

- 12項目が空欄やエラーなしで表示される
- 数値が固定文字列ではなく、取得時点の値である
- root crontabから10分ごとに実行される
- VirtualBoxコンソールとSSH端末への`wall`表示を確認できる
- 再起動後もscript、権限、cron設定が残る

### 10.4 レビュー中の変更操作

10分ごとから1分ごとへ変更する場合:

```bash
sudo crontab -e
```

```cron
* * * * * /usr/local/bin/monitoring.sh | /usr/bin/wall
```

script自体を変更せず自動実行を停止する場合は、root crontabの対象行をコメントアウトするか削除する。`monitoring.sh`の内容や実行権限は変更しない。

---

## 11. 評価で練習しておく操作

### 11.1 ユーザー・グループ

- [ ] 強度規則を満たすpasswordで新規ユーザーを作る
- [ ] `chage -l`でagingを確認する
- [ ] `evaluating`グループを作る
- [ ] 新規ユーザーを`evaluating`へ追加する
- [ ] `id`と`getent group`で確認する

### 11.2 hostname

- [ ] hostnameを指定された名前へ変更する
- [ ] `/etc/hosts`も整合させる
- [ ] 再起動後に変更が維持されることを確認する
- [ ] 指示された場合は`mhashimo42`へ戻す

### 11.3 UFW

- [ ] 一時的なTCPポートを許可する
- [ ] numbered listで追加を確認する
- [ ] 正しい番号のルールを削除する
- [ ] 4242/tcpだけに戻ったことを確認する

### 11.4 SSH

- [ ] 4242で一般ユーザーとして接続する
- [ ] 新規ユーザーで接続する
- [ ] root接続が拒否されることを示す
- [ ] `sshd -t`、`sshd -T`、`ss -lntp`の違いを説明する

### 11.5 sudo

- [ ] sudoersの構文を検証する
- [ ] sudo commandを実行する
- [ ] ログが更新されたことを確認する
- [ ] 3回の認証失敗制限と独自メッセージを説明する

### 11.6 monitoring

- [ ] scriptを手動実行する
- [ ] 各出力の取得元を説明する
- [ ] 実行間隔を1分へ変更する
- [ ] scriptを編集せず、自動実行を停止する
- [ ] 必要なら10分設定へ戻す

---

## 12. 設定変更時の安全な手順

1. 現在の設定とサービス状態を確認する。
2. VMコンソールなどの復旧経路を確保する。
3. 専用ツールで編集する。sudoersなら`visudo`を使う。
4. `sshd -t`や`visudo -c`で構文を検証する。
5. 必要なサービスだけreloadまたはrestartする。
6. 表示上の設定値だけでなく、実際の動作を確認する。
7. ネットワークや認証の変更では、新しい接続が成功するまで既存SSH接続を閉じない。

---

## 13. 最終セルフチェック

資料を見ずに次を説明できれば、レビュー準備は概ね完了である。

- [ ] VM、ホスト、ゲスト、ハイパーバイザーの関係
- [ ] Debianを選んだ理由とRocky Linuxとの違い
- [ ] `apt`と`aptitude`の違い
- [ ] AppArmorとUFWの役割の違い
- [ ] LUKS、PV、VG、LV、filesystemの関係
- [ ] 実VMにあるroot、home、swapのLV構成
- [ ] `/etc/login.defs`、`chage`、PAMの役割の違い
- [ ] `sudo`、`su`、`su -`の違い
- [ ] `visudo`を使う理由
- [ ] SSHを4242で提供し、root loginを禁止する理由
- [ ] UFWで4242/tcpだけを許可する理由
- [ ] cronの5フィールド、`*/10`、`@reboot`の意味
- [ ] monitoring scriptの12項目と取得元
- [ ] scriptを変更せず自動実行を停止する方法
- [ ] VM停止後にSHA-1を取得する理由

最後に、VM上の実際の出力と「0. このVMの構成」が一致していることを確認する。レビュー資料より実VMの状態を優先し、相違があればレビュー前に資料またはVMを修正する。
