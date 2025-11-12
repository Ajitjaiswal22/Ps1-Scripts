# Ps1-Scripts
PowerShell scripts for Intune Managed Windows devices.

This repository contains Powershell scripts for Deploying printers automatically using .CSV file containing all the information of the printers.

[CmdletBinding()]
param(
    [string]$CsvPath = ".\Printers.csv",
    [switch]$Uninstall
)

$TagRoot = "C:\\ProgramData\\Company\\Printers"
$LogRoot = "C:\\ProgramData\\Company\\Logs\\Printers"
$TimeStamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")
$LogFile = Join-Path $LogRoot "Install-$TimeStamp.log"

New-Item -ItemType Directory -Path $TagRoot -Force | Out-Null
New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
Start-Transcript -Path $LogFile -Force | Out-Null

function Info($m){ Write-Host "[INFO] $m" }
function Install-Driver-INF { param([string]$InfPath)
    $full = Resolve-Path $InfPath -ErrorAction Stop
    Info "Installing driver from $($full.Path)"
    $p = Start-Process pnputil.exe -ArgumentList @('/add-driver',"`"$($full.Path)`"",'/install') -NoNewWindow -Wait -PassThru
    if ($p.ExitCode -ne 0) { Write-Warning "pnputil exit code $($p.ExitCode)" }
}
function Ensure-Port { param($PortName,$Address)
    if (-not (Get-PrinterPort -Name $PortName -ErrorAction SilentlyContinue)) {
        Info "Creating TCP/IP port $PortName -> $Address"
        Add-PrinterPort -Name $PortName -PrinterHostAddress $Address -ErrorAction Stop
    }
}
function Ensure-Printer { param($Name,$DriverName,$PortName)
    if (-not (Get-Printer -Name $Name -ErrorAction SilentlyContinue)) {
        Info "Adding printer $Name using driver '$DriverName' on $PortName"
        Add-Printer -Name $Name -DriverName $DriverName -PortName $PortName -ErrorAction Stop
    }
}
function Add-QueuePrinter { param($Name,$Conn)
    if (-not (Get-Printer -Name $Name -ErrorAction SilentlyContinue)) {
        Info "Connecting $Conn as $Name"
        Add-Printer -ConnectionName $Conn -Name $Name -ErrorAction Stop
    }
}
function Remove-PrinterSafe { param($Name)
    $p = Get-Printer -Name $Name -ErrorAction SilentlyContinue
    if ($p) { Info "Removing printer $Name"; Remove-Printer -Name $Name -ErrorAction SilentlyContinue }
}
function Remove-PortIfUnused { param($PortName)
    $inUse = Get-Printer | Where-Object { $_.PortName -eq $PortName }
    if (-not $inUse) { Info "Removing unused port $PortName"; Remove-PrinterPort -Name $PortName -ErrorAction SilentlyContinue }
}

if (-not (Test-Path $CsvPath)) { Write-Error "CSV not found: $CsvPath"; Stop-Transcript | Out-Null; exit 1 }
$rows = Import-Csv $CsvPath | Where-Object { $_.Name -and -not ($_.Name -like '#*') }

foreach ($r in $rows) {
    $name=$r.Name; $method=($r.Method).ToUpperInvariant()
    $queue=$r.QueueShare; $addr=$r.PortAddress; $port=$r.PortName
    $inf=$r.DriverInf; $drv=$r.DriverName
    $tag = Join-Path $TagRoot "$name.tag"

    if ($Uninstall) {
        Remove-PrinterSafe -Name $name
        if ($method -eq 'IP' -and $port) { Remove-PortIfUnused -PortName $port }
        if (Test-Path $tag) { Remove-Item $tag -Force }
        continue
    }

    try {
        if ($method -eq 'QUEUE') {
            if (-not $queue) { Write-Error "[$name] QueueShare missing"; continue }
            Add-QueuePrinter -Name $name -Conn $queue
        } elseif ($method -eq 'IP') {
            if (-not $addr -or -not $port) { Write-Error "[$name] PortAddress/PortName missing"; continue }
            if (-not $inf) { Write-Error "[$name] DriverInf missing"; continue }
            if (-not $drv) { Write-Error "[$name] DriverName missing"; continue }

            Install-Driver-INF -InfPath $inf
            Ensure-Port -PortName $port -Address $addr
            Ensure-Printer -Name $name -DriverName $drv -PortName $port
        } else {
            Write-Error "[$name] Unknown Method '$method'"; continue
        }

        if (-not (Test-Path $tag)) { New-Item -ItemType File -Path $tag -Force | Out-Null }
        Info "Completed $name"
    } catch {
        Write-Error "[$name] Error: $($_.Exception.Message)"
    }
}

Stop-Transcript | Out-Null
exit 0


