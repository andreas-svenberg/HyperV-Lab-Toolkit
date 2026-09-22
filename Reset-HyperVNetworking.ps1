<#
    Reset-HyperVNetworking.ps1
    Diagnoses Hyper-V's virtual switches / NAT state on the host, and can
    optionally restart the relevant networking services, or force Windows
    to rebuild "Default Switch" from scratch.

    When to use: a VM gets "TTL exceeded" pinging out through Default
    Switch even after ruling out router/firewall config, MAC spoofing,
    and competing VPN/virtualization software, that pattern usually means
    Default Switch's own internal NAT state is corrupted on this specific
    host, not a config problem inside any VM.

    Usage:
        .\Reset-HyperVNetworking.ps1                     # diagnose only, changes nothing
        .\Reset-HyperVNetworking.ps1 -RestartServices     # diagnose + restart Hyper-V
                                                           # networking services.
                                                           # Safe, no VM data lost, but
                                                           # briefly interrupts network
                                                           # for ALL running VMs.
        .\Reset-HyperVNetworking.ps1 -ResetDefaultSwitch  # forces Windows to rebuild
                                                           # Default Switch on next
                                                           # restart. Shut down any VM
                                                           # connected to Default Switch
                                                           # first, asks for confirmation,
                                                           # requires a computer restart
                                                           # afterwards to take effect.
#>

param(
    [switch]$RestartServices,
    [switch]$ResetDefaultSwitch
)

Write-Host "`n=== 1. Current virtual switches ===" -ForegroundColor Cyan
Get-VMSwitch | Format-Table Name, SwitchType, NetAdapterInterfaceDescription -AutoSize

Write-Host "`n=== 2. NAT objects (Get-NetNat) ===" -ForegroundColor Cyan
Get-NetNat | Format-Table Name, InternalIPInterfaceAddressPrefix -AutoSize

Write-Host "`n=== 3. Hyper-V-related network adapters on the host ===" -ForegroundColor Cyan
Get-NetAdapter | Where-Object { $_.InterfaceDescription -match "Hyper-V" } |
    Format-Table Name, InterfaceDescription, Status, LinkSpeed -AutoSize

Write-Host "`n=== 4. VMs currently using Default Switch ===" -ForegroundColor Cyan
$vmsOnDefault = Get-VMNetworkAdapter -All | Where-Object { $_.SwitchName -eq "Default Switch" }
if ($vmsOnDefault) {
    $vmsOnDefault | Format-Table VMName, Name, SwitchName -AutoSize
} else {
    Write-Host "Inga VM kopplade mot Default Switch just nu." -ForegroundColor Green
}

if ($RestartServices) {
    Write-Host "`n=== 5. Startar om Hyper-V-nätverkstjänster ===" -ForegroundColor Cyan
    Write-Host "Påverkar inte VM:arnas data, men nätverket pausas kort för alla VM medan tjänsterna startar om." -ForegroundColor Yellow

    foreach ($svc in @("hns", "vmcompute")) {
        $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($service) {
            Write-Host "Startar om tjänsten $svc..." -ForegroundColor Yellow
            Restart-Service -Name $svc -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "Tjänsten $svc finns inte på den här datorn, hoppar över." -ForegroundColor DarkGray
        }
    }
    Write-Host "Klart. Testa pinga ut igen." -ForegroundColor Green
}

if ($ResetDefaultSwitch) {
    Write-Host "`n=== 6. Nollställer Default Switch ===" -ForegroundColor Red
    Write-Host "VARNING: Detta bygger om Default Switch helt. Alla VM som är kopplade mot" -ForegroundColor Red
    Write-Host "Default Switch måste kopplas om manuellt efteråt, och datorn behöver startas om." -ForegroundColor Red

    if ($vmsOnDefault) {
        Write-Host "`nFöljande VM är kopplade mot Default Switch just nu:" -ForegroundColor Yellow
        $vmsOnDefault | Format-Table VMName, Name -AutoSize
        Write-Host "Stäng av dessa VM innan du fortsätter." -ForegroundColor Yellow
    }

    $confirm = Read-Host "`nSkriv JA för att fortsätta, eller tryck Enter för att avbryta"
    if ($confirm -eq "JA") {
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\vmsmp\parameters"
        $newId = [guid]::NewGuid().ToString("B")
        Write-Host "Sätter nytt DefaultSwitchNetID: $newId" -ForegroundColor Yellow
        New-ItemProperty -Path $regPath -Name "DefaultSwitchNetID" -Value $newId -PropertyType String -Force | Out-Null
        Write-Host "Klart. Starta om datorn, Windows bygger då om Default Switch från grunden." -ForegroundColor Green
    } else {
        Write-Host "Avbrutet, inget ändrat." -ForegroundColor Green
    }
}
