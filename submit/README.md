*This project has been created as part of the 42 curriculum by mhashimo.*

# Born2beRoot

## Description

学内のx86_64端末上にVirtualBox 7.0.26でDebian 13 AMD64の仮想サーバーを構築し、暗号化ディスク、ユーザー・権限管理、SSH、ファイアウォール、定期監視を設定するシステム管理の課題です。GUIを使わず、必要なサービスに絞ったサーバーを構築し、設定の意味と動作を説明できることを目標とします。

提出物は、この `README.md` と `signature.txt` を提出リポジトリのルートに置いたものです。VM本体はGitに含めません。以下に構成と採用理由、評価順の説明・実演手順を示します。

## Project description

### OSの選択と比較：Debian vs Rocky Linux

Debianを選んだ理由は、課題が初学者向けに推奨しており、豊富な資料を参照しながらAPT・UFW・AppArmorで基本的なサーバー管理を学べるためです。

| 比較軸 | Debian（採用） | Rocky Linux |
| --- | --- | --- |
| 系統・管理 | Debian系、dpkg・APT、`.deb` | RHEL互換、RPM・DNF、`.rpm` |
| 長所 | stableの安定性、豊富なパッケージと資料 | RHEL互換の運用・企業向け環境を学べる |
| 短所・負担 | 安定性重視のため最新機能が必要な用途に合わない場合がある | 初学者にはSELinuxやfirewalldの設定も含め学習負担がある |
| この課題での保護機構 | AppArmor・UFW | SELinux・firewalld |

### 主な設計上の選択

| 項目 | 構成と目的 |
| --- | --- |
| 仮想化・起動 | 学内x86_64ホストのVirtualBox 7.0.26、CUIで管理するDebian 13 AMD64。グラフィックサーバーを導入せず、サービスを最小限にする |
| パーティション | EFI、`/boot`、LUKS2内のLVM root/home/swap。暗号化と容量管理を組み合わせる |
| ユーザー管理 | rootとは別に `mhashimo` を作成し、`sudo`・`user42` に所属。管理操作だけsudoで昇格する |
| パスワード | 有効期限30日、変更間隔2日、警告7日前、PAMによる品質検査 |
| ホスト名 | ログやネットワーク上で識別する名前として `mhashimo42` を設定 |
| 権限昇格 | sudo、認証3回制限、独自エラー、入出力ログ、TTY必須、コマンド探索パス制限 |
| ネットワーク制御 | UFW、受信は既定で拒否、許可はSSH用の4242/TCP |
| リモート管理 | OpenSSH、4242/TCP、rootのSSHログイン禁止 |
| プロセス制御 | AppArmorを起動時から有効化し、プロファイルでプログラムの操作を制限 |
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

EFIは起動用、`/boot` はカーネルなどの起動ファイル用です。LUKS2内にroot・home・swapを置き、OSやユーザーデータ、swapへの書き込みを暗号化します。rootとhomeのLVを分けて容量を個別に割り当てます。

### AppArmor vs SELinux

どちらも通常のユーザー・グループ権限に加え、ポリシーで操作を制限する強制アクセス制御です。AppArmorはプログラムのパスを中心とするプロファイルで管理し、個別プログラムの制限を追いやすい点が利点です。SELinuxは主にラベルとポリシーで制御し、詳細な制御ができる一方、ラベルと許可関係の理解が必要です。このVMはDebianのAppArmorを採用しています。

### UFW vs firewalld

どちらもLinuxのパケットフィルタを管理するツールです。UFWはポートや接続元に対する許可・拒否を簡潔に記述でき、この課題の少数のルールに適しています。firewalldはゾーンとサービス単位の管理ができ、ネットワークごとに方針を分ける用途に向きますが、その概念とruntime/permanent設定の区別が必要です。このVMはUFWを採用しています。

### VirtualBox vs UTM

VirtualBoxは複数のホストOSに対応した仮想化ソフトウェアで、VM・ネットワーク・スナップショットをGUIで管理できます。UTMはmacOS向けで、QEMUやAppleの仮想化機能を利用します。異なるCPUアーキテクチャのエミュレーションも選べますが、実行方式によって速度や機能が異なります。いずれもホストとゲストのCPU対応を確認する必要があります。課題はVirtualBoxを基本とし、利用できない場合にUTMを認めているため、この構成はVirtualBoxを採用しました。

## Instructions

コンパイルは不要です。学内のx86_64端末にあるVirtualBoxで構築済みVMを確認します。署名照合、スナップショット確認、VMの起動・再起動、NATポート転送の確認はこのホスト側で行います。署名照合と原本の保護を済ませてからVMを起動します。

**ホスト側**と明記したもの以外は、VM内の一般ユーザーから実行します。パスワードはプロンプトで入力します。再起動・対話編集・SSH接続の前後で操作が切り替わるため、全体を一括実行せず、各項目の説明に沿って進めます。

提出物の欠落・名前や配置の誤り、必須項目の不動作、必要な説明の不足があれば、評価票に従ってその時点で評価を終了します。

### 0. 事前確認

本人立ち会いのもと、学生の端末で正式な提出リポジトリを未使用のディレクトリへクローンします。ホスト側でGit等を置き換えるエイリアス・関数がないことを確認し、補助スクリプトを使う場合は内容を評価者と一緒に読みます。

```sh
# ホスト側。URLを正式な提出先に置き換える。
type -a git shasum diff
alias
git config --show-origin --get-regexp '^alias\.'
git clone 'OFFICIAL_REPOSITORY_URL' born2beroot-evaluation
cd born2beroot-evaluation
git remote -v
git ls-files
ls README.md signature.txt
```

remoteが本人の正式な提出先で、追跡する課題提出ファイルがルートの `README.md` と `signature.txt` だけであることを確認します。Git aliasがなければ `--get-regexp` は出力なし・終了値1です。

### 1. 全般的な確認：署名・スナップショット・起動

クローンしたリポジトリのルートにある `signature.txt` を使います。これは完全停止したVMの仮想ディスク全体のSHA-1で、GitのコミットIDではありません。原本を起動・変更した場合は、提出前に完全停止して再計算する必要があります。

照合前にVirtualBoxで `Born2BeRoot-amd64` が「電源オフ」であることを確認します。評価前から起動中のVMや保存状態のVMは使いません。「設定」→「ストレージ」で接続中のVDIの場所を確認し、次の `VM_DISK` と一致することを確認します。移動している場合は実パスへ置き換えます。

```sh
# ホスト側。VMは電源オフのまま実行する。
VM_DISK='/sgoinfre/mhashimo/Born2BeRoot-x86/Born2BeRoot-amd64/Born2BeRoot-amd64.vdi'
ACTUAL_SIGNATURE=$(mktemp)
shasum -a 1 "$VM_DISK" | awk '{print $1}' > "$ACTUAL_SIGNATURE"
diff -u signature.txt "$ACTUAL_SIGNATURE"
```

期待結果は `diff` の出力なし・終了値0です。不一致なら評価を終了し、その場で提出署名を書き換えて照合を通しません。

署名一致を確認したら、VirtualBoxの「スナップショット」画面で名前付きスナップショットがないことを確認します。その後、停止状態の評価用スナップショット `b2br-evaluation` を作って原本を保護します。代替として「クローン」から `Born2BeRoot-amd64-evaluation` を別ディレクトリへFull Cloneし、複製VDIを参照することを確認しても構いません。

スナップショット方式なら元のVM、クローン方式なら評価用クローンだけを起動します。起動による書き込みが原本VDIに直接入らないよう、保護を済ませてから進めます。

### 2. README.mdの確認

提出リポジトリのルートにある本ファイルの最初の斜体行、`Description`、`Project description` のOS選択・設計・4種類の比較を確認します。実行方法は `Instructions`、参考資料とAIの使用内容は `Resources` に記載しています。

### 3. プロジェクト概要

仮想マシンは、ホスト上の仮想化ソフトウェアがCPU・メモリ・ディスク・ネットワークなどの仮想的なハードウェアを提供し、その中で独立したゲストOSを動かす仕組みです。この構成では学内のx86_64端末がホスト、Debian 13 AMD64がゲストです。

選んだOSはDebianです。初学者向けとして課題が推奨し、資料が豊富で、APT・UFW・AppArmorを使って必要な管理を学べるためです。Debianはdpkg/APTで `.deb` を管理し、RockyはRHEL互換でRPM/DNFを使って `.rpm` を管理します。両者の長所・短所は上の比較表に示しています。

VMは、1台の物理端末で複数のOSを動かす、ホストと作業環境を分離する、構築や障害対応を試す用途に使います。ただしホストの資源を共有するため、ホストの停止や故障の影響は受けます。

`apt` と `aptitude` は、どちらもAPTを利用するパッケージ管理のフロントエンドです。`apt` は端末での対話的な導入・更新・削除に向いたコマンド、`aptitude` はコマンド操作に加えて対話画面を持ち、依存関係の解決候補を検討できます。

AppArmorはプログラムごとのプロファイルでファイルアクセスなどを制限します。通常の所有者・グループ権限に制限を加え、侵害されたプログラムの影響範囲を抑えます。enforceモードは違反を拒否し、complainモードは違反を記録します。保護される範囲は読み込まれたプロファイルによります。

評価中は監視情報が10分ごとに表示されることも確認します。コードと周期変更の実演は最後の監視スクリプトの項目で行います。

### 4. 基本設定

起動時にグラフィカル環境がなく、CUIの認証画面が表示されることを確認します。LUKSのパスフレーズでディスクを解除し、その後、課題のパスワード規則を満たすパスワードでroot以外の `mhashimo` としてログインします。LUKSの解除とOSのユーザー認証は別の操作です。

```sh
dpkg-query -W -f='${binary:Package}\t${db:Status-Status}\n' | grep -Ei 'xserver|xorg|xwayland|weston|gdm|lightdm|sddm|task-.*desktop|gnome-shell|plasma-desktop'
whoami
systemctl is-active ufw
systemctl is-active ssh
cat /etc/os-release
```

パッケージ一覧では `installed` のグラフィックサーバーがないことを確認します。共有ライブラリはサーバー本体と区別し、CUIで起動したことだけでは未導入と判断しません。続く期待結果は、ユーザー名が `mhashimo`、UFW・SSHがそれぞれ `active`、OSがDebianです。

### 5. User step 1：ユーザー・パスワードポリシー

```sh
id mhashimo
sudo adduser reviewer42
```

`mhashimo` が存在し、`sudo` と `user42` の両方に所属することを確認します。新規ユーザーには、評価者が選んだ規則を満たすパスワードを設定します。以後はこのユーザーを使います。`reviewer42` が既に存在する場合は未使用名に読み替え、全実演が終わるまで削除しません。

次に、期限と品質を設定したファイルを示します。

```sh
grep -E '^(PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_WARN_AGE)' /etc/login.defs
sudo chage -l reviewer42
sudo chage -l mhashimo
sudo chage -l root
sudo cat /etc/pam.d/common-password
sudo cat /etc/security/pwquality.conf
sudo find /etc/security/pwquality.conf.d -maxdepth 1 -type f -name '*.conf' -exec cat {} \;
```

`/etc/login.defs` は新規アカウントの期限の既定値です。`chage -l` は各アカウントに適用されている期限を表示します。PAMは認証やパスワード変更の処理をモジュールに分ける仕組みで、`common-password` から `pam_pwquality` を呼び、品質を検査します。`pwquality.conf`、追加の `.conf`、PAM行の引数を合わせて有効な設定を説明します。追加設定ディレクトリがなければ最後のコマンドのエラーは想定内です。

| 要件 | 設定と意味 |
| --- | --- |
| 有効期限30日 | `PASS_MAX_DAYS 30` |
| 変更間隔2日 | `PASS_MIN_DAYS 2` |
| 期限の7日前に警告 | `PASS_WARN_AGE 7` |
| 最低10文字 | `minlen=10`。正の文字種creditで実際の最低長が短縮されないようにする |
| 大文字・小文字・数字を含む | `ucredit=-1`、`lcredit=-1`、`dcredit=-1`。負の値は各文字種の最低必要数 |
| 同一文字の連続は3文字まで | `maxrepeat=3` |
| ユーザー名を含めない | `usercheck=1` |
| 前のパスワードに含まれない文字を7文字以上含む | `difok=7`。変更時の挿入・削除・置換などの差分を検査 |
| rootにも品質を強制 | `enforce_for_root`。不適合な候補を警告だけでなく拒否 |

旧パスワードとの比較だけはrootのパスワードに適用しません。rootによる変更では旧パスワードを入力しないため、一般ユーザーの旧新比較はそのユーザー自身の `passwd` で確認します。`sudo passwd reviewer42` では旧新比較になりません。最小2日の期限による拒否と品質による拒否を区別し、設定後にrootを含む既存アカウントのパスワードも変更したことを説明します。

### 6. User step 2：グループ・ポリシーの利点と負担

未使用の `evaluating` グループを作り、新規ユーザーを追加します。

```sh
sudo groupadd evaluating
sudo usermod -aG evaluating reviewer42
id reviewer42
```

期待結果は `reviewer42` の所属に `evaluating` があることです。グループは複数ユーザーの権限をまとめて管理する仕組みです。`usermod -aG` の `-a` は既存の補助グループを残して追加する指定で、変更は次のログインセッションから反映されます。

長さ・文字種・連続文字・名前の制限は、推測しやすいパスワードを減らします。期限は同じ認証情報を使い続ける期間を制限し、旧新の差分は小さな変更だけでの再利用を抑えます。一方、複雑さや定期変更の強制は記憶と変更の負担を増やし、単純な変更パターンや使い回しを誘発する場合があります。

### 7. ホスト名とパーティション

```sh
hostnamectl --static
sudo hostnamectl set-hostname EVALUATOR_LOGIN42
sudoedit /etc/hosts
```

最初の表示は `mhashimo42` です。`EVALUATOR_LOGIN42` は評価者のログイン名に `42` を付けた値に置き換えます。ホスト名は機械を識別する名前で、`hostnamectl` は永続設定も更新します。`/etc/hosts` の `127.0.1.1` などにある旧名も新名に合わせ、localhostの行は保持します。

```sh
sudo reboot
```

コンソールでLUKSを解除し、再ログインして変更の永続化を確認します。その後、元の名前へ戻します。

```sh
hostnamectl --static
sudo hostnamectl set-hostname mhashimo42
sudoedit /etc/hosts
```

再起動後の最初の表示が評価者のログイン名＋`42` であることを確認し、`/etc/hosts` の名前も `mhashimo42` に戻します。

```sh
lsblk -f
```

暗号化領域の下にLVMのroot/home/swapがあり、`/`・`/home`・swapとして使われていることを課題の必須例と比較します。

LVM（Logical Volume Manager）は容量を柔軟に割り当てる仕組みです。ディスクやパーティションをPV（物理ボリューム）として登録し、VG（ボリュームグループ）にまとめ、そこからLV（論理ボリューム）を切り出します。このVMはLUKS2の暗号化領域をPVとし、`mhashimo-vg` からroot・home・swapを作っています。LUKSがデータを暗号化し、LVMが容量を管理します。

### 8. SUDO

```sh
dpkg-query -W -f='${db:Status-Status}\n' sudo
sudo usermod -aG sudo reviewer42
id reviewer42
sudo /usr/bin/id
```

期待結果はパッケージが `installed`、新規ユーザーの所属に `sudo`、`sudo /usr/bin/id` の実効ユーザーがrootであることです。sudoは許可されたユーザーがコマンドを別ユーザー（通常root）の権限で実行する仕組みです。一般ユーザーの日常操作と管理操作を分け、誰が何を実行したかを記録できます。

設定ファイルでは、次の厳密なルールの実装を示します。

```sh
sudo cat /etc/sudoers.d/born2beroot
```

| 設定 | 意味 |
| --- | --- |
| `passwd_tries=3` | 1回の認証でパスワード誤入力を3回までに制限 |
| `badpass_message` | 誤入力時の独自メッセージ |
| `logfile` | コマンド履歴を `/var/log/sudo/sudo.log` に保存 |
| `log_input`・`log_output`・`iolog_dir` | 入出力を記録し、I/Oログを `/var/log/sudo/` 内に保存 |
| `requiretty` | TTY（端末）がない状態でのsudo実行を拒否 |
| `secure_path` | sudo実行時のコマンド探索パスを制限 |

続いてログディレクトリとファイルを確認し、コマンド実行前後の履歴を比較します。

```sh
sudo ls -l /var/log/sudo/
sudo tail -n 10 /var/log/sudo/sudo.log
sudo /usr/bin/id
sudo tail -n 10 /var/log/sudo/sudo.log
```

期待結果はディレクトリ内にログファイルがあり、既存のコマンド履歴が読め、実行後に `COMMAND=/usr/bin/id` が追加されることです。コマンド履歴と入出力ログは別の記録です。

### 9. UFW / Firewalld

```sh
dpkg-query -W -f='${db:Status-Status}\n' ufw
```

`installed` で、基本設定で確認したサービスが `active` であることが必要です。UFWはLinuxのパケットフィルタを設定するための管理ツールです。不要な受信接続を拒否して、ネットワークからアクセスできるサービスを限定します。このVMは受信を既定で拒否し、SSH用の4242/TCPだけを許可します。

```sh
sudo ufw status verbose
sudo ufw allow 8080/tcp
sudo ufw status verbose
sudo ufw delete allow 8080/tcp
sudo ufw status verbose
```

開始時はUFWが `active` で4242/TCPのみ許可されていること、追加後は8080/TCPが増えること、削除後は元のルールに戻ることを確認します。IPv6が有効なら対応するルールも対象です。ポートの許可は通信の制御であり、そのポートでサービスを起動する操作ではありません。

### 10. SSH

```sh
dpkg-query -W -f='${db:Status-Status}\n' openssh-server
```

`installed` で、基本設定で確認したサービスが `active` であることが必要です。SSHはサーバー認証とユーザー認証を行い、通信を暗号化してリモート操作する仕組みです。パスワードや操作内容を平文で流さず、VMに別端末から安全に接続できます。

```sh
sudo /usr/sbin/sshd -T | grep -E '^(port|permitrootlogin) '
sudo ss -ltnp
```

期待結果は `port 4242`、`permitrootlogin no` です。実効設定と実際の待受を確認し、SSHプロセスが4242だけを使っていることを示します。IPv4とIPv6で複数行でも同じポートなら構いません。

**学内ホスト側の別端末**から、新規ユーザーで接続します。この環境はVirtualBoxのNATでホスト4242→VM4242を転送します。別ホストやブリッジ接続を使う場合は、接続先と転送設定を確認して読み替えます。

```sh
ssh -p 4242 reviewer42@localhost
```

新規ユーザーのパスワードでログインし、そのSSHセッション内でユーザー名を確認して退出します。

```sh
whoami
exit
```

**ホスト側**でrootの接続を試します。

```sh
ssh -p 4242 root@localhost
```

同じ接続先に対し `reviewer42` は成功し、rootは拒否されることを確認します。`PermitRootLogin no` はrootの直接接続を禁止する設定です。一般ユーザーとして接続し、必要な管理操作だけsudoで行います。

### 11. 監視スクリプト

まずコードを示し、取得・集計・出力の流れを説明します。

```sh
sudo cat /usr/local/bin/monitoring.sh
```

`monitoring.sh` はBashで情報を集計して標準出力へ表示します。リポジトリのスクリプトをVMへ転送し、root所有・権限0755で配置しています。rootのcronがその出力を `wall` に渡し、ログイン中の全端末へ配信します。

| 表示項目 | コードの取得・集計方法 |
| --- | --- |
| OSアーキテクチャ・カーネル | `uname -a` |
| 物理CPU数・vCPU数 | `lscpu` のソケットIDを重複除去、`/proc/cpuinfo` のprocessor行を数える |
| RAM使用量・割合 | `free` のused/totalと百分率 |
| ディスク使用量・割合 | `df` でtmpfs等を除いた合計 |
| CPU使用率 | `/proc/stat` を1秒間隔で読み、全時間とidle＋iowaitの差分から計算 |
| 最終起動日時 | `uptime -s` |
| LVMの有無 | `lsblk` にtypeがlvmの行があるか |
| TCP接続数 | `ss -tan` のESTAB行を数える |
| ログインユーザー数 | `who` のユーザー名を重複除去して数える |
| IPv4・MAC | デフォルトルートのインターフェースを `ip` とsysfsで参照 |
| sudo実行回数 | `/var/log/sudo/sudo.log` のCOMMAND=行を数える |

RAMとディスクは課題の表示例に合わせて使用量・総量・割合を表示します。CPU使用率は2回の読み取りの差分です。sudo回数は現在のログに残る件数であり、ログローテーション前の履歴を合算しません。

cronは指定した時刻にコマンドを実行する仕組みです。時刻指定の5欄は「分・時・日・月・曜日」で、ユーザーのcrontabには実行ユーザー欄を付けません。このVMはrootのcrontabに次の2行を登録します。

```sh
sudo crontab -l
```

```cron
@reboot /usr/local/bin/monitoring.sh | /usr/bin/wall
*/10 * * * * /usr/local/bin/monitoring.sh | /usr/bin/wall
```

`@reboot` はcron起動時に1回、`*/10` は毎時0・10・20・30・40・50分に実行します。起動が12:03なら、起動時に続き12:10、12:20…となり、起動時刻から厳密な600秒間隔ではありません。コンソールとSSH端末を開き、通常周期で全端末に通知が届き、エラーが表示されないことを確認します。

#### 毎分実行へ変更

再起動後の比較のため、スクリプトの内容・権限を記録します。保存先が既にある場合は未使用名に置き換え、同じ実演中はその名前を使います。

```sh
sudo sh -c 'sha256sum /usr/local/bin/monitoring.sh > /root/b2br-monitoring.sha256'
sudo sh -c 'stat -c "%a %U:%G %n" /usr/local/bin/monitoring.sh > /root/b2br-monitoring.stat'
sudo crontab -e
```

10分ごとの行を次に置き換えます。

```cron
* * * * * /usr/local/bin/monitoring.sh | /usr/bin/wall
```

分の境界を2回以上またぎ、毎分の通知を確認します。ホスト側で新規ユーザーのSSH接続・切断を行い、TCP接続数とログイン人数の変化を確認します。VM内で次を実行し、後の通知でsudo件数が増えることも確認します。

```sh
sudo /usr/bin/id
```

#### スクリプトを変更せず停止し、再起動

```sh
sudo crontab -e
```

起動時と毎分の両方をコメントアウトします。スクリプトの編集・削除・権限変更は行いません。

```cron
# @reboot /usr/local/bin/monitoring.sh | /usr/bin/wall
# * * * * * /usr/local/bin/monitoring.sh | /usr/bin/wall
```

```sh
sudo reboot
```

LUKS解除・ログイン後、同じ場所にスクリプトがあり、内容・権限・所有者が変わっていないことを確認します。

```sh
sudo sha256sum -c /root/b2br-monitoring.sha256
sudo sh -c 'stat -c "%a %U:%G %n" /usr/local/bin/monitoring.sh > /root/b2br-monitoring.after.stat'
sudo diff -u /root/b2br-monitoring.stat /root/b2br-monitoring.after.stat
sudo crontab -l
```

期待結果はハッシュが `OK`、`diff` が差分なし、監視の2行がコメントのままであることです。再起動後も毎分の境界を2回以上またぎ、通知が来ないことを確認します。

### 12. ボーナス

ボーナスは必須項目がすべて合格した場合のみ評価します。このREADMEで扱うのはroot/home/swapの必須構成で、ボーナスの追加パーティション・WordPress・自由選択サービスは対象に含めません。

### 評価終了後

停止の確認を終えてから、評価用VMを停止します。

```sh
sudo poweroff
```

VirtualBoxで「電源オフ」になるまで待ちます。クローン方式では評価用クローンの名前と保存先を確認して削除し、原本へ変更を反映しません。スナップショット方式では `b2br-evaluation` を選んで「復元」し、評価後の状態を新たに保存せず、復元完了後に同スナップショットを「削除」します。削除だけで評価中の変更をマージしないよう、必ず復元を先に行います。

最後に原本VMが電源オフ・スナップショットなしであることを確認し、1節の同じ `VM_DISK` でSHA-1照合を再実行します。`diff` は出力なし・終了値0が期待結果です。不一致なら署名を書き換えず、復元手順と起動したディスクを確認します。

## Resources

- 課題本文：Born2beRoot Version 5.2。構築要件、README要件、提出方法。
- [Debian公式ドキュメント](https://www.debian.org/doc/)：OSと管理の基本。
- [apt(8)](https://manpages.debian.org/trixie/apt/apt.8.en.html)：aptの用途。
- [pam_pwquality(8)](https://manpages.debian.org/trixie/libpam-pwquality/pam_pwquality.8.en.html)：品質設定、rootへの適用、旧新比較。
- [sudoers(5)](https://manpages.debian.org/trixie/sudo/sudoers.5.en.html)：sudoの権限とログ設定。
- [crontab(5)](https://manpages.debian.org/trixie/cron/crontab.5.en.html)：時刻指定と起動時実行。
- [Oracle VM VirtualBox 7.0 User Guide](https://docs.oracle.com/en/virtualization/virtualbox/7.0/user/)：VM状態、スナップショット、クローンの公式手順。
- VM内の `man sshd_config`、`man ufw`、`man lvm`、`man cryptsetup`、`man wall`：インストール済み版の設定・操作。

### AI usage

AIは、課題・評価票の整理と日本語訳、レビュー説明資料と本READMEの文章・確認コマンドの整理、PDFのREADME要件との照合、監視シェルスクリプトのレビュー補助に使用しました。VMの構築・設定適用・実行結果の確認と、評価時の説明は自分で行います。
