# patchbot — external fact (facts.d, pluginsynced from the stagehand module;
# formerly named pcm_patch), Windows.
#
# Sibling of patchbot.sh. Same fact name, same consumers (Patching page,
# Action Center, and the correlation engine behind the Labs
# `computed_findings` flag), Windows-appropriate fields.
#
# ---------------------------------------------------------------------------
# THE POINT OF THIS FILE: os_build is the whole Windows vulnerability story.
#
# Since Windows 10 / Server 2016, cumulative updates are exactly that — a host
# on the January LCU contains every fix shipped since 2016. MSRC, however,
# links a CVE only to the KB that FIRST fixed it. So the obvious correlation —
# intersect installed KBs with the KBs named per CVE — reports thousands of
# false positives, because none of those historical KB IDs are individually
# present. Every naive Windows scanner has this bug.
#
# MSRC also publishes `FixedBuild` per remediation per product
# (e.g. "10.0.20348.1970"). Comparing the host's actual build against that is a
# monotonic integer comparison: immune to supersedence, no KB graph to walk, no
# missing-edge problem. So the primary signal this fact must deliver, quickly
# and always, is an accurate four-part build number.
#
# Everything else here is enrichment.
# ---------------------------------------------------------------------------
#
# SPEED: this runs on every Facter run, so it must be fast. The registry reads
# below are sub-millisecond. The expensive part — asking the Windows Update
# Agent what is installed and what is missing, which can take minutes and needs
# to reach WSUS/WU — is NOT done here. It is done by patchbot_refresh.ps1 on a
# scheduled task, which writes a cache this fact merely reads. That is the same
# scanner/fact split pe_patch uses, and for the same reason.
#
# A cold or missing cache is not an error: os_build still resolves, so Windows
# vulnerability correlation works on a host whose WUA scan has never run.
#
# Output: one line of JSON on stdout (Facter 4 / Puppet 8 — i.e. Puppet Core;
# the only stack we target, see docs: NO OpenVox), matching patchbot.sh.

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference    = 'SilentlyContinue'

$CacheFile = Join-Path $env:ProgramData 'PuppetLabs\patchbot\patch_cache.json'
$CacheMaxAgeSeconds = 86400 * 2   # cache older than this is reported stale

function Get-OsBuild {
    # Four-part build: CurrentMajorVersionNumber.CurrentMinorVersionNumber.
    # CurrentBuildNumber.UBR — e.g. 10.0.20348.3328.
    #
    # UBR is the revision that changes with every cumulative update and is the
    # ONLY part that distinguishes a patched host from an unpatched one. It
    # lives in the registry and nowhere else convenient: Facter's os.release
    # stops at the build number, and [Environment]::OSVersion has been
    # shimmed/lying since Windows 8.1. Read the registry.
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $cv  = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
    if ($null -eq $cv) { return $null }

    $major = $cv.CurrentMajorVersionNumber
    $minor = $cv.CurrentMinorVersionNumber
    if ($null -eq $major) {
        # Pre-Windows 10 (Server 2012 R2 and older) has no
        # CurrentMajorVersionNumber; fall back to the "6.3" style string.
        $parts = ("$($cv.CurrentVersion)").Split('.')
        if ($parts.Count -ge 2) { $major = $parts[0]; $minor = $parts[1] }
        else { return $null }
    }
    $build = $cv.CurrentBuildNumber
    $ubr   = $cv.UBR
    if ($null -eq $ubr) { $ubr = 0 }   # absent on pre-Win10; treat as .0
    return "$major.$minor.$build.$ubr"
}

function Test-RebootPending {
    # Four independent signals; any one of them means pending. Checked in
    # cheapest-first order.
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { return $true }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { return $true }

    $sm = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue
    if ($null -ne $sm -and $null -ne $sm.PendingFileRenameOperations -and $sm.PendingFileRenameOperations.Count -gt 0) { return $true }

    # SCCM's own opinion, only when the client is actually installed.
    if (Get-CimInstance -Namespace 'root\ccm\clientsdk' -ClassName 'CCM_ClientUtilities' -ErrorAction SilentlyContinue) {
        $r = Invoke-CimMethod -Namespace 'root\ccm\clientsdk' -ClassName 'CCM_ClientUtilities' `
                              -MethodName 'DetermineIfRebootPending' -ErrorAction SilentlyContinue
        if ($null -ne $r -and ($r.RebootPending -eq $true -or $r.IsHardRebootPending -eq $true)) { return $true }
    }
    return $false
}

# ---- fast path: always available, no network, no WUA -----------------------
$osBuild = Get-OsBuild
$reboot  = Test-RebootPending

# ---- cached path: whatever the last refresh managed to collect -------------
$cache        = $null
$cacheAge     = $null
$cacheStale   = $true
if (Test-Path $CacheFile) {
    try {
        $cache    = Get-Content -Path $CacheFile -Raw -ErrorAction Stop | ConvertFrom-Json
        $written  = [DateTime]::Parse($cache.generated_at, [Globalization.CultureInfo]::InvariantCulture,
                                      [Globalization.DateTimeStyles]::RoundtripKind)
        $cacheAge = [int]([DateTime]::UtcNow - $written.ToUniversalTime()).TotalSeconds
        $cacheStale = ($cacheAge -gt $CacheMaxAgeSeconds)
    } catch {
        $cache = $null   # unreadable cache is a cold cache, not a failure
    }
}

$installedKbs = @()
$missing      = @()
$source       = 'unknown'
$wsus         = $null
$scanError    = $null
$cvePopulated = $null

if ($null -ne $cache) {
    if ($cache.installed_kbs) { $installedKbs = @($cache.installed_kbs) }
    if ($cache.missing)       { $missing      = @($cache.missing) }
    if ($cache.source)        { $source       = [string]$cache.source }
    if ($cache.wsus_server)   { $wsus         = [string]$cache.wsus_server }
    if ($cache.scan_error)    { $scanError    = [string]$cache.scan_error }
    # Diagnostic, deliberately surfaced as a fact: does WUA actually populate
    # IUpdate2::CveIDs on this OS? Documented as existing since XP, but no
    # tooling in the wild reads it and every real scanner correlates KB->CVE
    # externally instead. If this comes back true across a fleet, a large part
    # of the correlation engine collapses into a local API call.
    if ($null -ne $cache.cve_ids_populated) { $cvePopulated = [bool]$cache.cve_ids_populated }
}

$securityCount = @($missing | Where-Object { $_.severity -and $_.severity -ne 'Unspecified' }).Count

$payload = [ordered]@{
    available       = $missing.Count
    security        = $securityCount
    reboot_required = $reboot
    last_checked    = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    manager         = 'wua'
    os_build        = $osBuild
    installed_kbs   = $installedKbs
    missing         = $missing
    source          = $source
    wsus_server     = $wsus
    package_count   = $missing.Count
    truncated       = $false
    # Staleness is reported, never hidden. A scan against a two-week-old view
    # of Windows Update is not evidence of anything, and the console's coverage
    # view exists to say so out loud.
    cache_age_seconds  = $cacheAge
    cache_stale        = $cacheStale
    cve_ids_populated  = $cvePopulated
    scan_error         = $scanError
}

# -Compress keeps it to one line; Depth 6 covers missing[].cve_ids.
@{ patchbot = $payload } | ConvertTo-Json -Compress -Depth 6
