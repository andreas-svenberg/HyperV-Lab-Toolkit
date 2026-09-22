# Samla-HyperV-Info.ps1
# Läsonly script - gör inga ändringar i systemet.
# Samlar ihop switch-, VM- och nätverkskonfiguration inför en av/på-cykel av Hyper-V,
# så att du har allt dokumenterat om något inte kommer tillbaka automatiskt.
#
# Kör i ett vanligt PowerShell-fönster (admin rekommenderas för fullständig info):
#   .\Samla-HyperV-Info.ps1

$stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$outDir  = "C:\Hyper-V\Backup-Info"
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$outFile = Join-Path $outDir "HyperV-Backup-Info_$stamp.txt"
$jsonFile = Join-Path $outDir "HyperV-Backup-Info_$stamp.json"

function Skriv($rubrik) {
    "`n=== $rubrik ===" | Out-File $outFile -Append -Encoding utf8
}

"HYPER-V KONFIGURATIONSSNAPSHOT" | Out-File $outFile -Encoding utf8
"Genererad: $(Get-Date)" | Out-File $outFile -Append -Encoding utf8

$data = [ordered]@{}

# --- Host-standardvägar ---
Skriv "VM HOST STANDARDVÄGAR"
$hostInfo = Get-VMHost | Select-Object VirtualHardDiskPath, VirtualMachinePath
$hostInfo | Format-List | Out-File $outFile -Append -Encoding utf8
$data.VMHost = $hostInfo

# --- Virtuella switchar ---
Skriv "VIRTUELLA SWITCHAR"
$switches = Get-VMSwitch | Select-Object Name, SwitchType, NetAdapterInterfaceDescription, Id, AllowManagementOS
$switches | Format-Table -AutoSize | Out-File $outFile -Append -Encoding utf8
$data.Switches = $switches

# --- Host vEthernet-adaptrar + IP-konfig (viktigt för interna/privata switchar, t.ex. pfSense-LAN) ---
Skriv "HOST vEthernet-ADAPTRAR OCH IP-KONFIG"
$vEthAdapters = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*Hyper-V Virtual Ethernet*" }
$ipData = foreach ($a in $vEthAdapters) {
    $ips = Get-NetIPAddress -InterfaceIndex $a.ifIndex -ErrorAction SilentlyContinue |
        Select-Object AddressFamily, IPAddress, PrefixLength
    [pscustomobject]@{
        AdapterName = $a.Name
        InterfaceDescription = $a.InterfaceDescription
        Status = $a.Status
        IPAddresses = $ips
    }
}
foreach ($item in $ipData) {
    "Adapter: $($item.AdapterName)  ($($item.InterfaceDescription))  Status: $($item.Status)" | Out-File $outFile -Append -Encoding utf8
    $item.IPAddresses | Format-Table -AutoSize | Out-File $outFile -Append -Encoding utf8
}
$data.HostVEthernetAdapters = $ipData

# --- Virtuella datorer ---
Skriv "VIRTUELLA DATORER"
$vms = Get-VM | Select-Object Name, State, Generation, Version, Path, ConfigurationLocation, AutomaticStartAction, AutomaticStopAction
$vms | Format-List | Out-File $outFile -Append -Encoding utf8
$data.VMs = $vms

# --- VM-nätverkskort: switch-koppling, MAC, VLAN ---
Skriv "VM-NÄTVERKSKORT (switch, MAC, VLAN)"
$vmNics = foreach ($vm in Get-VM) {
    $nics = Get-VMNetworkAdapter -VMName $vm.Name
    foreach ($nic in $nics) {
        $vlan = Get-VMNetworkAdapterVlan -VMName $vm.Name -VMNetworkAdapterName $nic.Name -ErrorAction SilentlyContinue
        [pscustomobject]@{
            VM = $vm.Name
            NIC = $nic.Name
            SwitchName = $nic.SwitchName
            MacAddress = $nic.MacAddress
            DynamicMac = $nic.DynamicMacAddressEnabled
            VlanMode = $vlan.OperationMode
            VlanId = $vlan.AccessVlanId
        }
    }
}
$vmNics | Format-Table -AutoSize | Out-File $outFile -Append -Encoding utf8
$data.VMNetworkAdapters = $vmNics

# --- Checkpoints/snapshots ---
Skriv "CHECKPOINTS / SNAPSHOTS"
$snaps = foreach ($vm in Get-VM) {
    Get-VMSnapshot -VMName $vm.Name -ErrorAction SilentlyContinue |
        Select-Object VMName, Name, CreationTime, ParentSnapshotName
}
if ($snaps) { $snaps | Format-Table -AutoSize | Out-File $outFile -Append -Encoding utf8 }
else { "Inga checkpoints hittades." | Out-File $outFile -Append -Encoding utf8 }
$data.Snapshots = $snaps

# --- Virtuella hårddiskar per VM ---
Skriv "VIRTUELLA HÅRDDISKAR PER VM"
$vhds = foreach ($vm in Get-VM) {
    Get-VMHardDiskDrive -VMName $vm.Name |
        Select-Object VMName, Path, ControllerType, ControllerNumber, ControllerLocation
}
$vhds | Format-Table -AutoSize | Out-File $outFile -Append -Encoding utf8
$data.HardDiskDrives = $vhds

# --- Spara även som JSON för enkel maskinell återställning senare ---
$data | ConvertTo-Json -Depth 6 | Out-File $jsonFile -Encoding utf8

Write-Host "Klart!"
Write-Host "Textrapport: $outFile"
Write-Host "JSON-data:   $jsonFile"
Invoke-Item $outFile