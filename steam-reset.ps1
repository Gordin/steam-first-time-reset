function Get-SteamAppsPath {
    if (Test-Path "$($env:ProgramFiles)\Steam\steamapps") { return "$($env:ProgramFiles)\Steam\steamapps" }
    if (Test-Path "${env:ProgramFiles(x86)}\Steam\steamapps") { return "${env:ProgramFiles(x86)}\Steam\steamapps" }
    Write-Output "Could not find Steam installation directory"
}

function Get-ACFFilesFromLibrary {
    param($libraryFolderPath)

    $librarySteamPath = Join-Path $libraryFolderPath "steamapps"
    if (Test-Path $librarySteamPath) {
        return Get-ChildItem -Path $librarySteamPath -Filter "*.acf"
    }

    return @()
}

function Get-ACFFiles {
    param($steamLibraryFolders)

    return $steamLibraryFolders | ForEach-Object { Get-ACFFilesFromLibrary -libraryFolderPath $_.Path }
}

function Get-GameName {
    param($content)
    if ($content -match '"name"\s+"(.+?)"') {
        return $matches[1]
    }
}

function Get-InstallDir {
    param($content)
    if ($content -match '"installdir"\s+"(.+?)"') {
        return $matches[1]
    }
}

function Get-InstallScripts {
    param($content)
    $installScriptsSectionRegex = '(?m)(?<=\n\t"InstallScripts"\n\t{)([\s\S]*?)(?=\n\t})'
    $installScriptFileRegex = '\s*"\d+"\s+"(.+?)"'
    if ($content -match $installScriptsSectionRegex) {
        $installScriptsSection = $matches[1]
        return [regex]::Matches($installScriptsSection, $installScriptFileRegex) | ForEach-Object { $_.Groups[1].Value }
    }
    return @()
}

function Get-HasRunKeys {
    param($installScripts, $appPath, $installdir)
    $hasRunKeys = @{}
    foreach ($installScript in $installScripts) {
        $installScriptPath = Join-Path "${appPath}steamapps" -ChildPath "common\$installdir\$installScript"
        if (!(Test-Path $installScriptPath)) { continue }

        $installScriptContent = Get-Content $installScriptPath -Raw
        $hasRunKeyRegex = '(?i)"hasrunkey"\s+"(.+?)"'
        $scriptHasRunKeys = [regex]::Matches($installScriptContent, $hasRunKeyRegex) | ForEach-Object { $_.Groups[1].Value }
        foreach ($key in $scriptHasRunKeys) {
            $hasRunKeys[$key -replace '\\\\', '\'] = $true
        }
    }
    return $hasRunKeys.Keys
}

function Get-GameDataFromAcfFile {
    param ($file)
    $content = Get-Content $file.FullName -Raw
    $name = Get-GameName -content $content
    $installdir = Get-InstallDir -content $content
    $installScripts = Get-InstallScripts -content $content
    $appPath = $file.FullName.Split('steamapps', 2)[0]
    $hasRunKeys = Get-HasRunKeys -installScripts $installScripts -appPath $appPath -installdir $installdir
    return New-Object PSObject -Property @{
        Name                = $name
        InstallScripts      = $installScripts
        InstallScriptsCount = $installScripts.Count
        HasRunKeys          = $hasRunKeys
        ACFFile             = $file.FullName
    }
}

function Get-Games {
    param($acfFiles)
    $games = $acfFiles | ForEach-Object { Get-GameDataFromAcfFile -file $_ }
    return $games
}

function Select-Game {
    param($games)
    return $games | Select-Object Name, InstallScriptsCount, InstallScripts, HasRunKeys, ACFFile | Out-GridView -PassThru -Title "Select a game to reset first-time setup"
}

function Remove-RegistryKey {
    param ($key)
    # Check if the original registry key exists, if not try with WOW6432Node
    if (-not (Test-Path "Registry::$key")) {
        $key = $key -replace '\\SOFTWARE\\', '\SOFTWARE\WOW6432Node\'
        if (-not (Test-Path "Registry::$key")) {
            Write-Host "Registry key already removed: $key"
            return
        }
    }

    try {
        Remove-Item -Path "Registry::$key" -ErrorAction Stop
        Write-Host "Registry key removed: $key"
    }
    catch {
        Write-Host "Failed to remove registry key: $key"
    }
}

function Reset-FirstTimeSetup {
    param($selectedGame)
    $selectedGame.HasRunKeys | ForEach-Object { Remove-RegistryKey -key $_ }
}

function Get-SteamLibraryFolders {
    param($steamAppsPath)

    $libraryFoldersPath = Join-Path $steamAppsPath "libraryfolders.vdf"
    if (-not (Test-Path $libraryFoldersPath)) {
        Write-Host "Could not find libraryfolders.vdf file."
        return @($steamAppsPath)
    }

    $libraryFoldersContent = Get-Content $libraryFoldersPath -Raw

    $libraryFolderSectionRegex = '(?m)"\d+"\s+{([\s\S]*?)}'
    $libraryFolderSections = [regex]::Matches($libraryFoldersContent, $libraryFolderSectionRegex) | ForEach-Object { $_.Groups[1].Value }

    $libraryFolders = @()

    foreach ($section in $libraryFolderSections) {
        $pathRegex = '"path"\s+"(.+?)"'
        $labelRegex = '"label"\s+"(.+?)"'
        $contentIdRegex = '"contentid"\s+"(.+?)"'
        $totalSizeRegex = '"totalsize"\s+"(.+?)"'

        if ($section -match $pathRegex) { $path = $matches[1] }
        if ($section -match $labelRegex) { $label = $matches[1] }
        if ($section -match $contentIdRegex) { $contentId = $matches[1] }
        if ($section -match $totalSizeRegex) { $totalSize = $matches[1] }

        $libraryFolders += [PSCustomObject]@{
            Path      = $path
            Label     = $label
            ContentId = $contentId
            TotalSize = $totalSize
        }
    }

    return $libraryFolders
}

function Invoke-Main {
    $steamAppsPath = Get-SteamAppsPath
    if (-not $steamAppsPath) { return }

    $steamLibraries = Get-SteamLibraryFolders -steamAppsPath $steamAppsPath

    $acfFiles = Get-ACFFiles -steamLibraryFolders $steamLibraries
    $games = Get-Games -acfFiles $acfFiles
    $selectedGame = Select-Game -games $games

    if ($null -eq $selectedGame) {
        Write-Host "No game selected, exiting."
        return
    }

    Reset-FirstTimeSetup -selectedGame $selectedGame
}

Invoke-Main