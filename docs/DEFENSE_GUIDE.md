> 実VMはDebian 13 ARM64、hostname mhashimo42、LUKS2内のroot/home/swapです。VM内のmonitoring.shはstdoutへ表示し、root crontabがwallへパイプします。旧設計と混同しないこと。

# Defense guide

Born2beRootのレビュイーが、設定の事実と理由を自分の言葉で説明するための学習メモ。

## 1. Security layers

~~~text
保存データ -> LUKS
容量管理 -> LVM
リモート入口 -> SSH 4242 / root login禁止
ネットワーク入口 -> UFW
権限昇格 -> sudo
認証品質 -> PAM / pwquality / chage
プロセス制御 -> AppArmor
定期観測 -> cron / monitoring.sh / wall
~~~

単一の設定で安全にするのではなく、保存、ネットワーク、権限、認証、実行制御を層として組み合わせる。

## 2. LUKS and LVM

LUKSはブロックデバイスを暗号化する標準形式。LVMはPVをVGという容量プールにまとめ、LVを切り出す。

~~~text
disk -> partition -> LUKS -> PV -> VG -> LV -> filesystem
~~~

LUKSだけでは容量管理にならず、LVMだけでは暗号化にならない。評価ではlsblk -fを見せ、crypto_LUKS、device-mapper、LV、filesystem、mount pointを順番に説明する。

## 3. SSH and UFW

SSHは暗号化されたリモート管理プロトコル。4242は課題要件であり、ポート変更だけで安全になるわけではない。一般ユーザーでSSH接続し、必要なコマンドだけsudoで昇格することでrootの直接ログインを避ける。

UFWはiptables/nftablesを扱うフロントエンド。incoming deny、outgoing allow、4242/tcp allowの順に設定する。4242を許可する前にenableすると自分を締め出す。

## 4. Password policy

Agingとqualityは別物。

- login.defs: 新規ユーザーのデフォルト
- chage: 既存アカウントの有効期限
- pam_pwquality: パスワード変更時の品質判定
- pwquality.conf: 品質ルールの値

~~~text
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
~~~

creditが負数なのは、その文字種を少なくとも要求するため。maxrepeat=3は同一文字4連続を拒否する。difok=7はrootには適用しない課題上の扱いを、非rootの変更で確認する。

## 5. sudo

sudoは必要なコマンドだけ一時的にroot権限で実行する仕組み。

| 設定 | 意味 |
| --- | --- |
| passwd_tries=3 | 認証試行を3回に制限 |
| badpass_message | 失敗時の独自メッセージ |
| log_input / log_output | 入出力を記録 |
| iolog_dir | I/Oログ保存先 |
| requiretty | TTYなしの実行を拒否 |
| secure_path | sudo時のPATHを固定 |

sudoersのsyntax errorはsudo全体を壊し得るため、/etc/sudoersを直接編集せずvisudo -fを使う。

## 6. AppArmor and SELinux

どちらもLSMを利用するMAC。

- AppArmor: プログラムのパスを中心にprofileを書く。比較的導入しやすい。
- SELinux: ファイルやプロセスにlabelを付け、label間のpolicyで許可・拒否する。

DebianならAppArmorを起動時から有効にする。RockyならSELinuxをenforcingで維持する。AppArmorはファイアウォールではない。UFWはネットワーク、AppArmorはプロセスの操作を制御する。

## 7. apt and aptitude

aptは日常操作・スクリプトで標準的。aptitudeは依存関係の候補を対話的に検討しやすい。どちらもパッケージ管理のフロントエンドであり、OSのファイルやサービスを変更する操作だと理解する。

## 8. cron and wall

~~~cron
@reboot /usr/local/bin/monitoring.sh | /usr/bin/wall
*/10 * * * * /usr/local/bin/monitoring.sh | /usr/bin/wall
~~~

分フィールドが0,10,20,30,40,50のときrootとして実行する。@rebootは起動時に1回。wallはログイン中の端末へメッセージをブロードキャストする。

## 9. monitoring.sh

12項目と取得元を対応づけて説明する。

| 項目 | 取得元 |
| --- | --- |
| architecture | uname -a |
| physical CPU | lscpu -p=SOCKET |
| vCPU | /proc/cpuinfo の processor 行数 |
| RAM | free |
| storage | df |
| CPU usage | /proc/statの差分 |
| last boot | uptime -s |
| LVM | lsblk |
| TCP | ss |
| users | who |
| network | ip / sysfs |
| sudo | /var/log/sudo/sudo.log の COMMAND= 件数 |

値が空なら、まず取得元コマンドを単体実行する。ネットワークインターフェース名、journalの有無、ログ形式などVM差を説明できるようにする。

## 10. Short answers

### GUIを入れてはいけない理由

この課題はサーバー管理を評価するため、GUIなしが要件。削除より最初から選ばない方が確実。

### root SSHを禁止する理由

rootは全権限を持つため、一般ユーザー経由のsudoより攻撃時の被害が大きい。

### signatureは何か

Gitのcommit hashではなく、電源停止中の仮想ディスクファイルに対するSHA-1。VMを起動・変更するとディスクが変わり得るため再取得する。

### レビューで設定変更を求められたら

変更対象、構文検証、サービス再起動、外部からの確認の順に行う。元のセッションとコンソールを残す。

## 11. Final self-test

資料を見ずに次を説明する。

- LUKS / PV / VG / LV / filesystemの関係
- sshd -tとsshd -Tの違い
- UFWを有効にする安全な順序
- login.defsとchageの違い
- PAMとpwquality.confの関係
- visudoを使う理由
- cronの5フィールドと@reboot
- wallが表示する端末
- AppArmorとSELinuxの違い
- signatureをVM停止後に取る理由
