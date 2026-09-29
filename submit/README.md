*This project has been created as part of the 42 curriculum by mhashimo.*

# Born2beRoot

## Description

VirtualBox上にDebian 13 AMD64の仮想サーバーを構築し、暗号化ディスク、ユーザー・権限管理、SSH、ファイアウォール、定期監視を設定するシステム管理の課題です。GUIを使わず、設定の意味と動作を説明できることを目標とします。

提出物は、この `README.md` と `signature.txt` を**提出リポジトリのルート**に置いたものです。VM本体はGitに含めません。このREADMEだけで評価手順を追えるよう、下に実演コマンドと期待結果を記載しています。

### 確認状況

構成情報は2026-09-30に学内のx86_64端末上で再構築・再起動検証した実VMに基づきます。4242/TCPのSSH接続とroot接続拒否、不適合パスワードの拒否、sudoの3回失敗制限・独自メッセージ・I/Oログ、複数SSH端末への手動 `wall` 配信、cronの起動時および00・10・20分の実行履歴を確認しました。主なGUIパッケージとdesktop taskの不在、`multi-user.target`、評価開始用VMにスナップショットがないことも確認済みです。

`signature.txt` は2026-09-30に完全停止した `Born2BeRoot-amd64.vdi` のSHA-1です。以後原本を起動・変更していれば、提出前に完全停止して再計算する必要があります。以下の手順を記載したことは、評価中のすべての変更操作を事前に実演したことを意味しません。

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
| 仮想化・起動 | VirtualBox 7.0.26、CUIで管理するDebian 13 AMD64 |
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

### 評価時に説明するプロジェクト概要

**仮想マシンとは何か。** ホストOS上のVirtualBoxが、物理端末のCPU・メモリ・ストレージ・ネットワークを仮想ハードウェアとしてゲストOSへ提供し、その中で独立したDebianを動かす仕組みです。同じ物理端末上で環境を分離し、サーバー構築・設定変更・障害対応を安全に学べることが主な用途です。ただし、資源と障害点をホストと共有するため、物理的に独立した別サーバーと同じではありません。

**なぜDebianか。** Debian stableは安定性を重視し、APTの資料が豊富で、課題指定のUFW・AppArmorを使った基本的な管理を学びやすいためです。対してRocky LinuxはRHEL互換で、RPM/DNF、SELinux、firewalldを使う企業系の運用を学べます。DNFはRPMパッケージの導入・更新・削除と依存関係の解決を行うパッケージ管理ツールです。Debianは新機能の収録が遅い場合があり、Rockyはこの課題の初学者にとってSELinux等を含む学習範囲が広い、という負担があります。

**`apt` と `aptitude` の違い。** どちらもDebianのパッケージ管理を扱うフロントエンドですが、`apt` は日常の対話操作向けに、検索・導入・更新などの主要機能を簡潔にまとめたコマンドです。`aptitude` は別パッケージのフロントエンドで、対話型UIと依存関係の解決候補を提示する機能があります。`aptitude` は `apt` の別名ではありません。スクリプトでは表示形式を安定APIとしない `apt` より、用途に応じて `apt-get` や `apt-cache` を使います。

**AppArmorとは何か。** 通常の所有者・グループ権限に加え、プログラムごとのプロファイルでファイル等へのアクセスを制限する強制アクセス制御です。`enforce` モードは違反を拒否し、`complain` モードは主に記録します。サービスがactiveなだけで全プログラムが保護されるわけではないため、読み込まれたプロファイルとモードを `aa-status` でも確認します。

**最小構成にした理由。** サーバーに不要なGUIやサービスを入れなければ、資源消費、更新対象、待受ポート、攻撃対象領域を減らせます。必要な管理サービスだけをCUIで運用し、一般ユーザーでログインして、必要なコマンドだけsudoで昇格します。

## Instructions

コンパイルは不要です。学内のx86_64端末にあるVirtualBoxで構築済みVMを確認します。署名照合、スナップショット確認、VMの起動・再起動、NATポート転送の確認はすべてこのホスト側で行います。

以下はDebian用で、**ホスト側**と明記したもの以外はVM内の一般ユーザーから実行します。コードブロックは項目ごとに使い、再起動・対話編集・SSH接続を含む全体を一括実行しないでください。パスワードはプロンプトで入力します。

各コードブロック直前の **「評価票対応」** は、そのコマンド群で確認する評価票の文章を引用または要約したものです。コード内のコメントは、直後のコマンドが何を確認・変更するかを示します。評価ではコマンドを一括貼り付けせず、コメントと実際の出力を対応させながら1項目ずつ実行します。

評価順：署名と起動 → README・概要 → 基本設定 → ユーザー → ホスト名・LVM → sudo → UFW → SSH → 監視 → ボーナス。

### 0. 起動前：正式な提出物・署名・スナップショット

本人立ち会いのもと、学生の端末で正式な提出リポジトリを空のディレクトリへクローンします。ホスト側でエイリアス・関数やGitの設定を確認し、補助スクリプトを使う場合は内容を一緒に読みます。

**評価票対応：**「学生の端末上で正式なGitリポジトリを空のフォルダへcloneする」「悪意のあるaliasに注意する」「補助スクリプトは学生と一緒に確認する」「ルートに提出物がある」を確認するコマンドです。

```sh
# ホスト側。URLを正式な提出先に置き換える。
# 使用されるgit・shasum・diffが想定した実体か確認する。
type -a git shasum diff
# シェルaliasとGit aliasにコマンドのすり替えがないか確認する。
alias
git config --show-origin --get-regexp '^alias\.'
# 空の新規ディレクトリ名へ正式リポジトリをcloneする。
git clone 'OFFICIAL_REPOSITORY_URL' born2beroot-evaluation
cd born2beroot-evaluation
# 正式なremote、追跡ファイル、ルートの実ファイルを確認する。
git remote -v
git ls-files
ls -la
# READMEの必須先頭行とsignature.txtの存在・内容を確認する。
head -n 1 README.md
cat signature.txt
```

`born2beroot-evaluation` はまだ存在しない名前を使います。Git aliasがなければ `--get-regexp` は出力なし・終了値1となります。remoteのURLと提出者・課題の対応を評価者と確認し、`git ls-files` では課題提出ファイルの `README.md` と `signature.txt` だけが表示されることを確認します。

これは、正式な提出物だけを評価し、aliasや未確認スクリプトによる表示・コマンドのすり替えを避けるためです。Gitで追跡する課題提出ファイルは `README.md` と `signature.txt` で、VDIそのものはGitへ含めません。提出物欠落、ファイル名違い、署名不一致、起動不能など評価票の終了条件に該当した場合は、その場で取り繕わず評価を終了します。

#### 0-1. VM名・停止状態・スナップショットの確認

**ここではまだVMを起動しません。** VirtualBox Managerを開き、左側で評価対象VMを選びます。VM名の下の状態が「電源オフ（Powered Off）」であることを確認します。「実行中（Running）」や「保存（Saved）」なら評価を開始しません。対象VMのメニューから「スナップショット（Snapshots）」を開き、名前付きスナップショットがなく、`Current State` だけであることを確認します。

同じ状態はホスト側のCLIでも確認できます。`VM_NAME` は `VBoxManage list vms` に表示された正確な名前へ置き換えます。

**評価票対応：**「スナップショットが存在しない」「評価開始前から動いているVMは受け入れない」を、起動前に確認するコマンドです。

```sh
# ホスト側。まだstartvmは実行しない。
# 登録VMから評価対象の正確な名前を特定する。
VBoxManage list vms
VM_NAME='Born2BeRoot-amd64'
# 対象VMが既に実行中でないことを確認する。
VBoxManage list runningvms
# 保存状態ではなくVMState="poweroff"であることを確認する。
VBoxManage showvminfo "$VM_NAME" --machinereadable | grep -E '^(name|VMState|CfgFile|SnapFldr)='
# 名前付きスナップショットがないことを確認する。
VBoxManage snapshot "$VM_NAME" list
```

期待結果は、対象VMが `list runningvms` に現れず、`VMState="poweroff"` であることです。`snapshot list` はスナップショットがない旨を表示し、名前付きスナップショットを列挙しません。この条件を確認する前から動いていたVMや、保存状態のVMは受け入れません。

#### 0-2. 接続ディスクと署名の確認

VirtualBox Managerで対象VMの「設定（Settings）」→「ストレージ（Storage）」を開き、ストレージコントローラー配下の仮想ハードディスクを選択します。右側に表示される場所が、署名対象の `Born2BeRoot-amd64.vdi` であることを確認します。CLIでは次の出力の「Storage」欄でも、接続中のディスクの絶対パスを確認できます。

**評価票対応：**「必要なら `.vdi` の場所を学生に尋ねる」「VirtualBoxのディスクは `.vdi`」に対し、実際にVMへ接続されている署名対象ディスクを特定するコマンドです。

```sh
# ホスト側。
# Storage欄で接続されたVDIの絶対パスを確認する。
VBoxManage showvminfo "$VM_NAME"
```

このVMはVirtualBoxを使うためディスク拡張子は `.vdi` です。UTMを使った構成では通常 `.qcow2` などになり、その場合はUTMで接続先を確認して実際のディスクファイルをSHA-1の対象にします。VirtualBox用の以下のパスは使いません。

クローンした提出リポジトリのルートで、VirtualBoxに表示された実パスを `VM_DISK` に設定して比較します。

**評価票対応：**「`signature.txt` 内の署名と `.vdi` の署名が一致することを、単純な `diff` で確認する」を実行するコマンドです。

```sh
# ホスト側。VMは電源オフのまま実行する。
VM_DISK='/sgoinfre/mhashimo/Born2BeRoot-x86/Born2BeRoot-amd64/Born2BeRoot-amd64.vdi'
# 指定先が実在するVDIであることを確認する。
test -f "$VM_DISK"
test "${VM_DISK##*.}" = 'vdi'
# 提出署名がSHA-1の40桁形式であることを確認する。
grep -Eq '^[0-9a-fA-F]{40}$' signature.txt
# 停止中VDIからSHA-1だけを一時ファイルへ保存する。
ACTUAL_SIGNATURE=$(mktemp)
shasum -a 1 "$VM_DISK" | awk '{print $1}' > "$ACTUAL_SIGNATURE"
# 提出値と実測値を比較する。出力なし・終了値0が合格。
diff -u signature.txt "$ACTUAL_SIGNATURE"
DIFF_STATUS=$?
# 一時ファイルを削除し、diffの終了値を最終結果にする。
rm "$ACTUAL_SIGNATURE"
test "$DIFF_STATUS" -eq 0
```

期待結果は `diff` の出力なし・終了値0です。署名はGitのコミットIDではなく、完全停止した仮想ディスク全体のSHA-1です。VMを起動するだけでもログ等が書き込まれて署名が変わり得ます。不一致なら評価を止め、提出署名を書き換えてその場の照合を通すことはしません。

#### 0-3. 原本を保護する方法を1つ選ぶ

署名一致と「スナップショットなし」を確認した**後**、次のAかBのどちらか一方を実施します。両方を同時に行う必要はありません。このVMではAの評価専用コールドスナップショットを基本とします。

##### A. 評価専用コールドスナップショット

VirtualBox Managerで、電源オフの対象VMの「スナップショット」を開きます。`Current State` を選択して「作成（Take）」を押し、名前を `b2br-evaluation`、説明を「署名照合後・起動前の評価専用」として作成します。作成後、一覧に `b2br-evaluation` と、その下に `Current State` があることを確認します。

CLIで行う場合は次のとおりです。実行中に作るlive snapshotではなく、`VMState="poweroff"` を確認した後に作成します。

**評価票対応：**「VMを起動する前にコールドスナップショットを作る」を実施し、作成結果を一覧で確認するコマンドです。

```sh
# ホスト側。
EVAL_SNAPSHOT='b2br-evaluation'
# 電源オフ状態から評価専用スナップショットを作る。
VBoxManage snapshot "$VM_NAME" take "$EVAL_SNAPSHOT" --description='署名照合後・起動前の評価専用'
# 作成したスナップショット名と状態を確認する。
VBoxManage snapshot "$VM_NAME" list --details
```

スナップショット作成後の書き込みは差分ディスクへ行われます。評価終了時は後述の手順でこの時点へ復元し、評価専用スナップショットを削除します。

##### B. 独立したフルクローン

VirtualBox Managerで対象VMを右クリックして「クローン（Clone）」を選びます。名前を `Born2BeRoot-amd64-evaluation`、保存先を原本とは別の評価用ディレクトリにし、「Full Clone」と「Current Machine State」を選んで作成します。作成後、クローン側の「設定」→「ストレージ」で、原本のVDIではなく評価用ディレクトリ内の複製VDIを参照していることを確認します。

CLIで同じ操作を行う例です。`EVAL_BASE` は十分な空き容量がある、原本とは別の評価専用ディレクトリにします。

**評価票対応：** コールドスナップショットを使わない場合の「仮想ディスクを別ディレクトリへ複製し、そのコピーから起動する」を実施・確認する代替コマンドです。

```sh
# ホスト側。
EVAL_VM_NAME='Born2BeRoot-amd64-evaluation'
EVAL_BASE='/sgoinfre/mhashimo/Born2BeRoot-x86/evaluation-copy'
# 原本とは別の評価用保存先を用意する。
mkdir -p "$EVAL_BASE"
# 現在の停止中VMを独立したFull Cloneとして複製・登録する。
VBoxManage clonevm "$VM_NAME" --name="$EVAL_VM_NAME" --basefolder="$EVAL_BASE" --mode=machine --register
# クローンが評価用ディレクトリ内の複製VDIを参照することを確認する。
VBoxManage showvminfo "$EVAL_VM_NAME"
```

出力の仮想ディスクが `EVAL_BASE` 配下にあり、原本の `VM_DISK` ではないことを確認します。以降は元のVMではなく `EVAL_VM_NAME` だけを起動します。

#### 0-4. 保護した評価用VMを起動する

AならVirtualBox Managerで元のVMを、Bなら作成した評価用クローンを選び、「起動（Start）」を押します。CLIなら、選択した方法に対応する片方だけを実行します。

**評価票対応：**「評価するVMを起動する」を、原本保護が完了した後に実施するコマンドです。

```sh
# A：評価専用スナップショット方式
VBoxManage startvm "$VM_NAME" --type=gui

# B：フルクローン方式。Aと同時には実行しない。
VBoxManage startvm "$EVAL_VM_NAME" --type=gui
```

起動画面でLUKSパスフレーズを入力して暗号化領域を解除し、ログイン画面でrootではなく `mhashimo` と課題要件を満たすパスワードを使います。ここから先は評価用の状態だけを変更し、原本VDIを直接起動・接続し直しません。

### 1. READMEと概要の説明

冒頭の斜体の作成者行、`Description`、`Project description`、4つの比較、`Instructions`、`Resources` を確認します。口頭では上の「評価時に説明するプロジェクト概要」を自分の言葉で説明し、設定やコマンドを質問されたときは暗記した一文だけでなく、実VMの状態と結び付けて答えます。監視通知が評価中も10分ごとに出ることを確認し、出ない場合は後回しにせずcron・wall・端末の書込許可を調べます。

### 2. 基本設定・サービス

**評価票対応：**「GUIがない」「rootではないユーザーでログイン」「UFWとSSHが起動」「OSがDebianまたはRocky」「AppArmorが起動」をまとめて確認するコマンドです。

```sh
# 「rootではないユーザーでログイン」を確認する。
whoami
id
# 「選んだOSがDebianまたはRocky」を確認する。
cat /etc/os-release
uname -m
# login42形式のホスト名も同時に確認する。
hostnamectl
# 「グラフィカル環境がない」を起動ターゲット・サービス・パッケージから確認する。
systemctl get-default
systemctl status display-manager --no-pager
# 「UFW・SSH・AppArmorが起動時から有効で、現在も動作」を確認する。cronは監視項目用。
systemctl is-enabled apparmor ssh ufw cron
systemctl is-active apparmor ssh ufw cron
# AppArmorの読込済みプロファイルとモードを確認する。
sudo aa-status
# UFWがactiveであることを確認する。
sudo ufw status verbose
# 禁止されたX.org・Waylandや主要desktop環境の候補を抽出する。
dpkg-query -W -f='${binary:Package}\t${db:Status-Status}\n' | grep -Ei 'xserver|xorg|wayland|gdm|lightdm|sddm|task-.*desktop|gnome-shell|plasma-desktop'
```

期待結果：ユーザーはrootではなく `mhashimo`、OSはDebian、ホスト名は `mhashimo42`。CUI起動で、AppArmor・SSH・UFW・cronがenabled/active、UFWはactiveです。display-managerがない場合の「Unit not found」は想定内です。パッケージ一覧は候補抽出であり、共有ライブラリとグラフィックサーバー本体を区別して確認します。`multi-user.target` だけでGUI未導入とは判断しません。

接続前に求められるLUKSパスフレーズは暗号化ディスクの解除、解除後に求められるログインパスワードはOS上のユーザー認証で、目的が異なります。課題が禁止するのはX.org、Wayland等のグラフィックサーバーです。CUIが見えること、`multi-user.target` であること、GUI関連パッケージがないことを組み合わせて確認します。`systemctl is-enabled` は次回以降の起動設定、`is-active` は現在の稼働状態なので、両方を確認します。

### 3. User step 1：既存ユーザー・新規作成・パスワード

この後の評価では一貫して `reviewer42` を新規ユーザーの例として使います。既に存在する場合は別の未使用名に読み替えてください。削除は全実演が終わるまで行いません。

**評価票対応：**「学生のログイン名と同じユーザーが存在し、`sudo`と`user42`に所属」「評価者が選んだパスワードで新しいユーザーを作成」を確認するコマンドです。

```sh
# 既存の学生ユーザーと所属グループを確認する。
id mhashimo
getent group sudo
getent group user42
# 評価用ユーザー名が未使用であることを確認する。
getent passwd reviewer42
# 課題の規則を満たすパスワードを対話入力してユーザーを作る。
sudo adduser reviewer42
# 新規ユーザーへ30日・2日・7日の期限設定が反映されたか確認する。
sudo chage -l reviewer42
```

`mhashimo` はsudo/user42の両方に所属すること、新規ユーザーのパスワード設定で要件を満たす候補が受理されることを確認します。作成前の `getent passwd reviewer42` は未使用なら出力なしです。

**評価票対応：**「要求されたパスワード規則をVM上でどのように設定したか説明する」に対し、期限とPAM品質設定の根拠ファイルを表示するコマンドです。

```sh
# 新規アカウントに使う期限の既定値30/2/7を確認する。
grep -E '^(PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_WARN_AGE)' /etc/login.defs
# 既存の学生ユーザーとrootにも期限が個別適用済みか確認する。
sudo chage -l mhashimo
sudo chage -l root
# pam_pwqualityがパスワード変更処理に組み込まれているか確認する。
sudo cat /etc/pam.d/common-password
# 長さ・文字種・連続文字・ユーザー名・旧新差分・root強制の値を確認する。
sudo cat /etc/security/pwquality.conf
# 追加ファイルによる設定の上書きがないか確認する。
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

期限と品質は別の仕組みです。`/etc/login.defs` の30/2/7は主に新規アカウントの既定値で、既存ユーザーの実値は `chage` で確認します。PAMの `pam_pwquality` は変更時の文字列を検査します。負のcreditはその文字種の最低必要数を意味し、`difok=7` は旧新パスワード間の挿入・削除・置換等の差を検査します。rootによる変更は旧パスワードを尋ねないため、課題どおり旧新差分だけはrootに適用されませんが、`enforce_for_root` により他の品質規則はrootにも拒否として適用されます。

### 4. User step 2：evaluatingグループ

**評価票対応：**「目の前で`evaluating`グループを作り、新規ユーザーを所属させ、最後に所属を確認する」をその順に実演するコマンドです。

```sh
# 同名グループがまだ存在しないことを確認する。
getent group evaluating
# evaluatingを作成する。
sudo groupadd evaluating
# 既存の補助グループを保持したまま新規ユーザーを追加する。
sudo usermod -aG evaluating reviewer42
# ユーザー側・グループ側の両方から所属を確認する。
id reviewer42
getent group evaluating
```

グループ名が未使用であることを確認して作成し、所属を示します。パスワードポリシーの利点（推測しやすい候補の削減など）と負担（記憶・変更の手間や単純な変更パターンの誘発など）も説明します。

グループは複数ユーザーへ同じ権限をまとめて割り当てる仕組みです。`usermod -aG` の `-a` は既存の補助グループを保持するために必要で、`-a` を省くと他グループ所属を失う危険があります。所属変更は既存セッションへ直ちに反映されないため、SSH確認では新しくログインします。強いパスワード規則は推測しやすい候補や同じ認証情報を長期間使う危険を減らす一方、複雑さと頻繁な変更は記憶・運用負担、使い回し、単純な末尾変更を誘発し得るため、あらゆる環境でこの課題の値が最適だとは限りません。

### 5. ホスト名の変更・再起動・パーティション

`EVALUATOR_LOGIN42` を評価者のログイン名に `42` を付けた値へ置き換えます。

**評価票対応：**「ホスト名がlogin42形式」「ログイン名部分を評価者のログイン名へ変更する」を実行し、関連ファイルも確認するコマンドです。

```sh
# 現在のhostnameがmhashimo42であることを確認する。
hostnamectl --static
cat /etc/hostname
# ローカル名前解決に記録された旧hostnameを確認する。
cat /etc/hosts
# 評価者ログイン名+42へ永続hostnameを変更する。
sudo hostnamectl set-hostname EVALUATOR_LOGIN42
# /etc/hostsの対応する旧名も新名へ変更する。
sudoedit /etc/hosts
```

`/etc/hosts` の `127.0.1.1` などにある `mhashimo42` を新名に合わせ、localhostの行は保持します。その後、再起動します。

**評価票対応：**「ホスト名を変更し、再起動後に変更が反映される」を確認するための再起動です。

```sh
sudo reboot
```

コンソールでLUKSを解除し、再ログインして永続化を確認します。

**評価票対応：**「再起動後にホスト名変更が反映されている」を確認し、評価後の作業を続けるため元のホスト名へ戻すコマンドです。

```sh
# 再起動後も評価者名+42が保持されていることを確認する。
hostnamectl --static
cat /etc/hostname
cat /etc/hosts
# 元の提出状態mhashimo42へ戻す。
sudo hostnamectl set-hostname mhashimo42
# /etc/hostsもmhashimo42へ戻す。
sudoedit /etc/hosts
```

`/etc/hosts` の名前も `mhashimo42` に戻します。シェルプロンプトは古い名前のままの場合があるため、確認は `hostnamectl` で行います。

**評価票対応：**「VMのパーティションを表示」「課題図と比較」「LVMとは何か、どう動くか説明する」ため、暗号化・PV・VG・LV・マウント・swapを表示するコマンドです。

```sh
# ディスク階層とLUKS・LVM・ファイルシステムを確認する。
lsblk
lsblk -f
# LVMのPV→VG→LV構造を個別に確認する。
sudo pvs
sudo vgs
sudo lvs
# rootとhomeの実マウント先、swapの利用を確認する。
findmnt /
findmnt /home
swapon --show
```

期待結果：暗号化領域の下にLVMのroot/home/swapがあり、`/`・`/home` とswapが利用されています。課題の必須例と構造を比べ、PV→VG→LVと暗号化の役割を説明します。図の容量は例示です。

ホスト名はネットワークやログ上で機械を識別する名前です。`hostnamectl set-hostname` は永続ホスト名を変更しますが、ローカル名前解決に使う `/etc/hosts` の旧名は自動で直らないため、対応する行も変更します。再起動後の確認によって永続化を実証します。

LUKSはディスク上のデータを暗号化し、LVMは容量を論理的に管理します。LVMではPV（Physical Volume）をVG（Volume Group）へまとめ、そこからLV（Logical Volume）を切り出し、ファイルシステムを作ってマウントします。swapはファイルシステムとしてマウントしません。LVMだけでは暗号化されず、LUKSだけではLV単位の柔軟な容量管理はできません。このVMでrootとhomeを分けたのは、ユーザーデータによる容量消費をシステム領域から分離するためです。

### 6. SUDO：所属追加・設定・ログ更新

**評価票対応：**「sudoがインストール済み」「新規ユーザーをsudoグループへ追加」「厳密なルールを示す」「`/var/log/sudo/`にファイルがある」を確認するコマンドです。

```sh
# sudoパッケージが正しくインストールされているか確認する。
dpkg-query -W sudo
# 評価用ユーザーをsudoグループへ追加し、所属を確認する。
sudo usermod -aG sudo reviewer42
id reviewer42
# sudoers全体の構文が正常か確認する。
sudo visudo -c
# 課題用の厳密設定を表示して各ルールを説明する。
sudo cat /etc/sudoers.d/born2beroot
# 現在のユーザーに許可されたsudo操作を確認する。
sudo -l
# 指定ログディレクトリと、その中のイベント/I/Oログを確認する。
sudo ls -ld /var/log/sudo
sudo find /var/log/sudo -type f -print
```

期待結果：構文が正常で、`passwd_tries=3`、独自 `badpass_message`、`log_input`、`log_output`、`logfile`・`iolog_dir`、`requiretty`、`secure_path` が有効です。保存先は `/var/log/sudo/` 内です。新しいログインセッションではreviewer42もsudoを利用できます。

sudoは、sudoersで許可されたユーザーが別ユーザー（通常root）の権限で特定のコマンドを実行する仕組みです。一般作業をrootで続けず、管理操作だけを昇格させ、誰が何を実行したか記録できる点が利点です。一方、広いsudo権限を持つアカウントは実質的にroot相当なので、所属と設定を厳しく管理します。

| sudo設定 | 意味 |
| --- | --- |
| `passwd_tries=3` | 1回の認証で誤入力を3回までにする |
| `badpass_message` | 誤入力時に独自メッセージを表示する |
| `logfile` | 実行者・対象・コマンド等のイベントログを保存する |
| `log_input`, `log_output` | 端末の入出力をI/Oログとして記録する |
| `iolog_dir` | I/Oログを `/var/log/sudo/` 配下へ置く |
| `requiretty` | 端末が割り当てられた実行だけを許可する |
| `secure_path` | sudo時にコマンドを探索するPATHを信頼できる場所へ制限する |

設定編集に `visudo` を使うのは、保存前後に構文を検査してsudo全体を壊す危険を減らすためです。イベントログとI/Oログは別物で、後者は `sudoreplay` で一覧・再生します。

**評価票対応：**「sudoログの内容に実行履歴が見える」「sudoでコマンドを実行するとログが更新される」を前後比較するコマンドです。

```sh
# 実行前のイベントログ末尾を確認する。
sudo tail -n 10 /var/log/sudo/sudo.log
# sudo経由で確認用コマンドを1回実行する。
sudo /usr/bin/id
# COMMAND=/usr/bin/idが追加されたことを確認する。
sudo tail -n 10 /var/log/sudo/sudo.log
# 入出力ログのセッション一覧を確認する。
sudo sudoreplay -d /var/log/sudo -l
```

`id` の結果がrootで、ログに `COMMAND=/usr/bin/id` が追加されていることを確認します。I/Oログの実パスが下位ディレクトリなら、`sudoreplay -d` のパスを `iolog_dir` の値に合わせます。一覧にあるIDを指定して再生します。

**評価票対応：** sudoの「入力と出力も記録する」設定が実データとして再生できることを確認するコマンドです。

```sh
# IDは一覧にある値へ置き換える。
sudo sudoreplay -d /var/log/sudo SESSION_ID
```

3回制限と独自メッセージの確認では、次を実行して意図的に3回誤入力し、実行されず終了することを確認します。認証キャッシュを無効にする `sudo -k` が必要です。

**評価票対応：** sudoの「誤ったパスワードは3回まで」「独自エラーメッセージ」を動作で確認するコマンドです。

```sh
# 既存の認証キャッシュを破棄する。
sudo -k
# 意図的に3回誤入力し、独自メッセージと実行拒否を確認する。
sudo /usr/bin/true
```

### 7. UFW：4242確認・8080追加・削除

UFWは、Linuxカーネルのパケットフィルタへ許可・拒否ルールを設定するための管理ツールです。このVMでは不要な外部到達性を減らすため、受信を既定で拒否し、SSHに必要な4242/TCPだけを許可します。firewalldは同じ目的に使えますが、ゾーンやサービス単位で方針を管理する点が特徴です。ポートを許可することと、そのポートでサービスを起動することは別なので、8080の評価ではサーバーを起動する必要はありません。

**評価票対応：**「UFWがインストールされ正常動作」「有効なルールに4242」「8080を追加して一覧確認し、最後に削除」を順番に実演するコマンドです。

```sh
# UFWのインストール、起動時有効化、現在の動作を確認する。
dpkg-query -W ufw
systemctl is-enabled ufw
systemctl is-active ufw
# 既定方針と4242/TCPだけが許可されていることを確認する。
sudo ufw status verbose
sudo ufw status numbered
# 評価用に8080/TCPを追加し、一覧で増えたことを確認する。
sudo ufw allow 8080/tcp
sudo ufw status numbered
# 評価用8080ルールを削除し、4242だけへ戻ったことを確認する。
sudo ufw delete allow 8080/tcp
sudo ufw status numbered
```

開始時と終了時は4242/TCPだけが受信許可され、途中で8080/TCPのルールが増えることを確認します。IPv6有効時は対応するルールも確認します。8080に実際のサーバーを起動する必要はありません。既存ルールと重なる場合は、今回追加したものを特定して削除します。

### 8. SSH：4242のみ・新規ユーザー・root拒否

SSHは、暗号化した通信路でサーバーを認証し、さらに鍵またはパスワードでユーザーを認証して、遠隔からシェルを操作する仕組みです。平文の遠隔操作と異なり、認証情報と通信内容を保護できることが利点です。rootの直接ログインを禁止すると、まず個人を識別できる一般ユーザーで入り、必要な操作だけsudoで昇格するため、総当たり対象と無記名の特権操作を減らせます。4242へ変えることだけは強い認証の代わりになりません。

**評価票対応：**「SSHがインストールされ正常動作」「VM内で4242番ポートだけを使用」「root接続禁止」の設定と実待受を確認するコマンドです。

```sh
# OpenSSH serverのインストール、起動時有効化、現在の動作を確認する。
dpkg-query -W openssh-server
systemctl is-enabled ssh
systemctl is-active ssh
# sshd設定の構文が正常か確認する。
sudo /usr/sbin/sshd -t
# 実効設定がport 4242、permitrootlogin noか確認する。
sudo /usr/sbin/sshd -T | grep -E '^(port|permitrootlogin|passwordauthentication|pubkeyauthentication) '
# sshdが実際に4242だけで待ち受けているか確認する。
sudo ss -ltnp
```

期待結果：構文エラーなし、`port 4242`、`permitrootlogin no`。`ss` でSSHプロセスの待受が4242のみで、22等にないことを確認します。IPv4とIPv6で複数行になっていても同一ポートなら構いません。`Match` 条件がある場合は対象ユーザー・接続元に対する実効設定も確認します。

`sshd -t` は設定の構文、`sshd -T` はインクルード等を反映した実効設定、`ss` は実際の待受ソケットを確認します。どれか1つだけでは「意図した設定が構文上正しく、実際に4242で動作している」ことを十分に示せないため、組み合わせて確認します。

**学内ホストの別端末**から接続します。以下はNATでホスト4242→VM4242を転送している場合です。ブリッジ等の場合は `localhost` をVMのIPに置き換えます。

**評価票対応：**「新しく作ったユーザーでSSHログインする」をホスト側から確認するコマンドです。

```sh
ssh -p 4242 reviewer42@localhost
```

新規ユーザーのセッション内で確認します。

**評価票対応：** 接続成功が別ユーザーや既存セッションではなく、新規ユーザー自身のSSHセッションであることを確認するコマンドです。

```sh
# reviewer42として接続できたことと、追加済みグループを確認する。
whoami
id
# sudo項目で追加した権限が新しいログインセッションへ反映されたか確認する。
sudo -l
exit
```

再びホストからroot接続を試し、拒否を確認します。

**評価票対応：**「rootユーザーではSSH接続できない」を、一般ユーザー成功後に同じ接続先で確認するコマンドです。

```sh
ssh -p 4242 root@localhost
```

正しい接続先に対して一般ユーザーは成功し、rootは拒否されることが必要です。rootの接続失敗だけでなく `PermitRootLogin no` も確認してください。

VirtualBoxのNATを使う場合、ホスト側ポートとゲスト側ポートは別の設定です。この例は「ホストのlocalhost:4242 → ゲストの4242/TCP」という転送を前提とします。接続失敗をroot禁止の証拠にする前に、新規一般ユーザーが同じ接続先へ成功することを確認します。

### 9. 監視：コード・10分周期・動的な値

`monitoring.sh` は情報を取得・計算して標準出力へ書くBashスクリプトです。全端末への配信はスクリプト自身ではなく、rootのcron行にあるパイプの右側の `wall` が担当します。この分離により、スクリプト単体の出力確認と定期配信を別々に検証できます。cronは指定時刻にコマンドを実行するデーモンで、rootのユーザーcrontabを使うため、5つの時刻欄の後に実行ユーザー欄は書きません。

**評価票対応：**「コードを見せながらスクリプトの動作を説明」「cronとは何か」「起動時から10分ごとの設定」を、コード・単体実行・crontab・サービス状態から確認するコマンドです。

```sh
# 評価対象の実コードを表示し、各取得・計算処理を説明する。
sudo cat /usr/local/bin/monitoring.sh
# スクリプトの所有者・権限を記録する。
sudo stat -c '%a %U:%G %n' /usr/local/bin/monitoring.sh
# cronを待たず単体実行し、全項目がエラーなしで出るか確認する。
sudo /usr/local/bin/monitoring.sh
# @rebootと10分周期、wallへのパイプを確認する。
sudo crontab -l
# cronが起動時から有効で現在も動作中か確認する。
systemctl is-enabled cron
systemctl is-active cron
```

rootのcrontabの通常設定は次の2行です。

**評価票対応：**「サーバー起動時から10分ごとに全端末へ表示する」ための通常設定です。

```cron
# cron起動時に1回実行し、wallで全端末へ配信する。
@reboot /usr/local/bin/monitoring.sh | /usr/bin/wall
# 毎時00・10・20・30・40・50分に実行して配信する。
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

実装の読み方は次のとおりです。

- 物理CPU数は `lscpu -p=SOCKET` のコメントを除き、ゲストから見えるsocket IDを重複排除して数えます。vCPU数は `/proc/cpuinfo` の `processor` 行数です。
- RAMは `free` のused/total、ディスクはtmpfs等を除いた `df --total` のused/totalと使用率を表示します。PDF本文の「available」と表示例のused/totalには表現差があるため、値を説明するときは何を分子・分母にしたかを明示します。
- CPU使用率は `/proc/stat` を1秒間隔で2回読み、全CPU時間の増分からidleとiowaitの増分を引いて割合を求めます。累積値そのものや固定値は表示しません。
- LVMは `lsblk` にtype `lvm` があるか、TCPは状態が `ESTAB` の接続、ユーザー数は `who` のユーザー名を重複排除した人数です。
- ネットワークはデフォルトルートのインターフェースを選び、そのIPv4とsysfs上のMACを取得します。経路がなければ `N/A` となるので、`N/A`を正常値と決め付けません。
- sudo回数は `/var/log/sudo/sudo.log` の `COMMAND=` 行数です。ログローテーション済みの全世代を合算する値ではなく、このログに残る記録数です。

コンソールとSSH端末を開いたまま、配信先とエラーの有無を確認します。

**評価票対応：**「起動時および10分ごとに、すべての端末へエラーなしで表示される」を、ログイン端末・書込許可・手動wall・cron履歴から確認するコマンドです。

```sh
# 現在ログイン中で配信対象となる端末を確認する。
who
# 現端末がwallメッセージを受信可能か確認する。
mesg
# cronと同じパイプを手動実行し、全端末への実表示を確認する。
sudo /usr/local/bin/monitoring.sh | sudo /usr/bin/wall
# 直近のcron実行履歴にエラーがないか確認する。
sudo journalctl -u cron --since '15 minutes ago' --no-pager
```

このVMでは複数のSSH端末への手動配信と、cronの起動時および00・10・20分の実行履歴を確認しました。実行ログだけで全端末への表示は証明できないため、評価中もコンソールとSSH端末を開いた状態で実表示を確認します。

### 10. 監視：毎分へ変更 → 停止 → 再起動して無変更確認

まずrootのcrontabと、スクリプトのハッシュ・所有者・権限を保存します。保存先が既にある場合は別名にし、同じ実演中はその名前を使ってください。

**評価票対応：** 後で「スクリプトそのものを変更せず停止した」と証明できるよう、毎分化の前にcrontab、内容、所有者、権限の基準値を保存するコマンドです。

```sh
# 通常のroot crontabを復元用に保存する。
sudo sh -c 'crontab -l > /root/b2br-review-crontab.before'
# スクリプト内容のSHA-256を保存する。
sudo sh -c 'sha256sum /usr/local/bin/monitoring.sh > /root/b2br-monitoring.sha256'
# 所有者・グループ・権限・パスを保存する。
sudo sh -c 'stat -c "%a %U:%G %n" /usr/local/bin/monitoring.sh > /root/b2br-monitoring.stat'
# rootのcrontabだけを編集する。
sudo crontab -e
```

`*/10` の行を次に置き換えます。元の10分行を重複して残さないでください。

**評価票対応：**「正しく動作したら毎分実行へ変更する」で使用するcron行です。

```cron
# 1分ごとに実行し、wallで全端末へ配信する。
* * * * * /usr/local/bin/monitoring.sh | /usr/bin/wall
```

**評価票対応：** 10分行が消え、毎分行が1つだけになったことを確認するコマンドです。

```sh
sudo crontab -l
```

分の境界を2回以上またいで通知時刻と値の変化を確認します。次に `sudo crontab -e` で、起動時と毎分の**両方**をコメントアウトします。他の場所にも監視の登録があれば確認してください。

**評価票対応：**「スクリプトそのものを変更せず、サーバー起動後に実行されないようにする」ため、スケジュールだけを無効化する設定です。

```cron
# 起動時実行を無効化する。
# @reboot /usr/local/bin/monitoring.sh | /usr/bin/wall
# 毎分実行も無効化する。
# * * * * * /usr/local/bin/monitoring.sh | /usr/bin/wall
```

**評価票対応：** 無効化されたcrontabを表示したうえで、「確認のためもう一度サーバーを再起動する」を実行します。

```sh
# 両方がコメント化されていることを確認する。
sudo crontab -l
# 停止状態が起動後も続くか確認するため再起動する。
sudo reboot
```

LUKS解除・ログイン後、同じパスにファイルがあり、ハッシュ・権限・所有者が変わっていないことを確認します。

**評価票対応：** 再起動後に「スクリプトが同じ場所に存在し、権限と内容が変わらず、実行されない」を確認するコマンドです。

```sh
# 内容が保存前のSHA-256と一致するか確認する。
sudo sha256sum -c /root/b2br-monitoring.sha256
# 再起動後の所有者・権限を取得し、保存前と比較する。
sudo sh -c 'stat -c "%a %U:%G %n" /usr/local/bin/monitoring.sh > /root/b2br-monitoring.after.stat'
sudo diff -u /root/b2br-monitoring.stat /root/b2br-monitoring.after.stat
# スケジュールが無効のままか確認する。
sudo crontab -l
# 今回の起動後に監視ジョブの実行記録がないか確認する。
sudo journalctl -u cron -b --no-pager
```

期待結果：ハッシュは `OK`、`diff` は差分なし。起動後と分の境界を越えても監視通知が来ず、cronの実行記録も増えません。スクリプトの内容や実行権限を変更して止める操作は行いません。

毎分への変更は、cron式とwall配信が実際に機能し、表示値が動的に更新されることを短時間で確認するためです。停止はジョブのスケジュールだけを無効化して行います。`@reboot` も止めなければ再起動直後に1回表示されるため、定期行だけのコメントアウトでは不十分です。保存したSHA-256と`stat`の比較により、停止のためにスクリプト本体、所有者、権限を変更していないことを示します。

### 11. ボーナスと終了後

必須が完全に合格した場合のみ、追加パーティション2点、lighttpd・MariaDB・PHPによるWordPress2点、自由選択サービス1点を評価します。NGINXとApache2は禁止です。この構成にはボーナス構築の確認記録はありません。

したがって、ボーナス相当の構成や得点は主張しません。実VMのroot/home/swap構成は必須要件として説明し、ボーナス例にある `/var`、`/srv`、`/tmp`、`/var/log` の個別LVを作成済みとは説明しません。

停止確認を終えてから、評価用の変更を戻します。原本を保護したコピーを破棄する場合は、コピー内の変更を原本に反映する必要はありません。作業VMを再利用する場合の復元例です。

**評価票対応：** 評価中に求められた一時変更を通常設定へ戻し、4242以外の不要なUFWルールが残っていないことを確認する終了処理です。

```sh
# 監視を通常の@reboot・10分周期へ戻す。
sudo crontab /root/b2br-review-crontab.before
sudo crontab -l
# hostnameが元のmhashimo42か確認する。
hostnamectl --static
# 8080等の評価用ルールが消え、4242だけか確認する。
sudo ufw status numbered
```

評価用ユーザーのSSHセッションを終了後、**この評価で作成したユーザーとグループであることを確認して**削除します。

**評価票対応：** 評価票で作成した一時ユーザー・グループを作業VMから除去し、スナップショット復元またはクローン削除を安全に行える電源オフ状態へ移る終了処理です。

```sh
# この評価で作成したreviewer42とホームだけを削除する。
sudo deluser --remove-home reviewer42
# この評価で作成したevaluatingだけを削除する。
sudo groupdel evaluating
# ファイルシステムを正常終了させてVMを完全停止する。
sudo poweroff
```

#### 評価用VMを停止する

`sudo poweroff` 後、VirtualBox Managerで評価に使ったVMの状態が「電源オフ」になるまで待ちます。「閉じる」から「仮想マシンの状態を保存」を選んではいけません。ホスト側でも停止を確認します。

**評価票対応：** 評価用スナップショットを復元・削除、または評価用クローンを削除する前提として、評価用VMが完全停止したことを確認するコマンドです。

```sh
# ホスト側。Aなら元のVM名を使う。
ACTIVE_VM_NAME='Born2BeRoot-amd64'
# Bなら上の代わりに次を使う：ACTIVE_VM_NAME='Born2BeRoot-amd64-evaluation'
# 評価用VMが実行一覧にないことを確認する。
VBoxManage list runningvms
# 保存状態ではなくpoweroffか確認する。
VBoxManage showvminfo "$ACTIVE_VM_NAME" --machinereadable | grep '^VMState='
```

Aでは元のVM、Bでは `EVAL_VM_NAME` が `list runningvms` に現れず、`VMState="poweroff"` であることを確認します。

#### Aを選んだ場合：復元して評価専用スナップショットを削除する

VirtualBox Managerの「スナップショット」で `b2br-evaluation` を選び、「復元（Restore）」を押します。現在の評価後状態を保存するか尋ねられた場合は、新しいスナップショットを作成せずに復元します。復元完了後、同じ `b2br-evaluation` を選んで「削除（Delete）」を押し、処理が終わるまでVirtualBoxを終了しません。最後に、名前付きスナップショットがなく `Current State` だけになったことを確認します。

CLIで行う場合は次の順です。

**評価票対応：**「評価開始時に作ったコールドスナップショットを評価終了時に削除する」を、評価中の変更を原本へ残さない順序で実行するコマンドです。

```sh
# ホスト側。VMがpoweroffであることを先に確認する。
VM_NAME='Born2BeRoot-amd64'
EVAL_SNAPSHOT='b2br-evaluation'
# 先に起動前の状態へ戻し、評価中の差分を破棄する。
VBoxManage snapshot "$VM_NAME" restore "$EVAL_SNAPSHOT"
# 復元後に評価専用スナップショットを削除する。
VBoxManage snapshot "$VM_NAME" delete "$EVAL_SNAPSHOT"
# 名前付きスナップショットがなくなったことを確認する。
VBoxManage snapshot "$VM_NAME" list
```

`restore` で評価中の変更を破棄して署名照合時の状態へ戻してから、`delete` で評価専用スナップショットを除去します。削除処理では差分ディスクの整理に時間がかかる場合があるため、中断しません。

#### Bを選んだ場合：評価用クローンだけを削除する

VirtualBox Managerで、元のVMではなく `Born2BeRoot-amd64-evaluation` を選び、「削除（Remove）」→「すべてのファイルを削除（Delete all files）」を選びます。元の `Born2BeRoot-amd64` や原本VDIを削除対象にしていないことを、確定前に名前とストレージパスで再確認します。

CLIで削除する場合も、まず表示内容で対象が評価用ディレクトリのクローンであることを確認してから、そのVM名だけを削除します。

**評価票対応：**「別ディレクトリへ複製したコピーから起動」を選んだ場合に、原本ではなく評価用コピーだけを確認・削除するコマンドです。

```sh
# ホスト側。表示された名前とディスクパスを確認してから削除する。
EVAL_VM_NAME='Born2BeRoot-amd64-evaluation'
# 削除対象が評価用名・評価用パスであることを最終確認する。
VBoxManage showvminfo "$EVAL_VM_NAME"
# 登録と評価用クローンの関連ファイルだけを削除する。
VBoxManage unregistervm "$EVAL_VM_NAME" --delete
# 原本VMが登録されたまま、評価用名が消えたことを確認する。
VBoxManage list vms
```

#### 原本の最終確認

どちらの方法でも、元のVMが電源オフで、名前付きスナップショットがないことを再確認します。そのうえで、起動前と同じ原本VDIからSHA-1を再計算します。

**評価票対応：** 次回評価に向けて「原本 `.vdi` を変更せず署名を同一に保つ」「スナップショットなし」「VMは電源オフ」へ戻ったことを最終確認するコマンドです。

```sh
# ホスト側。
VM_NAME='Born2BeRoot-amd64'
VM_DISK='/sgoinfre/mhashimo/Born2BeRoot-x86/Born2BeRoot-amd64/Born2BeRoot-amd64.vdi'
# 原本VMが実行中でないこととpoweroffを確認する。
VBoxManage list runningvms
VBoxManage showvminfo "$VM_NAME" --machinereadable | grep '^VMState='
# 評価専用を含む名前付きスナップショットがないことを確認する。
VBoxManage snapshot "$VM_NAME" list
# 原本VDIのSHA-1を再計算して提出署名と比較する。
POST_SIGNATURE=$(mktemp)
shasum -a 1 "$VM_DISK" | awk '{print $1}' > "$POST_SIGNATURE"
diff -u signature.txt "$POST_SIGNATURE"
DIFF_STATUS=$?
# 一時ファイルを削除し、diffの終了値を最終結果にする。
rm "$POST_SIGNATURE"
test "$DIFF_STATUS" -eq 0
```

期待結果は、元のVMが `VMState="poweroff"`、名前付きスナップショットなし、`diff` の出力なし・終了値0です。不一致なら `signature.txt` を書き換えず、評価用スナップショットの復元・削除順序、または起動したディスクが原本ではなかったかを確認します。

### 12. 評価票との対応表

この表は見落とし確認用です。実演時は表だけを読み上げず、該当節のコマンド、期待結果、理由を使って説明します。

| 評価項目 | このREADMEでの回答・実演箇所 |
| --- | --- |
| 正式リポジトリ、alias、補助スクリプト、不正・欠落時の終了 | 0節のclone前確認と終了条件 |
| `signature.txt`、停止中VDIとの比較、スナップショットなし、原本保護 | 0節のSHA-1、`diff`、コピー/コールドスナップショット手順 |
| README必須形式・説明・4比較・AI利用 | 冒頭、Description、Project description、Resources |
| VMの仕組み・用途、Debian選択、Debian/Rocky、apt/aptitude、AppArmor | 「評価時に説明するプロジェクト概要」と1節 |
| GUIなし、暗号化解除、一般ユーザーログイン、OS、UFW/SSH/AppArmor/cron | 2節のサービス・パッケージ確認と説明 |
| `mhashimo`、`sudo`/`user42`、新規ユーザー、パスワードポリシー | 3節の作成・設定値・動作確認と期限/品質の説明 |
| `evaluating`作成・所属、ポリシーの長所短所 | 4節のコマンドと理由 |
| `login42`形式、評価者名への変更、再起動、復元、LVM | 5節の変更・永続化・ストレージ確認とLUKS/LVM説明 |
| sudo導入、新規ユーザー追加、厳格設定、ログ生成・更新 | 6節の設定表、認証失敗、イベント/I/Oログ確認 |
| UFWの役割、4242、8080の追加・確認・削除 | 7節 |
| SSHの役割、4242のみ、新規ユーザー接続、root拒否 | 8節の設定・待受・接続試験 |
| 監視コード、全表示項目、cron、起動時・10分ごと | 9節の取得元・実装説明・wall配信確認 |
| 毎分化、動的な値、スクリプト無変更で停止、再起動確認 | 10節のcrontab変更、ハッシュ・所有者・権限比較 |
| ボーナスの前提とこのVMの非該当 | 11節 |
| 評価中の一時変更の復元、ユーザー削除、原本保護 | 11節後半 |

## Resources

- 課題本文：Born2beRoot Version 5.2。要件と評価票を併せて確認します。
- [Debian公式ドキュメント](https://www.debian.org/doc/)：OSと管理の基本。
- [apt(8)](https://manpages.debian.org/trixie/apt/apt.8.en.html)：aptの用途。
- [pam_pwquality(8)](https://manpages.debian.org/trixie/libpam-pwquality/pam_pwquality.8.en.html)：品質設定、rootへの適用、旧新比較。
- [sudoers(5)](https://manpages.debian.org/trixie/sudo/sudoers.5.en.html)：sudoの権限とログ設定。
- [crontab(5)](https://manpages.debian.org/trixie/cron/crontab.5.en.html)：時刻指定と起動時実行。
- [Oracle VM VirtualBox 7.0 User Guide](https://docs.oracle.com/en/virtualization/virtualbox/7.0/user/)：VM状態、スナップショット、クローン、`VBoxManage` の公式手順。
- VM内の `man sshd_config`、`man ufw`、`man lvm`、`man cryptsetup`、`man wall`：インストール済み版の設定・操作。

### AI usage

AIは、課題・評価票の整理と日本語訳、レビュー説明資料と本READMEの文章・確認コマンドの整理、監視シェルスクリプトのレビュー補助に使用しました。VMの構築・設定適用・実行結果の確認と、評価時の説明は自分で行います。AIによる資料更新を実機での合格確認の代わりにはしていません。
