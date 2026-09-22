<#
    ListAllMyVMs.ps1
    Lists all VMs on the host in a table: Name, Status, CPU count, Memory,
    Memory type (Fixed/Dynamic) and vSwitch name.

    Sorted using ORDINAL (raw character) comparison instead of the default
    culture-aware comparison that Sort-Object normally uses.

    Why this matters: Windows' default linguistic string comparison treats
    a hyphen ("-") as a low-weight, near-ignorable character. That means a
    name like "MOV26-38-AD01" and "MOV26-38B-AD01" don't sort the way you'd
    expect from looking at the prefix, the comparison effectively skips the
    hyphen and compares "38AD01" against "38BAD01" character by character,
    which interleaves the "38-" and "38B-" batches instead of keeping them
    as two separate, grouped blocks. This is also why Hyper-V Manager's own
    VM list shows the same odd grouping, it uses the same kind of
    culture-aware comparison. Ordinal comparison treats "-" as a real
    character with its own fixed value, so all "38-..." names sort before
    all "38B-..." names, giving the grouping you actually intended with
    the naming convention.

    Usage:
        .\ListAllMyVMs.ps1
        .\ListAllMyVMs.ps1 | Export-Csv -Path "C:\Temp\VM-list.csv" -NoTypeInformation -Delimiter ";"
#>

$results = Get-VM | ForEach-Object {

    $vm = $_

    # Collect vSwitch name(s) from all network adapters on this VM
    $vSwitchName = (Get-VMNetworkAdapter -VM $vm | Select-Object -ExpandProperty SwitchName) -join ", "
    if (-not $vSwitchName) { $vSwitchName = "(no network adapter)" }

    [PSCustomObject]@{
        Namn      = $vm.Name
        Status    = $vm.State
        AntalCPU  = $vm.ProcessorCount
        Minne     = "{0} MB" -f [math]::Round($vm.MemoryStartup / 1MB)
        Minnestyp = if ($vm.DynamicMemoryEnabled) { "Dynamic" } else { "Fast" }
        vSwitch   = $vSwitchName
    }
}

# Sort with ordinal (case-insensitive) comparison so hyphens are treated as
# real characters instead of being skipped by the default culture comparer.
$sorted = [System.Collections.Generic.List[psobject]]::new()
$results | ForEach-Object { $sorted.Add($_) }
$sorted.Sort([Comparison[psobject]]{
    param($a, $b)
    [System.StringComparer]::OrdinalIgnoreCase.Compare($a.Namn, $b.Namn)
})

$sorted | Format-Table -AutoSize
