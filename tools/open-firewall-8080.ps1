# Open inbound TCP 8080 in Windows Firewall so Android phones on the same
# LAN can reach the RMODZ signaling server running on this PC.
#
# Usage: right-click PowerShell -> "Run as administrator", then:
#   powershell -ExecutionPolicy Bypass -File tools\open-firewall-8080.ps1
#
# Returns 0 and prints "OK" on success, or a non-zero exit code on failure.

$port = 8080
$ruleName = "RMODZ Server TCP 8080"

$existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Output "Rule '$ruleName' already exists."
    exit 0
}

try {
    New-NetFirewallRule `
        -DisplayName $ruleName `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort $port `
        -Action Allow `
        -Profile Any `
        -ErrorAction Stop | Out-Null
    Write-Output "OK: inbound TCP $port allowed for all profiles."
    exit 0
}
catch {
    Write-Error "FAILED: $($_.Exception.Message)"
    Write-Error "This script must be run from an elevated (Run as administrator) PowerShell."
    exit 1
}
