<#
.SYNOPSIS
    Fuzzy-search files in a GitHub repo, like GitHub's "Go to file" box.

.DESCRIPTION
    Pulls the full file tree for a repo/branch via the GitHub API, then finds
    every path that contains your query as a literal, case-insensitive
    substring (no scattered-letter fuzzy matching), and prints the matches
    ranked so filename hits outrank directory-only hits.

    The tree is cached locally (default: 15 minutes) so repeated searches
    against the same repo/branch don't keep hitting the API.

.PARAMETER Query
    One or more search terms, e.g. "baseauth" or "backup","restore". Each
    term is matched as a literal, case-insensitive substring of the file
    path. When more than one term is given, a file must match ALL of them
    (in any order/location) to be considered a result.

.PARAMETER Repo
    Repo in "owner/name" form, e.g. "cohesity/community-automation-samples".
    Default: "cohesity/community-automation-samples".

.PARAMETER Exclude
    One or more strings to filter out of the results. Any path containing
    ANY of these terms (case-insensitive substring match) is dropped, even
    if it matched -Query.

.PARAMETER Branch
    Branch or ref to search. Default: repo's default branch.

.PARAMETER Token
    GitHub personal access token. Optional for public repos (raises the rate
    limit from 60/hr to 5000/hr), required for private repos. Falls back to
    the $env:GITHUB_TOKEN environment variable if not supplied.

.PARAMETER Top
    Max number of results to show. Default: 50.

.PARAMETER NoCache
    Skip the local tree cache and force a fresh fetch.

.PARAMETER IncludeReadme
    Include README.md files in results. Excluded by default since they show
    up in nearly every directory and are usually just noise.

.PARAMETER PowerShell
    Only match PowerShell files (.ps1, .psm1, .psd1). Combinable with
    -Python / -Bash to match any of the selected languages.

.PARAMETER Python
    Only match Python files (.py).

.PARAMETER Bash
    Only match shell script files (.sh, .bash).

.EXAMPLE
    .\Find-GitHubFile.ps1 "baseauth"
    # Searches the default repo, cohesity/community-automation-samples.

.EXAMPLE
    .\Find-GitHubFile.ps1 -Query "modulecmdletDiscovery" -Repo "PowerShell/PowerShell" -Branch master -Top 25

.EXAMPLE
    $env:GITHUB_TOKEN = "ghp_xxx"
    .\Find-GitHubFile.ps1 -Query "config.yml" -Repo "myorg/private-repo"

.EXAMPLE
    .\Find-GitHubFile.ps1 -Query "backup" -PowerShell

.EXAMPLE
    .\Find-GitHubFile.ps1 -Query "restore" -Repo "cohesity/community-automation-samples" -Python -Bash

.EXAMPLE
    .\Find-GitHubFile.ps1 -Query "backup", "now"
    # Only matches paths containing BOTH "backup" and "now".

.EXAMPLE
    .\Find-GitHubFile.ps1 -Query "backup" -Exclude "test", "archive"
    # Matches "backup" but drops any path containing "test" or "archive".
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)][string[]]$Query,
    [Parameter(Position = 1)][ValidatePattern('^[\w.-]+/[\w.-]+$')][string]$Repo = 'cohesity/community-automation-samples',
    [Parameter()][string[]]$Exclude,
    [Parameter()][string]$Branch,
    [Parameter()][string]$Token = $env:GITHUB_TOKEN,
    [Parameter()][int]$Top = 50,
    [Parameter()][switch]$NoCache,
    [Parameter()][int]$CacheMinutes = 15,
    [Parameter()][switch]$IncludeReadme,
    [Parameter()][switch]$PowerShell,
    [Parameter()][switch]$Python,
    [Parameter()][switch]$Bash
)

# Map each language switch to the file extensions it should match.
$LanguageExtensions = @{
    PowerShell = @('.ps1', '.psm1', '.psd1')
    Python     = @('.py')
    Bash       = @('.sh', '.bash')
}

$ErrorActionPreference = 'Stop'

function Get-GitHubHeaders {
    param([string]$Token)
    $headers = @{
        'Accept'               = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
        'User-Agent'           = 'Find-GitHubFile-PS'
    }
    if ($Token) {
        $headers['Authorization'] = "Bearer $Token"
    }
    return $headers
}

function Get-DefaultBranch {
    param([string]$Repo, [hashtable]$Headers)
    $uri = "https://api.github.com/repos/$Repo"
    $resp = Invoke-RestMethod -Uri $uri -Headers $Headers -Method Get -TimeoutSec 90
    return $resp.default_branch
}

function Get-RepoTree {
    param([string]$Repo, [string]$Branch, [hashtable]$Headers)
    $uri = "https://api.github.com/repos/$Repo/git/trees/$Branch`?recursive=1"
    $resp = Invoke-RestMethod -Uri $uri -Headers $Headers -Method Get -TimeoutSec 90
    if ($resp.truncated) {
        Write-Warning "GitHub truncated the tree response (repo is very large). Results may be incomplete."
    }
    return $resp.tree | Where-Object { $_.type -eq 'blob' } | Select-Object -ExpandProperty path
}

function Get-CachePath {
    param([string]$Repo, [string]$Branch)
    $safe = ($Repo -replace '[\\/:]', '_') + "_" + ($Branch -replace '[\\/:]', '_')
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) "gh-file-search-cache"
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    return Join-Path $dir "$safe.json"
}

function Get-FuzzyScore {
    param(
        [string[]]$Queries,
        [string]$Candidate
    )

    if (-not $Queries -or $Queries.Count -eq 0) { return 0 }

    $cLower = $Candidate.ToLowerInvariant()
    $fileName = $Candidate.Split('/')[-1]
    $fileNameLower = $fileName.ToLowerInvariant()
    $fileStemLower = [System.IO.Path]::GetFileNameWithoutExtension($fileNameLower)

    $totalScore = 0

    foreach ($term in $Queries) {
        $qLower = $term.ToLowerInvariant()

        if (-not $cLower.Contains($qLower)) {
            return -1  # every term must match -> this one doesn't, no result
        }

        $score = 100

        if ($fileStemLower.Contains($qLower)) {
            $score += 60
            $matchIndex = $fileStemLower.IndexOf($qLower)
        }
        elseif ($fileNameLower.Contains($qLower)) {
            $score += 30
            $matchIndex = $fileNameLower.IndexOf($qLower)
        }
        else {
            # match is somewhere in the directory part of the path only
            $matchIndex = $cLower.IndexOf($qLower)
        }

        # earlier matches score a bit higher
        $score -= [math]::Min(20, $matchIndex)

        # exact filename (stem) match is the best possible result
        if ($fileStemLower -eq $qLower) {
            $score += 50
        }

        $totalScore += $score
    }

    # shorter paths rank slightly higher among otherwise-equal matches
    $lengthPenalty = [math]::Min(15, [math]::Floor($Candidate.Length / 10))
    $totalScore -= $lengthPenalty

    return $totalScore
}

# --- main ---

$headers = Get-GitHubHeaders -Token $Token

if (-not $Branch) {
    Write-Verbose "No branch specified, looking up default branch for $Repo..."
    $Branch = Get-DefaultBranch -Repo $Repo -Headers $headers
}

$cachePath = Get-CachePath -Repo $Repo -Branch $Branch
$paths = $null

if (-not $NoCache -and (Test-Path $cachePath)) {
    $age = (Get-Date) - (Get-Item $cachePath).LastWriteTime
    if ($age.TotalMinutes -le $CacheMinutes) {
        Write-Verbose "Using cached tree ($([math]::Round($age.TotalMinutes,1)) min old)."
        $paths = Get-Content $cachePath -Raw | ConvertFrom-Json
    }
}

if (-not $paths) {
    Write-Verbose "Fetching file tree for $Repo@$Branch..."
    try {
        $paths = Get-RepoTree -Repo $Repo -Branch $Branch -Headers $headers
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 403) {
            throw "GitHub API rate limit hit or access denied. Pass -Token with a PAT (or set `$env:GITHUB_TOKEN) to raise the limit / access private repos."
        }
        elseif ($statusCode -eq 404) {
            throw "Repo '$Repo' or branch '$Branch' not found (or you lack access to it)."
        }
        else {
            throw
        }
    }
    $paths | ConvertTo-Json -Depth 1 | Set-Content -Path $cachePath -Encoding utf8
}

if (-not $IncludeReadme) {
    $before = $paths.Count
    $paths = $paths | Where-Object { (Split-Path -Path $_ -Leaf) -notmatch '^readme\.md$' }
    Write-Verbose "Filtered out $($before - $paths.Count) README.md file(s)."
}

$selectedLanguages = @($PSBoundParameters.Keys | Where-Object { $LanguageExtensions.ContainsKey($_) })
if ($selectedLanguages.Count -gt 0) {
    $allowedExtensions = $selectedLanguages | ForEach-Object { $LanguageExtensions[$_] } | Select-Object -Unique
    $before = $paths.Count
    $paths = $paths | Where-Object {
        $ext = [System.IO.Path]::GetExtension($_).ToLowerInvariant()
        $allowedExtensions -contains $ext
    }
    Write-Verbose "Filtered to $($paths.Count) file(s) matching language(s): $($selectedLanguages -join ', ') (was $before)."
}

if ($Exclude -and $Exclude.Count -gt 0) {
    $excludeLower = $Exclude | ForEach-Object { $_.ToLowerInvariant() }
    $before = $paths.Count
    $paths = $paths | Where-Object {
        $pLower = $_.ToLowerInvariant()
        -not ($excludeLower | Where-Object { $pLower.Contains($_) })
    }
    Write-Verbose "Excluded $($before - $paths.Count) file(s) matching: $($Exclude -join ', ')."
}

$queryLabel = $Query -join "' + '"

Write-Verbose "Scoring $($paths.Count) files against query '$queryLabel'..."

$results = foreach ($p in $paths) {
    $score = Get-FuzzyScore -Queries $Query -Candidate $p
    if ($score -ge 0) {
        [PSCustomObject]@{
            Score = $score
            Path  = $p
        }
    }
}

$ranked = $results |
    Sort-Object -Property Score -Descending |
    Select-Object -First $Top -Property Path |
    Sort-Object -Property Path |
    ForEach-Object {
        $dir = Split-Path -Path $_.Path -Parent
        if ($dir) {
            $dirUrl = "https://github.com/$Repo/tree/$Branch/$($dir -replace '\\','/')"
        }
        else {
            $dirUrl = "https://github.com/$Repo/tree/$Branch"
        }
        [PSCustomObject]@{
            Path         = $_.Path
            DirectoryUrl = $dirUrl
        }
    }

if (-not $ranked) {
    Write-Host "No matches for '$queryLabel' in $Repo@$Branch." -ForegroundColor Yellow
    return
}

Write-Host "`nMatches for '$queryLabel' in $Repo@$Branch (of $($paths.Count) files):`n" -ForegroundColor Cyan

foreach ($r in $ranked) {
    Write-Host $r.Path -ForegroundColor White
    Write-Host $r.DirectoryUrl -ForegroundColor DarkGray
}
Write-Host ""
