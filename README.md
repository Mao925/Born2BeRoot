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
├── docs/
│   ├── DEFENSE_GUIDE.md
│   └── REVIEW_CHECKLIST.md
├── scripts/
│   ├── monitoring.sh
│   └── verify_vm.sh
└── .gitignore
~~~

The assignment requires README.md and signature.txt **at the root of the submitted repository**. Copy only the two files inside submit/ to a separate 42 hand-in repository when ready.

**Signature update:** submit/signature.txt was updated using the user's 2026-09-24 SHA-1 output from the fully powered-off VM disk. Do not boot or modify the VM without obtaining a fresh SHA-1. The SSH-terminal wall broadcast remains unverified; VirtualBox-console cron delivery was confirmed. The scripts/monitoring.sh file is transcribed from pasted terminal output, not exported byte-for-byte from the VM. Compare it with the VM original before relying on it as an exact backup.

Actual VM evidence and remaining checks: see DESIGN.md and docs/REVIEW_CHECKLIST.md. Do not commit .vdi/.qcow2, passwords or LUKS passphrases.
