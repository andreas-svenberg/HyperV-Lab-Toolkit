<#
    Test-NetworkLoop.ps1
    Diagnoses (and optionally fixes) a TTL-exceeded / routing-loop problem
    on a Windows VM. Run as Administrator INSIDE the affected VM.

    What it checks:
      1. Active network adapters
      2. IP config per adapter, flags more than one Default Gateway set
      3. Default routes (0.0.0.0/0), flags duplicates
      4. Traceroute to 8.8.8.8, flags a repeated hop (the loop itself)

    Usage:
        .\Test-NetworkLoop.ps1          # diagnose only, changes nothing
        .\Test-NetworkLoop.ps1 -Fix     # diagnose, then remove duplicate
                                         # default routes (asks for
                                         # confirmation before each removal)
#>

param(
    [switch]$Fix
)

Write-Host "`n=== 1. Active network adapters ===" -ForegroundColor Cyan
$adapters = Get-NetAdapter | Where-Object Status -eq "Up"
$adapters | Format-Table Name, InterfaceDescription, MacAddress, LinkSpeed -AutoSize

Write-Host "`n=== 2. IP configuration per active adapter ===" -ForegroundColor Cyan
$ipConfigs = Get-NetIPConfiguration | Where-Object { $_.NetAdapter.Status -eq "Up" }
$ipConfigs | ForEach-Object {
    [PSCustomObject]@{
        Adapter = $_.InterfaceAlias
        IPv4    = ($_.IPv4Address.IPAddress -join ", ")
        Gateway = ($_.IPv4DefaultGateway.NextHop -join ", ")
        DNS     = ($_.DNSServer.ServerAddresses -join ", ")
    }
} | Format-Table -AutoSize

$gatewaysSet = $ipConfigs | Where-Object { $_.IPv4DefaultGateway }
if ($gatewaysSet.Count -gt 1) {
    Write-Host "VARNING: $($gatewaysSet.Count) nätverkskort har en Default Gateway satt samtidigt." -ForegroundColor Yellow
    Write-Host "Det är en vanlig orsak till routing-loopar, Windows kan välja fel väg ut." -ForegroundColor Yellow
}

Write-Host "`n=== 3. Default routes (0.0.0.0/0) ===" -ForegroundColor Cyan
$defaultRoutes = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue
$defaultRoutes | Sort-Object RouteMetric | Format-Table InterfaceAlias, NextHop, RouteMetric, ifIndex -AutoSize

if ($defaultRoutes.Count -gt 1) {
    Write-Host "VARNING: $($defaultRoutes.Count) default routes hittades." -ForegroundColor Yellow
    Write-Host "Flera vägar ut samtidigt är en klassisk orsak till en routing-loop / TTL exceeded." -ForegroundColor Yellow
}

Write-Host "`n=== 4. Traceroute mot 8.8.8.8 ===" -ForegroundColor Cyan
$trace = Test-NetConnection -ComputerName 8.8.8.8 -TraceRoute -WarningAction SilentlyContinue
$trace.TraceRoute | ForEach-Object { $_ }

$hopCounts = $trace.TraceRoute | Group-Object | Sort-Object Count -Descending
$loopHop = $hopCounts | Where-Object { $_.Count -gt 1 } | Select-Object -First 1
if ($loopHop) {
    Write-Host "LOOP HITTAD: $($loopHop.Name) förekommer $($loopHop.Count) gånger i traceroute-vägen." -ForegroundColor Red
} else {
    Write-Host "Ingen upprepad adress i traceroute-vägen." -ForegroundColor Green
    Write-Host "(Om felet är sporadiskt syns loopen inte alltid i ett enda test, prova ping igen om det uppstår.)" -ForegroundColor Green
}

if ($Fix) {
    Write-Host "`n=== 5. Åtgärda ===" -ForegroundColor Cyan

    if ($defaultRoutes.Count -gt 1) {
        # Keep the default route with the lowest RouteMetric, remove the rest.
        # -Confirm:$true means you get asked before each removal, nothing
        # happens silently.
        $keep = $defaultRoutes | Sort-Object RouteMetric | Select-Object -First 1
        $remove = $defaultRoutes | Where-Object { $_ -ne $keep }

        Write-Host "Behåller default route via $($keep.NextHop) ($($keep.InterfaceAlias))." -ForegroundColor Green
        foreach ($r in $remove) {
            Write-Host "Föreslår borttagning av default route via $($r.NextHop) ($($r.InterfaceAlias))..." -ForegroundColor Yellow
            Remove-NetRoute -DestinationPrefix "0.0.0.0/0" -NextHop $r.NextHop -InterfaceIndex $r.ifIndex -Confirm:$true
        }
    } else {
        Write-Host "Inga dubbla default routes att ta bort." -ForegroundColor Green
    }

    if ($gatewaysSet.Count -gt 1) {
        Write-Host "OBS: flera nätverkskort har en gateway satt. Det rör scriptet INTE automatiskt," -ForegroundColor Yellow
        Write-Host "eftersom det kan vara avsiktligt (t.ex. en router-VM som ska ha flera nät)." -ForegroundColor Yellow
        Write-Host "Stäng av eller koppla ur det kort som inte ska ha internetaccess, om det inte är tänkt att vara aktivt." -ForegroundColor Yellow
    }
}
