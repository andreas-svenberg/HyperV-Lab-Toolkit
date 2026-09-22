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

## Krav

- Hyper-V-rollen installerad
- Körs som administratör
- Windows PowerShell 5.1 eller PowerShell 7

## Licens

Fritt att använda och anpassa.
