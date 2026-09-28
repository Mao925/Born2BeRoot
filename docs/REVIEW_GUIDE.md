> このファイルがBorn2beRootのレビュー準備に使う唯一の資料です。実VMはDebian 13 ARM64、hostname `mhashimo42`、LUKS2内のLVMはroot/home/swapです。旧設計と混同しないでください。

# Born2beRoot review guide

このガイドは、評価前の実機確認、評価中の説明、最後の自己テストを一つにまとめたものです。コマンドの出力を見せるだけでなく、「何を確認しているか」「なぜ必要か」を自分の言葉で説明できることを完了条件にします。

## 1. 最初に把握する実VMの状態

| 項目            | 実VMで確認した状態                                                |
| --------------- | ----------------------------------------------------------------- |
| 仮想化・OS      | VirtualBox（私用Mac）、Debian 13 ARM64、CUI起動                   |
| hostname / user | `mhashimo42` / `mhashimo`（`sudo`、`user42`所属）         |
| storage         | EFI、`/boot`、LUKS2 → LVM root (`/`)、home (`/home`)、swap |
| SSH / UFW       | SSH 4242、root login禁止、UFW active、受信許可は4242/tcpのみ      |
| password        | rootとmhashimoは30/2/7日、`pam_pwquality`を設定                 |
| sudo            | `/etc/sudoers.d/born2beroot`、ログは`/var/log/sudo/sudo.log`  |
| services        | AppArmor、SSH、UFW、cronがenabledかつactive                       |
| monitoring      | スクリプトはstdoutへ出力し、root crontabが`wall`へパイプ        |
| cron            | `@reboot`および`*/10 * * * *`                                 |

* [ ] 確認済みなのは、テストユーザーのSSH接続と削除、数字を含まないパスワードの拒否、sudoの3回失敗制限とI/Oログ、VirtualBoxコンソールへの10分ごとのcron配信です。

評価前に残っている確認事項は次のとおりです。

- GUIが網羅的に入っていないこと
- SSH端末にも`wall`が届くこと（VirtualBoxコンソールへの配信は確認済み）
- 評価開始時のsnapshot状態と私用Macを使う評価運用
- VMを起動・変更した場合のsignature再取得

## 2. 安全に確認するための原則

- VMコンソールを復旧経路として残す。
- SSH設定は`sshd -t`、sudo設定は`visudo -c`で検証してからサービスを再起動する。
- UFWは4242/tcpを許可してから有効化する。
- 動作中のSSHセッションを閉じる前に、別端末から新しい接続に成功することを確認する。
- passwordとLUKS passphraseをリポジトリや画面共有に出さない。
- signature取得後はVMを起動しない。起動または変更したら完全停止後に再取得する。

## 3. セキュリティ全体像

```text
保存データ -> LUKS
容量管理   -> LVM
リモート入口 -> SSH 4242 / root login禁止
ネットワーク入口 -> UFW
権限昇格   -> sudo
認証品質   -> PAM / pwquality / chage
プロセス制御 -> AppArmor
定期観測   -> cron / monitoring.sh / wall
```

単一の設定で安全にするのではなく、保存、ネットワーク、権限、認証、実行制御を層として組み合わせています。

## 4. OS、hostname、GUI

```bash
hostnamectl
cat /etc/hostname
cat /etc/hosts
cat /etc/os-release
systemctl get-default
systemctl status display-manager
```

確認すること:

- hostnameが`mhashimo42`
- Debian 13である
- default targetが`graphical.target`ではない
- display manager、デスクトップ環境、X.org、Waylandを導入していない

GUIなしなのは、GUIではなくサーバー管理を評価する課題要件だからです。後から削除するより、インストール時から選択しない方が確実です。

## 5. LUKSとLVM

LUKSはブロックデバイスを暗号化する標準形式です。LVMはPVをVGという容量プールにまとめ、LVを切り出して容量を管理します。

```text
disk -> partition -> LUKS -> PV -> VG -> LV -> filesystem
```

LUKSだけでは容量管理にならず、LVMだけでは暗号化になりません。このVMで実際に確認済みのLVはroot、home、swapです。旧設計にあった`/var`、`/var/log`、`/tmp`などの個別LVは作成済みと説明しないでください。

```bash
lsblk
lsblk -f
findmnt /
findmnt /home
swapon --show
```

確認・説明すること:

- `crypto_LUKS`の下に複数のLVM logical volumeがある
- root、homeのfilesystemとmount pointが意図どおりで、swapが有効
- `/boot`は通常GRUBが読むためLUKSの外側にある
- LVを分けると容量枯渇の影響範囲を分けやすく、容量変更にも対応しやすい

## 6. ユーザーとグループ

```bash
id mhashimo
getent group user42
getent group sudo
getent passwd mhashimo
```

`mhashimo`が`user42`と`sudo`に所属することを確認します。評価者から新規ユーザー作成を求められた場合の例は次のとおりです。

```bash
sudo adduser reviewer42
sudo usermod -aG user42 reviewer42
id reviewer42
sudo deluser --remove-home reviewer42
```

## 7. SSHとUFW

SSHは暗号化されたリモート管理プロトコルです。4242は課題要件ですが、ポート変更だけで安全になるわけではありません。一般ユーザーで接続し、必要なコマンドだけ`sudo`で昇格することでrootの直接ログインを避けます。

UFWはiptables/nftablesを扱うフロントエンドです。基本方針はincoming deny、outgoing allow、4242/tcp allowです。

```bash
sudo sshd -t
sudo sshd -T | grep -E '^(port|permitrootlogin) '
sudo ss -ltnp
sudo ufw status numbered
sudo ufw status verbose
```

確認すること:

- SSHは4242でlistenしている
- `permitrootlogin no`
- UFWはactive、incoming default deny
- 4242/tcp以外に不要な受信許可がない
- 別端末から`mhashimo`の接続に成功し、rootの接続は拒否される

rootは全権限を持つため、root SSHを許すと認証突破時の被害が一般ユーザー経由のsudoより大きくなります。設定を変更するときは4242を許可してからUFWを有効化し、接続確認まで既存セッションとVMコンソールを残します。

## 8. パスワードポリシー

password agingとpassword qualityは別の仕組みです。

- `/etc/login.defs`: 新規ユーザーに適用するagingのデフォルト
- `chage`: 既存アカウントのaging
- PAMの`pam_pwquality`: password変更時の品質判定
- `/etc/security/pwquality.conf`: 品質ルールの値

```bash
grep -E '^(PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_WARN_AGE)' /etc/login.defs
sudo chage -l mhashimo
sudo chage -l root
grep -E '^(minlen|ucredit|lcredit|dcredit|maxrepeat|usercheck|difok)' /etc/security/pwquality.conf
grep -n pam_pwquality /etc/pam.d/common-password
```

期待値:

```text
PASS_MAX_DAYS=30
PASS_MIN_DAYS=2
PASS_WARN_AGE=7
minlen=10
ucredit=-1
lcredit=-1
dcredit=-1
maxrepeat=3
usercheck=1
difok=7
```

`credit`が負数なのは、その文字種を少なくとも1文字要求するためです。`maxrepeat=3`は同一文字4連続を拒否します。`difok=7`の課題上の動作確認は非rootユーザーで行います。実際のpasswordは見せず、無効な候補と有効な候補の結果だけを説明します。

## 9. sudo

sudoは、許可されたユーザーが必要なコマンドだけ一時的に別ユーザー（通常はroot）の権限で実行する仕組みです。

| 設定                           | 意味                         |
| ------------------------------ | ---------------------------- |
| `passwd_tries=3`             | 認証試行を3回に制限          |
| `badpass_message`            | 失敗時に独自メッセージを表示 |
| `log_input` / `log_output` | 入出力を記録                 |
| `iolog_dir`                  | I/Oログの保存先              |
| `requiretty`                 | TTYなしの実行を拒否          |
| `secure_path`                | sudo実行時のPATHを固定       |

```bash
sudo visudo -c
sudo stat -c '%A %U:%G %n' /etc/sudoers.d/born2beroot
sudo grep -R -E 'passwd_tries|badpass_message|log_input|log_output|iolog_dir|requiretty|secure_path' /etc/sudoers /etc/sudoers.d
sudo -k
sudo -l
sudo find /var/log/sudo -maxdepth 2 -type f -print
```

確認すること:

- sudoersのsyntaxがvalid
- policy fileはroot所有で、一般ユーザーが書き込めない
- password試行3回、独自メッセージ、TTY、`secure_path`が設定されている
- `/var/log/sudo/`にI/Oログが生成される

sudoersのsyntax errorはsudo全体を壊す可能性があります。`/etc/sudoers`を直接編集せず、`visudo -f /etc/sudoers.d/born2beroot`を使います。

## 10. AppArmor、サービス、パッケージ管理

```bash
systemctl is-enabled apparmor ssh ufw cron
systemctl is-active apparmor ssh ufw cron
sudo aa-status
```

4サービスが起動時有効かつactiveであり、AppArmor moduleとprofileが読み込まれていることを確認します。

AppArmorとSELinuxは、どちらもLinux Security Modulesを利用するMAC（強制アクセス制御）です。

- AppArmorはプログラムのパスを中心にprofileを記述し、比較的導入しやすい
- SELinuxはファイルやプロセスにlabelを付け、label間のpolicyで許可・拒否する
- DebianではAppArmor、Rocky LinuxではSELinuxを使う
- UFWはネットワーク通信、AppArmorはプロセスの操作を制御するため、役割が異なる

`apt`は日常操作やスクリプトで標準的に使われます。`aptitude`は依存関係の候補を対話的に検討しやすいツールです。どちらもパッケージ管理のフロントエンドです。

## 11. cron、wall、monitoring.sh

VM上の`/usr/local/bin/monitoring.sh`は標準出力へ表示し、rootのcrontabがその出力を`wall`へ渡します。

```cron
@reboot /usr/local/bin/monitoring.sh | /usr/bin/wall
*/10 * * * * /usr/local/bin/monitoring.sh | /usr/bin/wall
```

`*/10`は分フィールドが0、10、20、30、40、50のときにrootとして実行する指定です。`@reboot`は起動時に1回実行します。`wall`はログイン中の端末へメッセージをbroadcastします。

```bash
sudo /usr/local/bin/monitoring.sh
sudo crontab -l
sudo stat -c '%A %U:%G %n' /usr/local/bin/monitoring.sh
```

次の12項目が空欄なく表示されることを確認します。

| 項目                  | 主な取得元                                   |
| --------------------- | -------------------------------------------- |
| architecture / kernel | `uname -a`                                 |
| physical CPU          | `lscpu -p=SOCKET`                          |
| vCPU                  | `/proc/cpuinfo`の`processor`行数         |
| RAM                   | `free`                                     |
| storage               | `df`                                       |
| CPU usage             | `/proc/stat`の差分                         |
| last boot             | `uptime -s`                                |
| LVM                   | `lsblk`                                    |
| established TCP       | `ss`                                       |
| logged-in users       | `who`                                      |
| IPv4 / MAC            | `ip` / sysfs                               |
| sudo command count    | `/var/log/sudo/sudo.log`の`COMMAND=`件数 |

値が空なら取得元コマンドを単体で実行し、ネットワークインターフェース名、journalの有無、ログ形式などVMごとの差を切り分けます。「スクリプトを変更せず監視を停止」と求められた場合は、スクリプトではなくroot crontabの2行をコメントアウトします。

## 12. signature

signatureはGitのcommit hashではなく、電源停止中の仮想ディスクファイルに対するSHA-1です。VMを起動・変更すると仮想ディスクが変わり得るため、再取得が必要です。

1. VMを完全停止する。
2. snapshotの有無と、hash対象が実データを保持する正しい仮想ディスクか確認する。
3. ホスト側で対象ディスクのSHA-1を計算する。
4. 40桁のhex digestだけを`submit/signature.txt`へ書く。
5. その後はVMを起動しない。

リポジトリのrootで形式だけを確認するコマンド:

```bash
grep -Eq '^[0-9a-fA-F]{40}$' submit/signature.txt
```

## 13. 評価中に設定変更を求められた場合

次の順序を守ります。

1. 変更対象と現在値を確認する。
2. バックアップまたは復旧経路を確保する。
3. 設定を変更する。
4. `sshd -t`や`visudo -c`などで構文を検証する。
5. 必要なサービスだけreloadまたはrestartする。
6. 別端末から期待する動作を確認する。

ネットワークや認証の変更中は、既存SSHセッションとVMコンソールを最後まで残します。

## 14. 最終セルフテスト

資料を見ずに次を説明できれば準備完了です。

- LUKS、PV、VG、LV、filesystemの関係
- 実VMに存在するLVと、存在しない個別LV
- `sshd -t`と`sshd -T`の違い
- UFWを有効にする安全な順序
- `/etc/login.defs`と`chage`の違い
- PAMと`pwquality.conf`の関係
- `visudo`を使う理由
- cronの5フィールド、`*/10`、`@reboot`
- `monitoring.sh`の12項目と取得元
- `wall`が表示する端末
- AppArmorとSELinux、UFWの役割の違い
- signatureをVM停止後に取得する理由

最後に、VM上の実際の出力と、このガイドの「最初に把握する実VMの状態」が一致することを確認してください。
