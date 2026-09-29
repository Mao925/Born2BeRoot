# Born2BeRoot — workspace

This GitHub repository is for learning, VM documentation and **staging** the submission. It is not itself the final 42 hand-in.

~~~text
Born2BeRoot/
├── submit/
│   ├── README.md
│   └── signature.txt   # SHA-1 from powered-off VM, 2026-09-24
├── README.md
├── DESIGN.md
├── Born2beRoot.pdf
├── quiz.md
├── answer.md
├── docs/
│   ├── REVIEW_CHECKLIST_JA.md
│   └── REVIEW_GUIDE.md
├── scripts/
│   ├── monitoring.sh
│   └── verify_vm.sh
└── .gitignore
~~~

The assignment requires README.md and signature.txt **at the root of the submitted repository**. Copy only the two files inside submit/ to a separate 42 hand-in repository when ready.

**Signature update:** submit/signature.txt was updated using the user's 2026-09-24 SHA-1 output from the fully powered-off VM disk. Do not boot or modify the VM without obtaining a fresh SHA-1. The SSH-terminal wall broadcast remains unverified; VirtualBox-console cron delivery was confirmed. The scripts/monitoring.sh file is transcribed from pasted terminal output, not exported byte-for-byte from the VM. Compare it with the VM original before relying on it as an exact backup.

## Review documents

- [評価票の日本語訳](docs/REVIEW_CHECKLIST_JA.md)：提示された評価票の全項目と終了条件。
- [説明用ガイド](docs/REVIEW_GUIDE.md)：評価順に、仕組み・採用理由・設定の意味を整理。
- [提出用README](submit/README.md)：課題指定の説明・比較と、評価時の確認・変更・復元コマンド。提出先ではルートに配置。
- [構築記録](DESIGN.md)：実VMで確認した構成と残っている確認事項。

Do not commit .vdi/.qcow2, passwords or LUKS passphrases.
