# HyperV-Lab-Toolkit

Samling av PowerShell-script för felsökning och översikt i Hyper-V-labbmiljöer.

## Innehåll

### ListAllMyVMs.ps1

Listar alla VM på hosten i en tabell: Namn, Status, Antal CPU, Minne,
Minnestyp (Fast/Dynamic) och vSwitch-namn. Sorterar med ordinal (rå
teckenjämförelse) istället för Windows språkregler, så att namnkonventioner
som `PREFIX-1-` och `PREFIX-1B-` grupperas korrekt istället för att blandas
ihop.

Användning:

```
.\ListAllMyVMs.ps1
.\ListAllMyVMs.ps1 | Export-Csv -Path "C:\Temp\VM-list.csv" -NoTypeInformation -Delimiter ";"
```

### Test-NetworkLoop.ps1

Diagnostiserar (och kan valfritt åtgärda) TTL exceeded / routing-loop-problem
på en VM. Kollar nätverkskort, IP-konfiguration, default routes och kör en
traceroute som pekar ut var en eventuell loop sitter.

Användning:

```
.\Test-NetworkLoop.ps1          # bara diagnos, ändrar inget
.\Test-NetworkLoop.ps1 -Fix     # tar bort dubbla default routes,
                                 # frågar om bekräftelse först
```

### Reset-HyperVNetworking.ps1

Diagnostiserar Hyper-V's virtuella switchar och NAT-status på hosten, och kan
valfritt starta om nätverkstjänsterna eller tvinga Windows att bygga om
Default Switch från grunden. Används när ett fel (t.ex. TTL exceeded) kvarstår
oavsett vilken switch eller VM som testas, det pekar då på ett trasigt
nätverkstillstånd på själva hosten snarare än ett konfigurationsfel i en VM.

Användning:

```
.\Reset-HyperVNetworking.ps1                     # bara diagnos, ändrar inget
.\Reset-HyperVNetworking.ps1 -RestartServices     # startar om Hyper-V's nätverkstjänster,
                                                   # ofarligt, kort avbrott för alla VM
.\Reset-HyperVNetworking.ps1 -ResetDefaultSwitch  # tvingar Windows att bygga om Default
                                                   # Switch helt, kräver att alla VM på
                                                   # Default Switch är avstängda och att
                                                   # datorn startas om efteråt
```

## Krav

- Hyper-V-rollen installerad
- Körs som administratör
- Windows PowerShell 5.1 eller PowerShell 7

## Licens

Fritt att använda och anpassa.
