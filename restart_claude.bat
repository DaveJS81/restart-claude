@echo off
setlocal EnableExtensions

if /I "%~1"=="--cleanup" goto cleanup

echo WARNING: This will forcibly close Claude and every running Node, Python,
echo and Tail process. Unsaved work in those processes will be lost.
echo.
choice.exe /C YN /N /M "Continue? [Y/N] "
if errorlevel 2 exit /b 0
echo.

echo Requesting administrator access for cleanup...
set "RESTART_CLAUDE_SCRIPT=%~f0"
powershell.exe -NoProfile -Command "Start-Process -FilePath $env:RESTART_CLAUDE_SCRIPT -ArgumentList '--cleanup' -Verb RunAs -Wait"
if errorlevel 1 (
    echo Cleanup was cancelled or could not start.
    goto finish
)

echo.
echo Starting Claude...
powershell.exe -NoProfile -Command "$ErrorActionPreference = 'Stop'; try { $app = Get-StartApps | Where-Object { $_.Name -match '^Claude' -or $_.AppID -match '^Claude_' } | Select-Object -First 1; if ($app) { Start-Process explorer.exe -ArgumentList ('shell:AppsFolder\' + $app.AppID); exit 0 }; $pkg = Get-AppxPackage -Name Claude -ErrorAction SilentlyContinue | Select-Object -First 1; if ($pkg) { $manifest = Get-AppxPackageManifest $pkg; $id = $manifest.Package.Applications.Application.Id | Select-Object -First 1; Start-Process explorer.exe -ArgumentList ('shell:AppsFolder\' + $pkg.PackageFamilyName + '!' + $id); exit 0 }; $roots = @($env:LOCALAPPDATA + '\AnthropicClaude', $env:LOCALAPPDATA + '\Programs\Claude'); $exe = @(foreach ($root in $roots) { if (Test-Path $root) { Get-ChildItem $root -Filter Claude.exe -File -Recurse -ErrorAction SilentlyContinue } }) | Sort-Object LastWriteTime -Descending | Select-Object -First 1; if ($exe) { Start-Process -FilePath $exe.FullName; exit 0 }; exit 1 } catch { exit 1 }"

if errorlevel 1 (
    echo Claude could not be found automatically. Open it from the Start menu.
) else (
    echo Claude launch requested.
)
goto finish

:cleanup
echo Stopping the Claude Cowork VM service...
sc.exe stop CoworkVMService >nul 2>&1
timeout.exe /T 3 /NOBREAK >nul

echo Stopping all Claude and Cowork executables and their child processes...
taskkill /F /T /FI "IMAGENAME eq claude*.exe" /IM * >nul 2>&1
taskkill /F /T /FI "IMAGENAME eq cowork*.exe" /IM * >nul 2>&1

echo Stopping every Node, Python, and Tail process...
for /L %%R in (1,1,3) do (
    for %%P in (node.exe node_repl.exe nodejs.exe python.exe pythonw.exe python3.exe py.exe tail.exe) do (
        taskkill /F /T /IM %%P >nul 2>&1
    )
    timeout.exe /T 1 /NOBREAK >nul
)

timeout.exe /T 2 /NOBREAK >nul

echo.
echo Cleanup pass complete. Processes still visible after cleanup:
powershell.exe -NoProfile -Command "$names = 'claude','cowork-svc','node','node_repl','nodejs','python','pythonw','python3','py','tail'; Get-Process -Name $names -ErrorAction SilentlyContinue | Sort-Object ProcessName,Id | Format-Table Id,ProcessName -AutoSize"
exit /b 0

:finish
echo.
pause
endlocal
