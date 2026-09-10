# Module-playerbots

**Module-playerbots** is an autonomous, evidence-driven upstream porting, stabilization, and verification framework for Turtle WoW 1.18.1 / vMaNGOS PlayerBots.

The project systematically audits, adapts, verifies, and integrates fixes and improvements from two active upstream repositories into a custom Turtle WoW server.

---

## 1. Repository Topology

| Repository Role | Local Directory | Upstream Git Remote | Branch | Primary Function |
| :--- | :--- | :--- | :--- | :--- |
| **TARGET** | `tortoise-wow-extended` | `https://github.com/Ildourol/tortoise-wow-extended.git` | `mantech-turtle` | Product repository. PlayerBots module (`modules/mod-playerbots`) and Dungeon Clear (`modules/mod-dungeon-clear`). |
| **UPSTREAM 1** | `playerbots` | `https://github.com/cmangos/playerbots.git` | `master` | Donor repository for CMaNGOS PlayerBots. High-velocity AI, travel, and combat fixes. |
| **UPSTREAM 2** | `core` | `https://github.com/ileboii/core.git` | `vmangos-ike3-playerbots` | Donor repository for vMaNGOS PlayerBots. Core-integrated lifecycle, healing, and stance fixes. |

---

## 2. How to Install & Setup

This repository contains the orchestration, automation, documentation, and state tracking framework. The underlying server and donor repositories are tracked separately and must be cloned into the project root:

### Step 1: Clone the Management Framework
```powershell
git clone -b module-playerbots https://github.com/Ildourol/twow-project.git Module-playerbots
cd Module-playerbots
```

### Step 2: Clone the Component Repositories
Run the following commands inside the `Module-playerbots` directory:

```powershell
# 1. Target Product Repository (Turtle WoW Extended)
git clone -b mantech-turtle https://github.com/Ildourol/tortoise-wow-extended.git tortoise-wow-extended

# 2. Upstream CMaNGOS PlayerBots Donor Repository
git clone https://github.com/cmangos/playerbots.git playerbots

# 3. Upstream vMaNGOS PlayerBots Donor Repository
git clone -b vmangos-ike3-playerbots https://github.com/ileboii/core.git core
```

### Step 3: Prerequisites & Toolchain Setup
- **Visual Studio 2022**: Desktop development with C++ workload (v143 toolset).
- **CMake**: Version 3.20+ (recommended: 4.x).
- **vcpkg Dependencies**:
  ```powershell
  vcpkg install ace:x64-windows boost-thread:x64-windows boost-filesystem:x64-windows boost-system:x64-windows openssl:x64-windows
  ```

### Step 4: Configure the Build Baseline
Configure CMake for the target repository with PlayerBots and Dungeon Clear enabled:
```powershell
cmake -S tortoise-wow-extended -B tortoise-wow-extended/build `
  -G "Visual Studio 17 2022" -A x64 `
  -DCMAKE_BUILD_TYPE=Release `
  -DBUILD_PLAYERBOTS=ON `
  -DMODULE_MOD_DUNGEON_CLEAR=static `
  -DALLOW_TURTLE_ADDONS=ON `
  -DBUILD_ELUNA=OFF `
  -DACE_ROOT="C:/vcpkg/installed/x64-windows" `
  -DBOOST_ROOT="C:/vcpkg/installed/x64-windows" `
  -DOPENSSL_LIBRARIES="C:/vcpkg/installed/x64-windows/lib/libssl.lib;C:/vcpkg/installed/x64-windows/lib/libcrypto.lib" `
  -DOPENSSL_INCLUDE_DIR="C:/vcpkg/installed/x64-windows/include"
```

### Step 5: Verify Environment
```powershell
.\task.ps1 status
```

---

## 3. Protected Systems & Core Invariants

1. **Core-Preservation Invariant**: Target native mechanics always take priority over foreign upstream architecture.
2. **Dungeon Clear Compatibility**: `modules/mod-dungeon-clear` is protected. Bot changes must preserve encounter routing, party hierarchy, and wipe recovery.
3. **Turtle Expansion Assurances**: Preserves 11 playable races (`MAX_RACES = 11`), custom entities ($\ge 40000$ spells, $\ge 300000$ creatures), and 64-bit debuff streaming.
4. **Multi-Tier Verification**: Every port must compile `modules.lib` and successfully link `mangosd.exe` using Visual Studio 2022 x64 before marking as completed.
5. **Durable Ledger**: Every evaluated commit is tracked permanently in `state/porting-ledger.json` to eliminate duplicate investigation.
6. **Commit-by-Commit Pipeline**: Batch auditing is permitted, but all code adaptation, build verification, git committing, and remote pushing must be executed strictly **commit-by-commit** (1 upstream commit = 1 target commit = 1 remote push). Batch commits are prohibited.
7. **Strict Vanilla / Classic Exclusivity**: This project is strictly Vanilla (Classic 1.12.1 / Turtle WoW 1.18.1 Classic+). Porting anything from TBC or WotLK is **STRICTLY PROHIBITED**. Only changes to Vanilla and Classic-related mechanics are permitted. Zero post-Vanilla expansion pollution.

---

## 4. Project Directory Structure

```
Module-playerbots/
├── AGENTS.md                  # Project-level autonomous orchestration protocol
├── README.md                  # Project overview and topology
├── COMMANDS.md                # Task dispatcher command reference
├── ROADMAP.md                 # Evidence-based porting milestones
├── task.ps1                   # Root CLI task dispatcher entrypoint
├── docs/                      # Architectural policies, baselines, and guides
│   ├── PROJECT_CHARTER.md
│   ├── SOURCE_MAP.md
│   ├── TARGET_BASELINE.md
│   ├── PLAYERBOTS_ARCHITECTURE.md
│   ├── PORTING_POLICY.md
│   ├── COMMIT_SELECTION_POLICY.md
│   ├── BUILD_AND_TEST.md
│   ├── DUNGEON_CLEAR_COMPATIBILITY.md
│   ├── KNOWN_RISKS.md
│   └── DECISIONS.md
├── state/                     # Machine-readable durable state
│   ├── sources.json
│   ├── source-watermarks.json
│   └── porting-ledger.json
├── reports/                   # Audit records and verification reports
│   ├── commit-audits/
│   └── verification/
└── tools/                     # PowerShell automation modules
    └── task.ps1
```

---

## 5. Command Quick Reference

```powershell
# Show current project status, repository heads, and backlog metrics
.\task.ps1 status

# Scan upstream commits (audit without modifying target source)
.\task.ps1 scan [cmangos|vmangos|all] [fast|normal|deep]

# Audit a specific upstream commit
.\task.ps1 audit <source> <commit-sha>

# Port a specific upstream commit
.\task.ps1 port <source> <commit-sha>

# Verify target compilation and link
.\task.ps1 verify-quick
.\task.ps1 verify-full

# Inspect porting ledger
.\task.ps1 ledger [cmangos|vmangos]
```
