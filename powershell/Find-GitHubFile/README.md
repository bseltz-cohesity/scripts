# Find-GitHubFile (PowerShell)

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script searches the files in a GitHub repo, similar to GitHub's own "Go to file" search box. Given one or more search terms, it pulls the repo's file tree via the GitHub API, finds every path that contains all of the terms as a literal, case-insensitive substring, and prints the matches along with a link to the enclosing folder on GitHub. The file tree is cached locally for a few minutes so repeated searches against the same repo/branch don't keep hitting the API.

## Download the script

Run these commands from PowerShell to download the script into your current directory

```powershell
# Download Commands
$scriptName = 'Find-GitHubFile'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
# End Download Commands
```

## Usage

```powershell
./Find-GitHubFile.ps1 -Query "backupNow" `
                      -Repo "cohesity/community-automation-samples"
```

`-Query` also binds positionally, and `-Repo` defaults to `cohesity/community-automation-samples`, so the shortest form of a search is just:

```powershell
./Find-GitHubFile.ps1 "backupNow"
```

## Parameters

* -Query: one or more search terms, e.g. `backupNow`. Each term is matched as a literal, case-insensitive substring of the file path. When more than one term is given, a file must match ALL of them to be considered a result
* -Repo: (optional) the GitHub repo to search, in `owner/name` form (defaults to `cohesity/community-automation-samples`)
* -Branch: (optional) the branch or ref to search (defaults to the repo's default branch)
* -Token: (optional) a GitHub personal access token, used to raise the API rate limit and to access private repos (defaults to the `$env:GITHUB_TOKEN` environment variable if set)
* -Top: (optional) the max number of results to show (defaults to `50`)
* -NoCache: (optional) skip the local file-tree cache and force a fresh fetch from GitHub
* -CacheMinutes: (optional) how long the local file-tree cache stays valid, in minutes (defaults to `15`)
* -IncludeReadme: (optional) include `README.md` files in results (excluded by default since they show up in nearly every directory and are usually just noise)
* -PowerShell: (optional) only match PowerShell files (`.ps1`, `.psm1`, `.psd1`) -- combinable with `-Python` / `-Bash`
* -Python: (optional) only match Python files (`.py`) -- combinable with `-PowerShell` / `-Bash`
* -Bash: (optional) only match shell script files (`.sh`, `.bash`) -- combinable with `-PowerShell` / `-Python`

## Examples

Basic search of the default repo:

```powershell
./Find-GitHubFile.ps1 "backupNow"
```

Search a different repo and branch, with more results:

```powershell
./Find-GitHubFile.ps1 -Query "moduleCmdletDiscovery" `
                      -Repo "PowerShell/PowerShell" `
                      -Branch master `
                      -Top 25
```

Search a private repo using a token:

```powershell
$env:GITHUB_TOKEN = 'ghp_xxx'
./Find-GitHubFile.ps1 -Query "config.yml" `
                      -Repo "myorg/private-repo"
```

Only match PowerShell files:

```powershell
./Find-GitHubFile.ps1 -Query "backup" -PowerShell
```

Require multiple terms to all match:

```powershell
./Find-GitHubFile.ps1 -Query "backupNow", "ccs"
```

## What the output shows

* **Matches**: each result's full repo-relative file path, sorted alphabetically
* **Directory link**: the URL to the GitHub folder containing that file
