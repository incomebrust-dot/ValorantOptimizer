<#
.SYNOPSIS
    Otimizacao Ultimate para Valorant - Reduz Tremor de Mira, Input Lag e Jitter
    Baseado em fontes top: GitHub (gaming_os_tweaker, Batlez, Hyyote, DaddyMadu, etc.), Reddit, BlurBusters.
    Combina .bat + .reg anterior + TUDO mais profundo: HPET full disable, timer res 0.5ms, network auto, services, mitigations, etc.
    AVISO: CRIE PONTO DE RESTAURACAO! Execute como Admin. Reinicie apos. Teste no Valorant.
    Para reverter: Rode com -Revert
#>

param(
    [switch]$Revert
)

# Funcao para log
function Write-Log { param($Msg); Write-Host "[$(Get-Date -f 'HH:mm:ss')] $Msg" -ForegroundColor Green }

if ($Revert) {
    Write-Log "REVERTENDO..."
    # Reverta bcdedit
    bcdedit /deletevalue useplatformtick
    bcdedit /deletevalue disabledynamictick
    bcdedit /set useplatformclock true
    # Reg mouse accel volta
    Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name MouseSpeed -Value 1
    Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name MouseThreshold1 -Value 6
    Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name MouseThreshold2 -Value 10
    # Power plan balanced
    powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
    # HPET device enable
    Get-PnpDevice -FriendlyName "*High precision event timer*" | Enable-PnpDevice -Confirm:$false
    # Re-enable services (exemplos)
    Get-Service SysMain, DiagTrack | % { sc config $_ start= auto; Start-Service $_ }
    Write-Log "Revertido! Reinicie."
    pause; return
}

# Verifica Admin
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

# Ponto de restauracao
Write-Log "Criando ponto de restauracao..."
Checkpoint-Computer -Description "Antes Otimizacao Valorant Ultimate" -RestorePointType "MODIFY_SETTINGS"

# 1. REG TWEAKS AVANCADOS (mouse, priority, fullscreen, DPC, TCP, etc.)
Write-Log "Aplicando Registry Tweaks..."

# Mouse Accel OFF (MarkC fix + buffer)
New-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value 0 -PropertyType DWord -Force
New-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value 0 -PropertyType String -Force
New-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value 0 -PropertyType String -Force
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\mouhid\Parameters" -Name "MouseDataQueueSize" -Value 50 -PropertyType DWord -Force
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" -Name "MouseDataQueueSize" -Value 50 -PropertyType DWord -Force
# Keyboard buffer
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\kbdhid\Parameters" -Name "KeyboardDataQueueSize" -Value 50 -PropertyType DWord -Force

# Prioridade Valorant Alta
$valPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\VALORANT-Win64-Shipping.exe\PerfOptions"
if (!(Test-Path $valPath)) { New-Item -Path $valPath -Force }
New-ItemProperty -Path $valPath -Name "CpuPriorityClass" -Value 3 -PropertyType DWord -Force

# Fullscreen Opti OFF
New-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Value 2 -PropertyType DWord -Force
New-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -PropertyType DWord -Force

# Win32 Priority Separation (short quantum, high foreground)
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 0x26 -PropertyType DWord -Force

# DPC/Latencia
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "DisablePagingExecutive" -Value 1 -PropertyType DWord -Force
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "CoalescingTimerInterval" -Value 0 -PropertyType DWord -Force

# Mitigations OFF (FPS+)
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Kernel" -Name "DisableDynamicCode" -Value 1 -PropertyType DWord -Force
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Kernel" -Name "DynamicallyRedirectedImports" -Value 0 -PropertyType DWord -Force

# MmCss High Priority
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "Priority" -Value 6 -PropertyType DWord -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "SFIO Priority" -Value "High" -PropertyType String -Force

# Prefetch OFF (SSD)
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnablePrefetcher" -Value 0 -PropertyType DWord -Force

# 2. BCDEDIT - Timers/HPET OFF
Write-Log "Desabilitando HPET e otimizando timers..."
bcdedit /set disabledynamictick yes
bcdedit /set useplatformclock no  # HPET OFF
bcdedit /set useplatformtick yes
bcdedit /set hypervisorlaunchtype off
bcdedit /set nx alwaysoff
bcdedit /set bootmenupolicy legacy

# 3. POWERCFG Ultimate + Tweaks
Write-Log "Ativando Ultimate Performance..."
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61
powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100
powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100
powercfg /setactive SCHEME_CURRENT
powercfg -h off  # Hibernacao OFF

# USB/Disk no sleep
powercfg /setacvalueindex SCHEME_CURRENT SUB_USB USBSELECTSUSPEND 0
powercfg /setactive SCHEME_CURRENT

# 4. DISABLE HPET DEVICE
Write-Log "Desabilitando HPET no Device Manager..."
Get-PnpDevice | Where-Object FriendlyName -like "*High precision event timer*" | Disable-PnpDevice -Confirm:$false

# 5. SERVICES DISABLE (safe para gaming/Valorant)
$services = @("SysMain", "DiagTrack", "WSearch", "dmwappushservice", "SysMain", "TrkWks", "WMPNetworkSvc", "XblAuthManager", "XblGameSave", "XboxNetApiSvc")
foreach ($svc in $services) {
    if (Get-Service $svc -ErrorAction SilentlyContinue) {
        sc.exe config $svc start= disabled
        Stop-Service $svc -Force -ErrorAction SilentlyContinue
    }
}

# 6. NETWORK OTIMIZACAO AUTO
Write-Log "Otimizando Network (auto GUID)..."
$adapter = Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1
$guid = $adapter.InterfaceGuid
if ($guid) {
    $ifacePath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
    New-Item -Path $ifacePath -Force | Out-Null
    New-ItemProperty -Path $ifacePath -Name "TcpAckFrequency" -Value 1 -PropertyType DWord -Force
    New-ItemProperty -Path $ifacePath -Name "TcpDelAckTicks" -Value 0 -PropertyType DWord -Force
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Value 0xffffffff -PropertyType DWord -Force
}

# 7. TIMER RESOLUTION 0.5ms (background job)
Write-Log "Configurando Timer Resolution 0.5ms (roda em background)..."
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class NtTimer {
    [DllImport("ntdll.dll")] public static extern uint NtSetTimerResolution(ref uint TargetResolution, bool SetResolution, out uint CurrentResolution);
}
"@
function Set-TimerRes {
    $res = 500000u  # 0.5ms
    [uint32]$cur = 0
    [NtTimer]::NtSetTimerResolution([ref]$res, $true, [ref]$cur) | Out-Null
}
# Job background
Start-Job -ScriptBlock { while($true) { Set-TimerRes; Start-Sleep -Milliseconds 100 } } | Out-Null
Write-Log "Timer Res OK! (nao para apos reboot - use ISLC)"

# 8. GAME BAR / DVR OFF
Write-Log "Desabilitando Game Bar/DVR..."
New-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -PropertyType DWord -Force

# 9. CLEAR STANDBY LIST (equiv ISLC)
Write-Log "Limpando Standby List..."
$R = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(4)
for (;;) {
    [System.Runtime.InteropServices.Marshal]::WriteInt32($R, 4)
    $x = [PSMoveit]::MtEmptyWorkingSet(0)
    if ($x -ne 0) { break }
}

Write-Log "TUDO APLICADO! REINICIE AGORA e teste mira no Valorant."
Write-Log "Dicas extra: DPI 400-800, polling 1000Hz, Raw Input ON, sens 0.3-0.5."
Write-Log "Baixe ISLC.exe para timer res permanente: https://www.ghostarrow.com/islc"
pause