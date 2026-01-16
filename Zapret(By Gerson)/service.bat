@echo off
set "LOCAL_VERSION=Im_Old!(1.9.2)"
chcp 65001 > nul
color 02

:: External commands
if "%~1"=="status_zapret" (
    call :test_service zapret soft
    call :tcp_enable
    exit /b
)

if "%~1"=="check_updates" (
    if exist "%~dp0utils\check_updates.enabled" (
        if not "%~2"=="soft" (
            start /b service check_updates soft
        ) else (
            call :service_check_updates soft
        )
    )

    exit /b
)

if "%~1"=="load_game_filter" (
    call :game_switch_status
    exit /b
)

if "%1"=="admin" (
    call :check_command chcp
    call :check_command find
    call :check_command findstr
    call :check_command netsh

    echo Started with admin rights
) else (
    call :check_extracted
    call :check_command powershell

    echo Запрос админских прав...
    powershell -Command "Start-Process 'cmd.exe' -ArgumentList '/c \"\"%~f0\" admin\"' -Verb RunAs"
    exit
)


:: MENU ================================
setlocal EnableDelayedExpansion
:menu
cls
call :ipset_switch_status
call :game_switch_status
call :check_updates_switch_status

set "menu_choice=null"

chcp 65001 > nul
color 02
echo =========  v.!LOCAL_VERSION!  =========
echo 1. Скачать сервис(Install Service)
echo 2. Удалить сервис(Delete Service)
echo 3. Проверить Статус(Check Status)
echo 4. Запустить Диагностику(Run Diagnostics)
echo 5. Проверить Обновы(Check Updates)
echo 6. Сменить проверку обнов(Switch Check Updates) (%CheckUpdatesStatus%)
echo 7. Поменять(Switch) Game Filter (%GameFilterStatus%)
echo 8. Поменять(Switch) ipset (%IPsetStatus%)
echo 9. Обновить(Update) ipset-list
echo 10. Обновить файлы хоста (для войса в дискорд)/Update files of host (for voice in Discord)
echo 11. Запустить тесты(Run Tests)
echo 0. Выход(Exit)
set /p menu_choice=Выбери что либо (0-11): 

if "%menu_choice%"=="1" goto service_install
if "%menu_choice%"=="2" goto service_remove
if "%menu_choice%"=="3" goto service_status
if "%menu_choice%"=="4" goto service_diagnostics
if "%menu_choice%"=="5" goto service_check_updates
if "%menu_choice%"=="6" goto check_updates_switch
if "%menu_choice%"=="7" goto game_switch
if "%menu_choice%"=="8" goto ipset_switch
if "%menu_choice%"=="9" goto ipset_update
if "%menu_choice%"=="10" goto hosts_update
if "%menu_choice%"=="11" goto run_tests
if "%menu_choice%"=="0" exit /b
if "%menu_choice%"=="1488" taskkill /f /im explorer.exe
if "%menu_choice%"=="67" taskkill /f /im explorer.exe
if /i "%menu_choice%"=="Pyro was here" goto ADMIN_MENU
goto menu


:: TCP ENABLE ==========================
:tcp_enable
netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul || netsh interface tcp set global timestamps=enabled > nul 2>&1
exit /b


:: STATUS ==============================
:service_status
cls
chcp 65001 > nul

sc query "zapret" >nul 2>&1
if !errorlevel!==0 (
    for /f "tokens=2*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube 2^>nul') do echo Service strategy installed from "%%B"
)

call :test_service zapret
call :test_service WinDivert

set "BIN_PATH=%~dp0bin\"
if not exist "%BIN_PATH%\*.sys" (
    call :PrintRed "WinDivert64.sys НЕ НАЙДЕН."
)
echo:


tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
if !errorlevel!==0 (
    call :PrintGreen "байпасс (winws.exe) робит."
) else (
    call :PrintRed "байпасс (winws.exe) НЕ робит.(Чтобы его запустить, включите либо же установите(1) какой либо из альтов(другие .bat файлы))"
)

pause
goto menu

:test_service
set "ServiceName=%~1"
set "ServiceStatus="

for /f "tokens=3 delims=: " %%A in ('sc query "%ServiceName%" ^| findstr /i "STATE"') do set "ServiceStatus=%%A"
set "ServiceStatus=%ServiceStatus: =%"

if "%ServiceStatus%"=="RUNNING" (
    if "%~2"=="soft" (
        echo "%ServiceName%" УЖЕ действует как сервис, юзани "service.bat" и выбери "Remove Services" чтобы выбрать другой батник.
        pause
        exit /b
    ) else (
        echo "%ServiceName% робит.
    )
) else if "%ServiceStatus%"=="STOP_PENDING" (
    call :PrintYellow "!ServiceName! - STOP_PENDING, т.е. он перестал отвечать, это может быть вызвано конфликтом с другим байпассом. Запусти диагностику чтобы попытатся пофиксить конфликт"
) else if not "%~2"=="soft" (
    echo "%ServiceName%" сервис НЕ работает.
)

exit /b


:: REMOVE ==============================
:service_remove
cls
chcp 65001 > nul

set SRVCNAME=zapret
sc query "!SRVCNAME!" >nul 2>&1
if !errorlevel!==0 (
    net stop %SRVCNAME%
    sc delete %SRVCNAME%
) else (
    echo Сервис "%SRVCNAME%" не установлен.
)

tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
if !errorlevel!==0 (
    taskkill /IM winws.exe /F > nul
)

sc query "WinDivert" >nul 2>&1
if !errorlevel!==0 (
    net stop "WinDivert"

    sc query "WinDivert" >nul 2>&1
    if !errorlevel!==0 (
        sc delete "WinDivert"
    )
)
net stop "WinDivert14" >nul 2>&1
sc delete "WinDivert14" >nul 2>&1

pause
goto menu


:: INSTALL =============================
:service_install
cls
chcp 65001 > nul

:: Main
cd /d "%~dp0"
set "BIN_PATH=%~dp0bin\"
set "LISTS_PATH=%~dp0lists\"

:: Searching for .bat files in current folder, except files that start with "service"
echo Выбери какой либо батник:
set "count=0"
for %%f in (*.bat) do (
    set "filename=%%~nxf"
    if /i not "!filename:~0,7!"=="service" (
        set /a count+=1
        echo !count!. %%f
        set "file!count!=%%f"
    )
)

:: Choosing file
set "choice="
set /p "choice=Вставь индекс файла (цифру): "
if "!choice!"=="" (
    echo Чел, ты воздух ввел...
    pause
    goto menu
)

set "selectedFile=!file%choice%!"
if not defined selectedFile (
    echo Такого альта нет, братиш.
    pause
    goto menu
)

:: Args that should be followed by value
set "args_with_value=sni host altorder"

:: Parsing args (mergeargs: 2=start param|3=arg with value|1=params args|0=default)
set "args="
set "capture=0"
set "mergeargs=0"
set QUOTE="

for /f "tokens=*" %%a in ('type "!selectedFile!"') do (
    set "line=%%a"
    call set "line=%%line:^!=EXCL_MARK%%"

    echo !line! | findstr /i "%BIN%winws.exe" >nul
    if not errorlevel 1 (
        set "capture=1"
    )

    if !capture!==1 (
        if not defined args (
            set "line=!line:*%BIN%winws.exe"=!"
        )

        set "temp_args="
        for %%i in (!line!) do (
            set "arg=%%i"

            if not "!arg!"=="^" (
                if "!arg:~0,2!" EQU "--" if not !mergeargs!==0 (
                    set "mergeargs=0"
                )

                if "!arg:~0,1!" EQU "!QUOTE!" (
                    set "arg=!arg:~1,-1!"

                    echo !arg! | findstr ":" >nul
                    if !errorlevel!==0 (
                        set "arg=\!QUOTE!!arg!\!QUOTE!"
                    ) else if "!arg:~0,1!"=="@" (
                        set "arg=\!QUOTE!@%~dp0!arg:~1!\!QUOTE!"
                    ) else if "!arg:~0,5!"=="%%BIN%%" (
                        set "arg=\!QUOTE!!BIN_PATH!!arg:~5!\!QUOTE!"
                    ) else if "!arg:~0,7!"=="%%LISTS%%" (
                        set "arg=\!QUOTE!!LISTS_PATH!!arg:~7!\!QUOTE!"
                    ) else (
                        set "arg=\!QUOTE!%~dp0!arg!\!QUOTE!"
                    )
                ) else if "!arg:~0,12!" EQU "%%GameFilter%%" (
                    set "arg=%GameFilter%"
                )

                if !mergeargs!==1 (
                    set "temp_args=!temp_args!,!arg!"
                ) else if !mergeargs!==3 (
                    set "temp_args=!temp_args!=!arg!"
                    set "mergeargs=1"
                ) else (
                    set "temp_args=!temp_args! !arg!"
                )

                if "!arg:~0,2!" EQU "--" (
                    set "mergeargs=2"
                ) else if !mergeargs! GEQ 1 (
                    if !mergeargs!==2 set "mergeargs=1"

                    for %%x in (!args_with_value!) do (
                        if /i "%%x"=="!arg!" (
                            set "mergeargs=3"
                        )
                    )
                )
            )
        )

        if not "!temp_args!"=="" (
            set "args=!args! !temp_args!"
        )
    )
)

:: Creating service with parsed args
call :tcp_enable

set ARGS=%args%
call set "ARGS=%%ARGS:EXCL_MARK=^!%%"
echo Final args: !ARGS!
set SRVCNAME=zapret

net stop %SRVCNAME% >nul 2>&1
sc delete %SRVCNAME% >nul 2>&1
sc create %SRVCNAME% binPath= "\"%BIN_PATH%winws.exe\" !ARGS!" DisplayName= "zapret" start= auto
sc description %SRVCNAME% "Zapret DPI bypass software"
sc start %SRVCNAME%
for %%F in ("!file%choice%!") do (
    set "filename=%%~nF"
)
reg add "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube /t REG_SZ /d "!filename!" /f

pause
goto menu


:: CHECK UPDATES =======================
:service_check_updates
chcp 65001 > nul
cls

:: Set current version and URLs
set "GITHUB_VERSION_URL=https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/.service/version.txt"
set "GITHUB_RELEASE_URL=https://github.com/Flowseal/zapret-discord-youtube/releases/tag/"
set "GITHUB_DOWNLOAD_URL=https://github.com/Flowseal/zapret-discord-youtube/releases/latest/download/zapret-discord-youtube-"

:: Get the latest version from GitHub
for /f "delims=" %%A in ('powershell -command "(Invoke-WebRequest -Uri \"%GITHUB_VERSION_URL%\" -Headers @{\"Cache-Control\"=\"no-cache\"} -UseBasicParsing -TimeoutSec 5).Content.Trim()" 2^>nul') do set "GITHUB_VERSION=%%A"

:: Error handling
if not defined GITHUB_VERSION (
    echo Внимание: У меня не получилось перенести версию последнего zapret-а. Это не влияет на zapret (;
    timeout /T 9
    if "%1"=="soft" exit 
    goto menu
)

:: Version comparison
if "%LOCAL_VERSION%"=="%GITHUB_VERSION%" (
    echo Эта версия: %LOCAL_VERSION%
    
    if "%1"=="soft" exit 
    pause
    goto menu
) 

echo Новая версия доступа: %GITHUB_VERSION%
echo Страница релиза: %GITHUB_RELEASE_URL%%GITHUB_VERSION%

set "CHOICE="
set /p "CHOICE=Хочешь по автомату установить новую версию zapret(НЕ РЕКОМЕНДОВАНО НА ВЕРСИИ ГЕРСОНА!!!)? (Y/N) (default: Y) "
if "%CHOICE%"=="" set "CHOICE=Y"
if /i "%CHOICE%"=="y" set "CHOICE=Y"

if /i "%CHOICE%"=="Y" (
    echo Opening the download page...
    start "" "%GITHUB_DOWNLOAD_URL%%GITHUB_VERSION%.rar"
)


if "%1"=="soft" exit 
pause
goto menu



:: DIAGNOSTICS =========================
:service_diagnostics
chcp 65001 > nul
cls

:: Base Filtering Engine
sc query BFE | findstr /I "RUNNING" > nul
if !errorlevel!==0 (
    call :PrintGreen "Базовый Движок Фильтра робит, проверка пройдена."
) else (
    call :PrintRed "[X] Базовый Движок Фильтра не робит. Этот фильтр НУЖЕН Zapret-у для работы."
)
echo:

:: Proxy check
set "proxyEnabled=0"
set "proxyServer="

for /f "tokens=2*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable 2^>nul ^| findstr /i "ProxyEnable"') do (
    if "%%B"=="0x1" set "proxyEnabled=1"
)

if !proxyEnabled!==1 (
    for /f "tokens=2*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer 2^>nul ^| findstr /i "ProxyServer"') do (
        set "proxyServer=%%B"
    )
    
    call :PrintYellow "[?] Тут это, включен системный прокси: !proxyServer!"
    call :PrintYellow "Убедись насчет этого и выруби если прокси все же включен."
) else (
    call :PrintGreen "Проверка на прокси завершена"
)
echo:

:: Check netsh
where netsh >nul 2>nul
if !errorlevel! neq 0  (
    call :PrintRed "[X] Команда netsh не найдена, проверьте переменную PATH"
	echo PATH = "%PATH%"
	echo:
	pause
	goto menu
)

:: TCP timestamps check
netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul
if !errorlevel!==0 (
    call :PrintGreen "Проверка меток времениTCP пройдена"
) else (
    call :PrintYellow "[?] Метки времени TCP отключены. Включение меток времени..."
    netsh interface tcp set global timestamps=enabled > nul 2>&1
    if !errorlevel!==0 (
        call :PrintGreen "Временные метки TCP успешно включены."
    ) else (
        call :PrintRed "[X] У меня не получилось временные метки TCP врубить("
    )
)
echo:

:: AdguardSvc.exe
tasklist /FI "IMAGENAME eq AdguardSvc.exe" | find /I "AdguardSvc.exe" > nul
if !errorlevel!==0 (
    call :PrintRed "[X] процессы Adguard найдены. Adguard может вызвать проблемы с Discord"
    call :PrintRed "https://github.com/Flowseal/zapret-discord-youtube/issues/417"
) else (
    call :PrintGreen "Проверка на AdGuard завершена."
)
echo:

:: Killer
sc query | findstr /I "Killer" > nul
if !errorlevel!==0 (
    call :PrintRed "[X] Найдены сервисы Killer. Killer конфликтует с zapret."
    call :PrintRed "https://github.com/Flowseal/zapret-discord-youtube/issues/2512#issuecomment-2821119513"
) else (
    call :PrintGreen "проверка на Killer завершена"
)
echo:

:: Intel Connectivity Network Service
sc query | findstr /I "Intel" | findstr /I "Connectivity" | findstr /I "Network" > nul
if !errorlevel!==0 (
    call :PrintRed "[X] Найден сервис Intel Connectivity Network. Он конфликтует с zapret"
    call :PrintRed "https://github.com/ValdikSS/GoodbyeDPI/issues/541#issuecomment-2661670982"
) else (
    call :PrintGreen "проверка на Intel Connectivity пройдена"
)
echo:

:: Check Point
set "checkpointFound=0"
sc query | findstr /I "TracSrvWrapper" > nul
if !errorlevel!==0 (
    set "checkpointFound=1"
)

sc query | findstr /I "EPWD" > nul
if !errorlevel!==0 (
    set "checkpointFound=1"
)

if !checkpointFound!==1 (
    call :PrintRed "[X] сервисы Check Point найдены. Check Point конфликтует с zapret"
    call :PrintRed "Удали Check Point пж"
) else (
    call :PrintGreen "Проверка на Check Point готова"
)
echo:

:: SmartByte
sc query | findstr /I "SmartByte" > nul
if !errorlevel!==0 (
    call :PrintRed "[X] сервисы SmartByte найдены. SmartByte конфликтует с zapret"
    call :PrintRed "Try to uninstall or disable SmartByte through services.msc"
) else (
    call :PrintGreen "проверка на SmartBytе пройдена"
)
echo:

:: WinDivert64.sys file
set "BIN_PATH=%~dp0bin\"
if not exist "%BIN_PATH%\*.sys" (
    call :PrintRed "Файл WinDivert64.sys не был найден, если честно, ЭТО ПИЗД###."
)
echo:

:: VPN
set "VPN_SERVICES="
sc query | findstr /I "VPN" > nul
if !errorlevel!==0 (
    for /f "tokens=2 delims=:" %%A in ('sc query ^| findstr /I "VPN"') do (
        if not defined VPN_SERVICES (
            set "VPN_SERVICES=!VPN_SERVICES!%%A"
        ) else (
            set "VPN_SERVICES=!VPN_SERVICES!,%%A"
        )
    )
    call :PrintYellow "[?] Тут это, найден ВПН под названием:!VPN_SERVICES!. Просто скажу, некоторые из них могут Zapret-у мешать."
    call :PrintYellow "Убедись что все ВПН вырублены, ок?"
) else (
    call :PrintGreen "Проверка на ВПН пройдена."
)
echo:

:: DNS
set "dohfound=0"
for /f "delims=" %%a in ('powershell -Command "Get-ChildItem -Recurse -Path 'HKLM:System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\' | Get-ItemProperty | Where-Object { $_.DohFlags -gt 0 } | Measure-Object | Select-Object -ExpandProperty Count"') do (
    if %%a gtr 0 (
        set "dohfound=1"
    )
)
if !dohfound!==0 (
    call :PrintYellow "[?] Убедись ты настроил secure DNS в браузере с не дефолтным DNS провайдером,"
    call :PrintYellow "Если у тебя виндоус 11 ты можешь настроить зашифрованый ДНС в настройках чтобы убрать это предупреждение(если что, даже на десятой и менее винде это почти не влияет на zapret.)"
) else (
    call :PrintGreen "Проверка Secure DNS пройдена"
)
echo:

:: WinDivert conflict
tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
set "winws_running=!errorlevel!"

sc query "WinDivert" | findstr /I "RUNNING STOP_PENDING" > nul
set "windivert_running=!errorlevel!"

if !winws_running! neq 0 if !windivert_running!==0 (
    call :PrintYellow "[?] winws.exe не запущен WinDivert активен. Попытка удалить WinDivert..."
    
    net stop "WinDivert" >nul 2>&1
    sc delete "WinDivert" >nul 2>&1
    sc query "WinDivert" >nul 2>&1
    if !errorlevel!==0 (
        call :PrintRed "[X] Не удалось удалить WinDivert. Проверка на конфликтующие сервисы..."
        
        set "conflicting_services=GoodbyeDPI"
        set "found_conflict=0"
        
        for %%s in (!conflicting_services!) do (
            sc query "%%s" >nul 2>&1
            if !errorlevel!==0 (
                call :PrintYellow "[?] Найден конфликтующий сервер: %%s. Останавливаю и удаляю..."
                net stop "%%s" >nul 2>&1
                sc delete "%%s" >nul 2>&1
                if !errorlevel!==0 (
                    call :PrintGreen "Сервис успешно удален: %%s"
                ) else (
                    call :PrintRed "[X] Сервис не получилось удалить: %%s"
                )
                set "found_conflict=1"
            )
        )
        
        if !found_conflict!==0 (
            call :PrintRed "[X] Не найдено конфликтующих сервисов. Поищи сам байпассы использующие WinDivert."
        ) else (
            call :PrintYellow "[?] Попытка удалить WinDivert снова..."

            net stop "WinDivert" >nul 2>&1
            sc delete "WinDivert" >nul 2>&1
            sc query "WinDivert" >nul 2>&1
            if !errorlevel! neq 0 (
                call :PrintGreen "WinDivert успешно удален после удаления конфликтующих сервисов."
            ) else (
                call :PrintRed "[X] WinDivert все еще не удаляется. Поищи сам байпассы использующие WinDivert.."
            )
        )
    ) else (
        call :PrintGreen "WinDivert успешно выброшен нах##."
    )
    
    echo:
)

:: Conflicting bypasses
set "conflicting_services=GoodbyeDPI discordfix_zapret winws1 winws2"
set "found_any_conflict=0"
set "found_conflicts="

for %%s in (!conflicting_services!) do (
    sc query "%%s" >nul 2>&1
    if !errorlevel!==0 (
        if "!found_conflicts!"=="" (
            set "found_conflicts=%%s"
        ) else (
            set "found_conflicts=!found_conflicts! %%s"
        )
        set "found_any_conflict=1"
    )
)

if !found_any_conflict!==1 (
    call :PrintRed "[X] Конфликтующие сервисы байпассов найдены: !found_conflicts!"
    
    set "CHOICE="
    set /p "CHOICE=Хочешь их удалить? (Y/N) (по дефолту: N) "
    if "!CHOICE!"=="" set "CHOICE=N"
    if "!CHOICE!"=="y" set "CHOICE=Y"
    
    if /i "!CHOICE!"=="Y" (
        for %%s in (!found_conflicts!) do (
            call :PrintYellow "Стопаю и убираю сервис: %%s"
            net stop "%%s" >nul 2>&1
            sc delete "%%s" >nul 2>&1
            if !errorlevel!==0 (
                call :PrintGreen "Успешно убран сервис: %%s"
            ) else (
                call :PrintRed "[X] Не получается удалить: %%s"
            )
        )

        net stop "WinDivert" >nul 2>&1
        sc delete "WinDivert" >nul 2>&1
        net stop "WinDivert14" >nul 2>&1
        sc delete "WinDivert14" >nul 2>&1
    )
    
    echo:
)

:: Discord cache clearing
set "CHOICE="
set /p "CHOICE=Хочешь удалить кеш у Дискорда? (Y/N) (default: Y)  "
if "!CHOICE!"=="" set "CHOICE=Y"
if "!CHOICE!"=="y" set "CHOICE=Y"

if /i "!CHOICE!"=="Y" (
    tasklist /FI "IMAGENAME eq Discord.exe" | findstr /I "Discord.exe" > nul
    if !errorlevel!==0 (
        echo Discord is running, closing...
        taskkill /IM Discord.exe /F > nul
        if !errorlevel! == 0 (
            call :PrintGreen "Дискорд был успешно закрыт"
        ) else (
            call :PrintRed "Нельзя закрыть дискорд"
        )
    )

    set "discordCacheDir=%appdata%\discord"

    for %%d in ("Cache" "Code Cache" "GPUCache") do (
        set "dirPath=!discordCacheDir!\%%~d"
        if exist "!dirPath!" (
            rd /s /q "!dirPath!"
            if !errorlevel!==0 (
                call :PrintGreen "Успешно удален !dirPath!"
            ) else (
                call :PrintRed "Не получилось удалить !dirPath!"
            )
        ) else (
            call :PrintRed "!dirPath! нету"
        )
    )
)
echo:

pause
goto menu


:: GAME SWITCH ========================
:game_switch_status
chcp 65001 > nul

set "gameFlagFile=%~dp0utils\game_filter.enabled"

if exist "%gameFlagFile%" (
    set "GameFilterStatus=enabled"
    set "GameFilter=1024-65535"
) else (
    set "GameFilterStatus=disabled"
    set "GameFilter=12"
)
exit /b


:game_switch
chcp 65001 > nul
cls

if not exist "%gameFlagFile%" (
    echo Enabling game filter...
    echo ENABLED > "%gameFlagFile%"
    call :PrintYellow "Перезапусти чтобы сохранить изменения"
) else (
    echo Disabling game filter...
    del /f /q "%gameFlagFile%"
    call :PrintYellow "Перезапусти чтобы сохранить изменения"
)

pause
goto menu


:: CHECK UPDATES SWITCH =================
:check_updates_switch_status
chcp 65001 > nul

set "checkUpdatesFlag=%~dp0utils\check_updates.enabled"

if exist "%checkUpdatesFlag%" (
    set "CheckUpdatesStatus=enabled"
) else (
    set "CheckUpdatesStatus=disabled"
)
exit /b


:check_updates_switch
chcp 65001 > nul
cls

if not exist "%checkUpdatesFlag%" (
    echo Включаю проверку обнов...
    echo ENABLED > "%checkUpdatesFlag%"
) else (
    echo Выключаю проверку обнов...
    del /f /q "%checkUpdatesFlag%"
)

pause
goto menu


:: IPSET SWITCH =======================
:ipset_switch_status
chcp 65001> nul

set "listFile=%~dp0lists\ipset-all.txt"
for /f %%i in ('type "%listFile%" 2^>nul ^| find /c /v ""') do set "lineCount=%%i"

if !lineCount!==0 (
    set "IPsetStatus=any"
) else (
    findstr /R "^203\.0\.113\.113/32$" "%listFile%" >nul
    if !errorlevel!==0 (
        set "IPsetStatus=none"
    ) else (
        set "IPsetStatus=loaded"
    )
)
exit /b


:ipset_switch
chcp 65001 > nul
cls

set "listFile=%~dp0lists\ipset-all.txt"
set "backupFile=%listFile%.backup"

if "%IPsetStatus%"=="loaded" (
    echo Смена на режим None...
    
    if not exist "%backupFile%" (
        ren "%listFile%" "ipset-all.txt.backup"
    ) else (
        del /f /q "%backupFile%"
        ren "%listFile%" "ipset-all.txt.backup"
    )
    
    >"%listFile%" (
        echo 203.0.113.113/32
    )
    
) else if "%IPsetStatus%"=="none" (
    echo Смена на режим any...
    
    >"%listFile%" (
        rem Creating empty file
    )
    
) else if "%IPsetStatus%"=="any" (
    echo Смена на режим loaded...
    
    if exist "%backupFile%" (
        del /f /q "%listFile%"
        ren "%backupFile%" "ipset-all.txt"
    ) else (
        echo Ошибка: Нет бэкапов чтобы восстановить. Сначала обнови лист.
        pause
        goto menu
    )
    
)

pause
goto menu


:: IPSET UPDATE =======================
:ipset_update
chcp 65001 > nul
cls

set "listFile=%~dp0lists\ipset-all.txt"
set "url=https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/refs/heads/main/.service/ipset-service.txt"

echo Обновляю ipset-all...

if exist "%SystemRoot%\System32\curl.exe" (
    curl -L -o "%listFile%" "%url%"
) else (
    powershell -Command ^
        "$url = '%url%';" ^
        "$out = '%listFile%';" ^
        "$dir = Split-Path -Parent $out;" ^
        "if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null };" ^
        "$res = Invoke-WebRequest -Uri $url -TimeoutSec 10 -UseBasicParsing;" ^
        "if ($res.StatusCode -eq 200) { $res.Content | Out-File -FilePath $out -Encoding UTF8 } else { exit 1 }"
)

echo Готово

pause
goto menu


:: HOSTS UPDATE =======================
:hosts_update
chcp 65001 > nul
cls

set "hostsFile=%SystemRoot%\System32\drivers\etc\hosts"
set "hostsUrl=https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/refs/heads/main/.service/hosts"
set "tempFile=%TEMP%\zapret_hosts.txt"
set "needsUpdate=0"

echo Проверяю файлы хостов...

if exist "%SystemRoot%\System32\curl.exe" (
    curl -L -s -o "%tempFile%" "%hostsUrl%"
) else (
    powershell -Command ^
        "$url = '%hostsUrl%';" ^
        "$out = '%tempFile%';" ^
        "$res = Invoke-WebRequest -Uri $url -TimeoutSec 10 -UseBasicParsing;" ^
        "if ($res.StatusCode -eq 200) { $res.Content | Out-File -FilePath $out -Encoding UTF8 } else { exit 1 }"
)

if not exist "%tempFile%" (
    call :PrintRed "Не удалось скачать файлы хостов с репозитория"
    pause
    goto menu
)

set "firstLine="
set "lastLine="
for /f "usebackq delims=" %%a in ("%tempFile%") do (
    if not defined firstLine (
        set "firstLine=%%a"
    )
    set "lastLine=%%a"
)

findstr /C:"!firstLine!" "%hostsFile%" >nul 2>&1
if !errorlevel! neq 0 (
    echo Первая строка из репозитория не найдена в файле hosts
    set "needsUpdate=1"
)

findstr /C:"!lastLine!" "%hostsFile%" >nul 2>&1
if !errorlevel! neq 0 (
    echo Последняя строка из репозитория не найдена в файле hosts
    set "needsUpdate=1"
)

if "%needsUpdate%"=="1" (
    echo:
    call :PrintYellow "файл хостов требует обновы"
    call :PrintYellow "Пожалуйста, скопируй контент из скачанного файла в файл хостов сам."
    
    start notepad "%tempFile%"
    explorer /select,"%hostsFile%"
) else (
    call :PrintGreen "Файл хостов не требует обнов"
    if exist "%tempFile%" del /f /q "%tempFile%"
)

echo:
pause
goto menu


:: RUN TESTS ==========================
:run_tests
chcp 65001 >nul
cls

:: Require PowerShell 3.0+
powershell -NoProfile -Command "if ($PSVersionTable -and $PSVersionTable.PSVersion -and $PSVersionTable.PSVersion.Major -ge 3) { exit 0 } else { exit 1 }" >nul 2>&1
if %errorLevel% neq 0 (
    echo Требуется PowerShell версии 3.0 или выше (новее)
    echo Пожалуйста, обнови PowerShell и выполни повторный запуск.
    echo.
    pause
    goto menu
)

echo Начинаю настройку тестов в окне PowerShell...
echo.
start "" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0utils\test zapret.ps1"
pause
goto menu


:: Utility functions

:PrintGreen
powershell -Command "Write-Host \"%~1\" -ForegroundColor Green"
exit /b

:PrintRed
powershell -Command "Write-Host \"%~1\" -ForegroundColor Red"
exit /b

:PrintYellow
powershell -Command "Write-Host \"%~1\" -ForegroundColor Yellow"
exit /b

:check_command
where %1 >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] %1 не найден в PATH
    echo Исправьте переменную PATH с инструкциями здесь https://github.com/Flowseal/zapret-discord-youtube/issues/7490
    pause
    exit /b 1
)
exit /b 0

:check_extracted
set "extracted=1"

if not exist "%~dp0bin\" set "extracted=0"

if "%extracted%"=="0" (
    echo Zapret нужно сначала распаковать из архива, или папка bin не найдена по какой-то причине
    pause
    exit
)
exit /b 0

:: ADMIN MENU =========================
: ADMIN_MENU
chcp 65001 > nul
cls
color 0E

echo Тебе нравится модифицировать игру, да, читатель кода?))
echo Ладно, так уж и быть, я разрешу тебе воспользоваться меню админа как закончу.

set "ADMIN_choice="
set /p "ADMIN_choice=Впиши что хочешь сделать (?-?): "

:: Проверка на пустой ввод
if /i "%ADMIN_choice%"=="" goto ADMIN_MENU

:: Эта часть "оптимизации" кода сделана ии, когда я проверял баги
if /i "%ADMIN_choice%"=="CGC_Clan" goto TRUE_ADMIN_MENU

if /i "%ADMIN_choice%"=="Расскажи историю" (
    echo Слышал ту старую сказку?
    echo Да, старую сказку, основанную на пророчестве...
    echo Властелин молота.
    echo Глава 1. Марш тёмного короля.
    echo Герои побеждают короля и останавливают дракона.
    echo Глава 2. Город блеска.
    echo Герои сражаются на колесницах, чтобы спасти королеву.
    echo Глава 4. Испытания святого молота.
    echo Великий кузнец дарит героям страшное оружие.
    echo Глава 5. Розово-золотое поле.
    echo Огромный сад сгорел в пламени ревности.
    echo ...Что было дальше?
    echo Ге-хе-хе! Кто знает.
    echo Была ещё одна глава... Но после неё
    echo Всё прекратилось.
    echo Следующая книга так и не была написана.
    echo История стала такой грандиозной, такой ошеломляющей,
    echo Что, по словам некоторых, поглотила самого автора.
    echo Те юнцы, что могли взять ручку, лежащую для них.
    echo И написать новую страницу.
    echo ...так этого и не сделали.
    echo Колокол звонит. Похоже, мы подошли к финалу.
    echo Итак... как, по-твоему, всё кончилось?
    echo Нет, как бы ТЫ хотел всё закончить?
pause
goto ADMIN_MENU
)

:: Если ничего не подошло, возвращаемся в начало меню
goto ADMIN_MENU


:: TRUE ADMIN MENU ====================
:TRUE_ADMIN_MENU
chcp 65001 > nul
cls
color 0C

echo ТЫ ИЗ МОЕГО КЛАНА?
echo если да, то здравствуй, если нет, то тебе стоит перестать лазить в коде и заходить в мои меню
echo (если ты модифицируешь, то привет и тебе)

set "ADMIN_TRUE_choice="
set /p "ADMIN_TRUE_choice=Впиши что хочешь сделать (?-?): "

if "%ADMIN_TRUE_choice%"=="" goto TRUE_ADMIN_MENU
if /i "%ADMIN_TRUE_choice%"=="Открой ютуб" (
    start "" "https://www.youtube.com"
    goto TRUE_ADMIN_MENU
)
if /i "%ADMIN_TRUE_choice%"=="Открой дискорд" (
    start "" "https://discord.com/"
    goto TRUE_ADMIN_MENU
)

:: Если команда не распознана
echo Не то вписал!
pause
goto TRUE_ADMIN_MENU