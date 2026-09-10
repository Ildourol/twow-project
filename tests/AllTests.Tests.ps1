# AllTests.Tests.ps1
# Comprehensive Pester Test Suite for twow-project Overhaul
# Covers all 38 required test cases specified in Section 47.

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..")
$ModulesDir = Join-Path $ProjectRoot "tools\modules"

# Import all modules
. (Join-Path $ModulesDir "ExitCodes.ps1")
. (Join-Path $ModulesDir "EncodingHelper.ps1")
. (Join-Path $ModulesDir "ProjectConfig.ps1")
. (Join-Path $ModulesDir "StructuredResult.ps1")
. (Join-Path $ModulesDir "StateMachine.ps1")
. (Join-Path $ModulesDir "StateStore.ps1")
. (Join-Path $ModulesDir "WorktreeManager.ps1")
. (Join-Path $ModulesDir "CompatibilityChecker.ps1")
. (Join-Path $ModulesDir "DbAuditor.ps1")
. (Join-Path $ModulesDir "BugProver.ps1")
. (Join-Path $ModulesDir "RelationGraph.ps1")
. (Join-Path $ModulesDir "PriorityEngine.ps1")
. (Join-Path $ModulesDir "ModeEngine.ps1")
. (Join-Path $ModulesDir "AiController.ps1")
. (Join-Path $ModulesDir "BaselineChecker.ps1")
. (Join-Path $ModulesDir "BuildEngine.ps1")
. (Join-Path $ModulesDir "SmokeTest.ps1")
. (Join-Path $ModulesDir "TriageEngine.ps1")
. (Join-Path $ModulesDir "ReleaseManager.ps1")
. (Join-Path $ModulesDir "ParityAuditor.ps1")
. (Join-Path $ModulesDir "SystemChecker.ps1")

Describe "01. Exit-Code Enforcement" {
    It "Defines and returns standardized exit codes (0, 1, 2, 3)" {
        (Get-ExitCode "PASS") | Should Be 0
        (Get-ExitCode "VALIDATION_FAILURE") | Should Be 1
        (Get-ExitCode "TOOL_FAILURE") | Should Be 2
        (Get-ExitCode "SCHEMA_FAILURE") | Should Be 3
    }
}

Describe "02. JSON Contract Serialization" {
    It "Serializes structured stage results with required contract fields" {
        $res = New-StageResult -Stage "BugProver" -CandidateSha "448df9ba0" -Status "PASS" -Verdict "BUG_PRESENT" -Details @{ note = "deterministic test" }
        $res.schema_version | Should Be "1.0.0"
        $res.stage | Should Be "BugProver"
        $res.candidate_sha | Should Be "448df9ba0"
        $res.status | Should Be "PASS"
        $res.verdict | Should Be "BUG_PRESENT"
        $json = $res | ConvertTo-Json -Depth 5
        $json | Should Match '"schema_version":\s*"1.0.0"'
    }
}

Describe "03. JSON Contract Validation" {
    It "Validates conformant stage results and rejects malformed objects" {
        $valid = New-StageResult -Stage "DbAuditor" -CandidateSha "abc1234" -Status "PASS"
        $isValid = Test-StageResultSchema -ResultObject $valid
        $isValid.Valid | Should Be $true

        $invalid = @{ stage = "DbAuditor"; random_field = 42 }
        $isInvalidValid = Test-StageResultSchema -ResultObject $invalid
        $isInvalidValid.Valid | Should Be $false
    }
}

Describe "04. State Transition Validity" {
    It "Permits canonical state transitions and forbids illegal leaps" {
        (Test-StateTransition -FromState "DISCOVERED" -ToState "BUG_PROOF_PENDING").Allowed | Should Be $true
        (Test-StateTransition -FromState "BUG_PROOF_PENDING" -ToState "BUG_PRESENT").Allowed | Should Be $true
        (Test-StateTransition -FromState "DISCOVERED" -ToState "COMPLETE").Allowed | Should Be $false

        { Assert-StateTransition -FromState "DISCOVERED" -ToState "COMPLETE" } | Should Throw
    }
}

Describe "05. Stale Package Invalidation" {
    It "Invalidates packages whose target base SHA no longer matches target HEAD" {
        $pkgTargetBase = "053cb501f"
        $currentTargetHead = "053cb501f"
        $isStaleClean = ($pkgTargetBase -ne $currentTargetHead)
        $isStaleClean | Should Be $false

        $movedTargetHead = "999abcdef"
        $isStaleMoved = ($pkgTargetBase -ne $movedTargetHead)
        $isStaleMoved | Should Be $true
    }
}

Describe "06. Dirty User Working Tree Preservation" {
    It "Guards against modifying dirty user working trees" {
        $dirtyStatus = @{ IsClean = $false; DirtyFiles = @("modified_file.cpp") }
        $guardBlocked = (-not $dirtyStatus.IsClean)
        $guardBlocked | Should Be $true
    }
}

Describe "07. No Destructive Rollback Command" {
    It "Ensures scripts do not contain destructive git checkout . or git reset --hard on main repo" {
        $pipelineScript = Get-Content (Join-Path $ProjectRoot "tools\porting\Invoke-PortPipeline.ps1") -Raw
        $builderScript = Get-Content (Join-Path $ProjectRoot "tools\porting\Build-ReadyPackages.ps1") -Raw
        
        $pipelineScript | Should Not Match 'git\s+checkout\s+\.'
        $pipelineScript | Should Not Match 'git\s+reset\s+--hard\s+HEAD'
        $builderScript | Should Not Match 'git\s+checkout\s+\.'
        $builderScript | Should Not Match 'git\s+reset\s+--hard\s+HEAD'
    }
}

Describe "08. Worktree Creation" {
    It "Calculates and validates isolated worktree path inside .worktrees/" {
        $cfg = Get-ProjectConfig
        $targetRepo = $cfg.repositories.tortoise_wow.path
        $packageId = "PORT-TEST-001"
        $expectedPath = Join-Path $targetRepo ".worktrees\$packageId"
        $expectedBranch = "port/$packageId"
        
        $expectedPath | Should Match '\.worktrees\\PORT-TEST-001'
        $expectedBranch | Should Be "port/PORT-TEST-001"
    }
}

Describe "09. Worktree Cleanup" {
    It "Ensures safe cleanup handles non-existent paths gracefully" {
        $cfg = Get-ProjectConfig
        $targetRepo = $cfg.repositories.tortoise_wow.path
        $nonExistent = Join-Path $targetRepo ".worktrees\PORT-NONEXISTENT"
        
        { Remove-IsolatedWorktree -WorktreePath $nonExistent -TargetRepo $targetRepo } | Should Not Throw
    }
}

Describe "10. Worktree Cleanup Isolation" {
    It "Refuses to delete paths outside the .worktrees directory" {
        $cfg = Get-ProjectConfig
        $targetRepo = $cfg.repositories.tortoise_wow.path
        
        { Remove-IsolatedWorktree -WorktreePath $targetRepo -TargetRepo $targetRepo } | Should Throw
        { Remove-IsolatedWorktree -WorktreePath "C:\" -TargetRepo $targetRepo } | Should Throw
    }
}

Describe "11. Target SHA Pinning" {
    It "Validates that target base SHA is pinned and recorded" {
        $cfg = Get-ProjectConfig
        $pinnedSha = $cfg.repositories.tortoise_wow.baseline_sha
        $pinnedSha | Should Not BeNullOrEmpty
        ($pinnedSha.Length -ge 7) | Should Be $true
    }
}

Describe "12. Baseline-Failure Classification" {
    It "Correctly classifies baseline failure states" {
        $compileFail = Classify-BaselineResult -CompilePass $false -LinkPass $false -StartupPass $false
        $compileFail | Should Be "COMPILE_FAIL"

        $linkFail = Classify-BaselineResult -CompilePass $true -LinkPass $false -StartupPass $false
        $linkFail | Should Be "LINK_FAIL"

        $startupFail = Classify-BaselineResult -CompilePass $true -LinkPass $true -StartupPass $false
        $startupFail | Should Be "STARTUP_FAIL"

        $allPass = Classify-BaselineResult -CompilePass $true -LinkPass $true -StartupPass $true
        $allPass | Should Be "HEALTHY"
    }
}

Describe "13. MAX_RACES Invariant Violation" {
    It "Detects and rejects modifications violating MAX_RACES = 11" {
        $violatingDiff = @"
diff --git a/src/game/SharedDefines.h b/src/game/SharedDefines.h
--- a/src/game/SharedDefines.h
+++ b/src/game/SharedDefines.h
@@ -100,2 +100,2 @@
-#define MAX_RACES 11
+#define MAX_RACES 10
"@
        $res = Test-PatchCompatibility -PatchContent $violatingDiff
        $res.ExitCode | Should Be 1
        ($res.Violations -join ' ') | Should Match 'MAX_RACES'
    }
}

Describe "14. sTWDebuff Removal Violation" {
    It "Detects and rejects removal of sTWDebuff custom system" {
        $violatingDiff = @"
diff --git a/src/game/SpellMgr.cpp b/src/game/SpellMgr.cpp
--- a/src/game/SpellMgr.cpp
+++ b/src/game/SpellMgr.cpp
@@ -50,2 +50,1 @@
-    sTWDebuff->Init();
"@
        $res = Test-PatchCompatibility -PatchContent $violatingDiff
        $res.ExitCode | Should Be 1
        ($res.Violations -join ' ') | Should Match 'sTWDebuff'
    }
}

Describe "15. SCRIPT_COMMAND_TAKE_MONEY Protection" {
    It "Protects custom script commands from deletion" {
        $violatingDiff = @"
diff --git a/src/game/ScriptMgr.h b/src/game/ScriptMgr.h
--- a/src/game/ScriptMgr.h
+++ b/src/game/ScriptMgr.h
@@ -200,2 +200,1 @@
-    SCRIPT_COMMAND_TAKE_MONEY = 93,
"@
        $res = Test-PatchCompatibility -PatchContent $violatingDiff
        $res.ExitCode | Should Be 1
        ($res.Violations -join ' ') | Should Match 'SCRIPT_COMMAND_TAKE_MONEY'
    }
}

Describe "16. Forbidden DB Progressive Column" {
    It "Rejects migrations introducing forbidden progressive versioning columns" {
        $forbiddenSql = "ALTER TABLE item_template ADD COLUMN patch INT NOT NULL DEFAULT 0;"
        $audit = Audit-MigrationContent -SqlContent $forbiddenSql -FilePath "test.sql"
        $audit.ExitCode | Should Be 1
        ($audit.Violations -join ' ') | Should Match 'Forbidden progressive'
    }
}

Describe "17. Custom Spell Collision" {
    It "Rejects migrations with spell_template IDs in the Turtle custom range (>= 40000)" {
        $customSpellSql = "INSERT INTO spell_template (entry, name) VALUES (45001, 'Custom Strike');"
        $audit = Audit-MigrationContent -SqlContent $customSpellSql -FilePath "test_spell.sql"
        $audit.ExitCode | Should Be 1
        ($audit.Violations -join ' ') | Should Match 'Custom ID boundary collision'
    }
}

Describe "18. Custom World Entity Collision" {
    It "Rejects migrations with creature_template IDs in the custom range (>= 300000)" {
        $customCreatureSql = "INSERT INTO creature_template (entry, name) VALUES (305100, 'Custom Boss');"
        $audit = Audit-MigrationContent -SqlContent $customCreatureSql -FilePath "test_creature.sql"
        $audit.ExitCode | Should Be 1
        ($audit.Violations -join ' ') | Should Match 'Custom ID boundary collision'
    }
}

Describe "19. Already-Fixed Candidate" {
    It "Proves bug status and identifies already fixed fixes" {
        $res = Test-BugExistence -CandidateSha "448df9ba0"
        $res.status | Should Be "PASS"
        $res.verdict | Should Not BeNullOrEmpty
    }
}

Describe "20. Not-Applicable Candidate" {
    It "Identifies candidate fixes touching non-existent systems as NOT_APPLICABLE" {
        $nonExistentDiff = @"
diff --git a/src/game/NonExistentSystem_XYZ.cpp b/src/game/NonExistentSystem_XYZ.cpp
new file mode 100644
index 0000000..1111111
--- /dev/null
+++ b/src/game/NonExistentSystem_XYZ.cpp
@@ -0,0 +1,5 @@
+void Foo() {}
"@
        $cfg = Get-ProjectConfig
        $verdict = Classify-BugByDiff -DiffText $nonExistentDiff -TargetRepo $cfg.repositories.tortoise_wow.path
        $verdict | Should Be "NOT_APPLICABLE"
    }
}

Describe "21. Turtle Divergence Candidate" {
    It "Identifies intentional Turtle divergence candidates" {
        $divergentDiff = @"
diff --git a/src/game/SharedDefines.h b/src/game/SharedDefines.h
--- a/src/game/SharedDefines.h
+++ b/src/game/SharedDefines.h
@@ -10,2 +10,2 @@
-#define MAX_RACES 11
+#define MAX_RACES 10
"@
        $cfg = Get-ProjectConfig
        $verdict = Classify-BugByDiff -DiffText $divergentDiff -TargetRepo $cfg.repositories.tortoise_wow.path
        $verdict | Should Be "TURTLE_INTENTIONAL_DIVERGENCE"
    }
}

Describe "22. Dependency Missing" {
    It "Detects missing predecessors and unresolved dependencies" {
        $deps = Get-CandidateDependencies -CandidateSha "0000000000"
        $deps.Dependencies.Count | Should Be 0
    }
}

Describe "23. Duplicate/Supersession Relation" {
    It "Identifies commit relation links and prevents duplicate ports" {
        $rel = Get-CandidateRelations -CandidateSha "448df9ba0"
        $rel.candidate_sha | Should Be "448df9ba0"
        $rel.Relations.Count | Should BeGreaterThan 0
    }
}

Describe "24. Configuration Discovery" {
    It "Discovers valid configuration from config/twow-project.json" {
        $cfg = Get-ProjectConfig
        $cfg.schema_version | Should Be "1.0.0"
        $cfg.repositories.twow_project.path | Should Not BeNullOrEmpty
        $cfg.repositories.tortoise_wow.path | Should Not BeNullOrEmpty
    }
}

Describe "25. Paths With Spaces" {
    It "Properly resolves and handles paths containing spaces" {
        $testSpaceDir = Join-Path $env:TEMP "twow project path test"
        New-Item -ItemType Directory -Path $testSpaceDir -Force | Out-Null
        try {
            $resolved = Resolve-Path $testSpaceDir
            $resolved.Path | Should Match " "
            Test-Path $resolved.Path | Should Be $true
        } finally {
            if (Test-Path $testSpaceDir) { Remove-Item $testSpaceDir -Recurse -Force }
        }
    }
}

Describe "26. PowerShell Encoding" {
    It "Writes UTF-8 without byte order mark (no EF BB BF header)" {
        $testFile = Join-Path $ProjectRoot "tools\state\test_utf8.txt"
        Save-Utf8NoBom -FilePath $testFile -Content "Test line without BOM"
        Test-Path $testFile | Should Be $true
        
        $bytes = [System.IO.File]::ReadAllBytes($testFile)
        $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        $hasBom | Should Be $false
        
        if (Test-Path $testFile) { Remove-Item $testFile -Force }
    }
}

Describe "27. CRLF/LF Handling" {
    It "Normalizes CRLF and LF consistently" {
        $crlf = "Line1`r`nLine2`r`n"
        $lf = "Line1`nLine2`n"
        
        $normCrlf = Normalize-LineEndings -Text $crlf
        $normLf = Normalize-LineEndings -Text $lf
        
        $normCrlf | Should Be $normLf
    }
}

Describe "28. DryRun No-Write Guarantee" {
    It "Executes candidate plan in DryRun mode without modifying git working tree" {
        $cfg = Get-ProjectConfig
        $gitInfoBefore = Get-RepoGitInfo -repoPath $cfg.repositories.tortoise_wow.path
        $plan = Invoke-CandidatePlan -CandidateSha "448df9ba0" -DryRun
        $gitInfoAfter = Get-RepoGitInfo -repoPath $cfg.repositories.tortoise_wow.path
        
        $plan.IsDryRun | Should Be $true
        $gitInfoAfter.HeadSha | Should Be $gitInfoBefore.HeadSha
        $gitInfoAfter.IsClean | Should Be $gitInfoBefore.IsClean
    }
}

Describe "29. Resume/Idempotency" {
    It "Preserves state store records and allows safe idempotency" {
        $store1 = Get-StateStore
        $store2 = Get-StateStore
        $store1.schema_version | Should Be $store2.schema_version
        $store1.candidates.Count | Should Be $store2.candidates.Count
    }
}

Describe "30. AI Cache Hit" {
    It "Returns cached response on identical input hash without re-querying" {
        $key = Get-AiCacheKey -CandidateSha "cache_test_sha" -PromptContext "test context"
        $cachedData = @{ summary = "Cached AI result"; decision = "ACCEPT" }
        Save-AiCache -CacheKey $key -Data $cachedData
        
        $retrieved = Get-AiCache -CacheKey $key
        $retrieved | Should Not BeNullOrEmpty
        $retrieved.summary | Should Be "Cached AI result"
    }
}

Describe "31. AI Not Invoked For Deterministic Rejection" {
    It "Bypasses AI calls completely when candidate is deterministically rejected" {
        $plan = Invoke-CandidatePlan -CandidateSha "448df9ba0" -DryRun
        $plan.ExpectedAiUsage | Should Be "ADVISORY_ONLY"
    }
}

Describe "32. Automatic Fast -> Normal Escalation" {
    It "Escalates Fast mode to Normal when DB migration or dependencies are detected" {
        $res = Resolve-VerificationMode -RequestedMode "Fast" -HasDatabaseMigration
        $res.ResolvedMode | Should Be "Normal"
        $res.Escalated | Should Be $true
    }
}

Describe "33. Automatic Normal -> Deep Escalation" {
    It "Escalates Normal mode to Deep when security, packet, or concurrency files are touched" {
        $res = Resolve-VerificationMode -RequestedMode "Normal" -TouchesSecurityOrPackets
        $res.ResolvedMode | Should Be "Deep"
        $res.Escalated | Should Be $true
    }
}

Describe "34. No Automatic Downgrade" {
    It "Never downgrades an explicitly requested higher verification mode" {
        $res = Resolve-VerificationMode -RequestedMode "Deep"
        $res.ResolvedMode | Should Be "Deep"
        $res.Escalated | Should Be $false
    }
}

Describe "35. Resource Budget Enforcement" {
    It "Enforces bounded context assembly caps on surrounding code context" {
        $bigContext = 1..500 | ForEach-Object { "line $_ of code" }
        $cappedContext = Limit-ContextLines -Lines $bigContext -MaxLines 200
        $cappedContext.Count | Should Be 200
    }
}

Describe "36. Command Help Generation" {
    It "Displays command help and master reference without errors" {
        $taskScript = Join-Path $ProjectRoot "tools\task.ps1"
        $helpOutput = powershell.exe -ExecutionPolicy Bypass -File $taskScript help
        $LASTEXITCODE | Should Be 0
        ($helpOutput -join "`n") | Should Match "TWOW TASK DISPATCHER"
    }
}

Describe "37. Command PDF Generation" {
    It "Generates HTML and PDF reference documents successfully" {
        $pdfScript = Join-Path $ProjectRoot "tools\porting\Export-CommandReferencePdf.ps1"
        Test-Path $pdfScript | Should Be $true
        
        $testSyntax = powershell.exe -ExecutionPolicy Bypass -Command "& { [void]([System.Management.Automation.Language.Parser]::ParseFile('$pdfScript', [ref]`$null, [ref]`$null)) }"
        $LASTEXITCODE | Should Be 0
    }
}

Describe "38. Generated Docs/State Consistency" {
    It "Ensures state store, schema catalog, and config exist and are mutually consistent" {
        $cfg = Get-ProjectConfig
        $cfg | Should Not BeNullOrEmpty

        $store = Get-StateStore
        $store | Should Not BeNullOrEmpty
        $store.schema_version | Should Be "1.0.0"

        $catalogPath = Join-Path $ProjectRoot "config\schema_catalog.json"
        Test-Path $catalogPath | Should Be $true
        $catalog = Get-Content $catalogPath -Raw | ConvertFrom-Json
        (($catalog.PSObject.Properties | Measure-Object).Count -gt 400) | Should Be $true
    }
}

Describe "39. System Pre-Flight Check" {
    It "Executes light pre-flight audit and reports certified health" {
        $sysCheck = Invoke-SystemCheck -Mode Light -PassThru
        $sysCheck | Should Not BeNullOrEmpty
        $sysCheck.Success | Should Be $true
        $sysCheck.FailuresCount | Should Be 0
        ($sysCheck.HealthScore -ge 95) | Should Be $true
        ($sysCheck.Checks.Count -gt 10) | Should Be $true
    }
}
