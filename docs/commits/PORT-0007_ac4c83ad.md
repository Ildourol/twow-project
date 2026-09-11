# Commit Dossier: PORT-0007 (e9e0dfc9)

## 1. Commit Overview

| Property | Value |
|:---|:---|
| **ID** | `PORT-0007` |
| **Target Commit SHA** | [`e9e0dfc9`](https://github.com/Ildourol/tortoise-wow-extended/commit/e9e0dfc98948025c2da004b160e6c44d52a9830c) |
| **Full SHA** | `e9e0dfc98948025c2da004b160e6c44d52a9830c` |
| **Subject** | `playerbots: healer bots prioritize healing tanks over other roles (P1)` |
| **Subsystem** | Healing / Strategy |
| **Author** | ile |
| **Date** | 2026-09-10 |
| **Upstream Donor** | [`vmangos/core@ac4c83ad`](https://github.com/ileboii/core/commit/ac4c83adf3ef73d0ae04233b0d150aaf29120180) |
| **Verification Status** | Verified (MSVC 2022 x64 Release: modules.lib + mangosd.exe clean link) |
| **Target Integration Branch** | `playerbots` |
| **Priority** | `P1` |

---

## 2. Rationale & Defect Description

Healer bots now prioritize group tanks whose health is within a 10% priority window of the lowest health member. In addition, healer bots will not cast self-healing if a group tank is within that same priority threshold, ensuring tank survival in dungeon and raid combat.

---

## 3. Protected Subsystems & Safety Verification

- **Strict Vanilla/Classic Compliance**: Fully compliant with Classic 1.12.1 / Turtle WoW 1.18.1. Zero TBC/WotLK code.
- **Dungeon Clear Compatibility**: Preserved.
- **Link Verification**: Compiled cleanly with exit code 0.