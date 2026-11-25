# Run from a normal local PowerShell session if this task cannot write .git.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

function Invoke-GitChecked {
    param([string[]]$GitArguments)
    & git @GitArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Git failed: $($GitArguments -join ' ')"
    }
}

Push-Location -LiteralPath $projectRoot
try {
    $branch = & git branch --show-current
    if ($LASTEXITCODE -ne 0 -or $branch -ne 'master') {
        throw 'Expected the master branch. No branch was changed.'
    }
    & git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        throw 'Staged changes exist. Commit or unstage them before syncing.'
    }

    $remotes = @{
        origin = 'https://github.com/yuweiran/cvpn.git'
        upstream = 'https://github.com/wg-easy/wg-easy.git'
    }
    $existingRemoteNames = @(& git remote)
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to inspect Git remotes.'
    }
    foreach ($remoteName in @('origin', 'upstream')) {
        if ($existingRemoteNames -contains $remoteName) {
            $existingUrl = & git remote get-url $remoteName
            if ($LASTEXITCODE -ne 0) {
                throw "Unable to inspect $remoteName."
            }
            if ($existingUrl -ne $remotes[$remoteName]) {
                throw "Unexpected $remoteName URL; left unchanged."
            }
        } else {
            Invoke-GitChecked -GitArguments @('remote', 'add', $remoteName, $remotes[$remoteName])
        }
    }

    Invoke-GitChecked -GitArguments @('fetch', 'origin')
    & git merge-base --is-ancestor HEAD origin/master
    if ($LASTEXITCODE -ne 0) {
        throw 'Local history has diverged. No reset was performed.'
    }

    # Only advance to a descendant commit. Mixed reset preserves working files.
    Invoke-GitChecked -GitArguments @('reset', '--mixed', 'origin/master')
    Invoke-GitChecked -GitArguments @('branch', '--set-upstream-to=origin/master', 'master')
    Invoke-GitChecked -GitArguments @('remote', 'set-url', '--push', 'upstream', 'DISABLED')
    Invoke-GitChecked -GitArguments @('remote', '-v')
    Invoke-GitChecked -GitArguments @('status', '--short', '--branch')
} finally {
    Pop-Location
}
