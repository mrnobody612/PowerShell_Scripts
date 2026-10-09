# Windows Endpoint Utility

Small PowerShell utility for Windows endpoint diagnostics and environment
collection.

## Overview

This repository contains a lightweight PowerShell script used to collect
basic endpoint information and perform a limited set of network diagnostics.

The script is intended to run without additional dependencies and is suitable
for controlled Windows environments.

## Features

- Host and user identification
- Endpoint execution timestamp
- File-system discovery for `.kdbx` files
- File metadata collection
- TCP connectivity checks
- HTTP-based result submission
- Lightweight TCP beaconing for connectivity testing

## Requirements

- Windows 10 / Windows 11
- PowerShell 5.1+
- Network connectivity to the configured collector
- Appropriate permissions for file-system enumeration

## Configuration

The destination server and network parameters are defined directly in the
PowerShell script.

Example:

```powershell
$srv = "IP"
$beaconPort = port
$httpPort = 8080
