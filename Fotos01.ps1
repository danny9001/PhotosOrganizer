<#
SYNOPSIS
  Organiza fotos y videos por año o año/mes, priorizando fecha de captura (EXIF/Shell).
  Si no existe, usa fecha de modificación (LastWriteTime).
  Puede renombrar los archivos con un patrón configurable usando tokens sin colisiones.

EXAMPLES
  .\Fotos01.ps1 -Source "C:\temp\fotos" -Destination "C:\temp\ExportadoFotos" -WhatIf -Verbose
  .\Fotos01.ps1 -Source "C:\temp\fotos" -Destination "C:\temp\ExportadoFotos" -Rename -RenamePattern "{YYYY}-{MO}-{DD}_{HH}{MI}{SS}" -LogCsv ".\movimientos.csv"
  .\Fotos01.ps1 -Source "C:\temp\fotos" -Destination "C:\temp\ExportadoFotos" -GroupBy YearMonth -Rename -Verbose
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Carpeta de origen de los archivos")]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$Source,

    [Parameter(Mandatory = $true, HelpMessage = "Carpeta destino para organizar los archivos")]
    [string]$Destination,

    # 'Year' (por defecto) o 'YearMonth'
    [ValidateSet('Year','YearMonth')]
    [string]$GroupBy = 'Year',

    # Exporta un log CSV opcional
    [ValidateScript({ !$_.Length -or $_.ToLower().EndsWith('.csv') })]
    [string]$LogCsv,

    # Extensiones soportadas (separadas por tipo)
    [string[]]$ImageExtensions = @('jpg','jpeg','jpe','tif','tiff','png','bmp','gif','heic','heif')
    [string[]]$RawExtensions   = @('dng','cr2','nef','arw','rw2','orf','srw','raf')
    [string[]]$VideoExtensions = @('mp4','mov','m4v','avi','wmv','mkv','mts','m2ts','3gp')

    # Copiar en vez de mover
    [switch]$CopyInsteadOfMove,

    # Forzar renombrado (si no, conserva el nombre original salvo colisión)
    [switch]$Rename,

    # Patrón de renombrado (sin extensión) — tokens: {YYYY},{YY},{MO},{DD},{HH},{MI},{SS},{orig},{ext}
    [string]$RenamePattern = '{YYYY}-{MO}-{DD}_{HH}{MI}{SS}'
)

begin {
    Write-Verbose "Inicializando..."

    $normalizedExts = @($ImageExtensions + $RawExtensions + $VideoExtensions) | ForEach-Object {
        if ($_ -notmatch '^\.') { ".$_" } else { $_ }
    }

    if (-not (Test-Path -LiteralPath $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    $script:ShellApp = New-Object -ComObject Shell.Application
    $script:LogItems = New-Object System.Collections.Generic.List[object]

    # Extensiones tratadas como imagen para intentar EXIF
    $script:ImageExts = @($ImageExtensions + $RawExtensions) | ForEach-Object {
        if ($_ -notmatch '^\.') { ".$_" } else { $_ }
    }

    try { Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue | Out-Null } catch {}
    $script:TotalFiles = 0
    $script:SuccessFiles = 0
    $script:ErrorFiles = 0
}

process {

    function Resolve-UniquePath {
        param([Parameter(Mandatory=$true)][string]$Path)
        $dir  = Split-Path $Path -Parent
        $base = [System.IO.Path]::GetFileNameWithoutExtension($Path)
        $ext  = [System.IO.Path]::GetExtension($Path)
        $i = 1
        $candidate = $Path
        while (Test-Path -LiteralPath $candidate) {
            $candidate = Join-Path $dir ("{0} ({1}){2}" -f $base, $i, $ext)
            $i++
        }
        return $candidate
    }

    function Resolve-UniquePathForName {
        param(
            [Parameter(Mandatory=$true)][string]$Directory,
            [Parameter(Mandatory=$true)][string]$FileNameNoExt,
            [Parameter(Mandatory=$true)][string]$ExtensionWithDot
        )
        $candidate = Join-Path $Directory ($FileNameNoExt + $ExtensionWithDot)
        if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
        $i = 1
        do {
            $candidate = Join-Path $Directory ("{0} ({1}){2}" -f $FileNameNoExt, $i, $ExtensionWithDot)
            $i++
        } while (Test-Path -LiteralPath $candidate)
        return $candidate
    }

    function Get-ExifDate {
        param([Parameter(Mandatory=$true)][string]$Path)
        # 0x9003 DateTimeOriginal, 0x9004 DateTimeDigitized, 0x0132 DateTime
        $tags = 0x9003, 0x9004, 0x0132
        try {
            $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
            try {
                $img = [System.Drawing.Image]::FromStream($fs, $false, $false)
                try {
                    foreach ($tag in $tags) {
                        try {
                            $prop = $img.GetPropertyItem($tag)
                            if ($null -ne $prop -and $prop.Value) {
                                $raw = [System.Text.Encoding]::ASCII.GetString($prop.Value).Trim([char]0).Trim()
                                if (-not [string]::IsNullOrWhiteSpace($raw)) {
                                    # EXIF "YYYY:MM:DD HH:MM:SS" -> "YYYY-MM-DD HH:MM:SS"
                                    $fixed = $raw -replace '^(\d{4}):(\d{2}):(\d{2})', '${1}-${2}-${3}'
                                    $dt = $null
                                    $ok = [datetime]::TryParseExact(
                                        $fixed, 'yyyy-MM-dd HH:mm:ss',
                                        [System.Globalization.CultureInfo]::InvariantCulture,
                                        [System.Globalization.DateTimeStyles]::AssumeLocal,
                                        [ref]$dt
                                    )
                                    if (-not $ok) { $ok = [datetime]::TryParse($fixed, [ref]$dt) }
                                    if ($ok -and $dt -gt [datetime]'1900-01-01') {
                                        Write-Verbose "EXIF encontrado ($('{0:X4}' -f $tag)): $dt — $Path"
                                        return $dt
                                    }
                                }
                            }
                        } catch { }
                    }
                } finally { $img.Dispose() }
            } finally { $fs.Dispose() }
        } catch {
            Write-Verbose "No se pudo leer EXIF: $Path — $($_.Exception.Message)"
        }
        return $null
    }

    function Get-ShellExtendedProperty {
        param(
            [Parameter(Mandatory=$true)][string]$Path,
            [Parameter(Mandatory=$true)][string[]]$PropertyNames
        )
        try {
            $folderPath = Split-Path $Path -Parent
            $leaf       = Split-Path $Path -Leaf
            $ns         = $script:ShellApp.Namespace($folderPath)
            if ($null -eq $ns) { return $null }
            $item       = $ns.ParseName($leaf)
            if ($null -eq $item) { return $null }

            foreach ($pn in $PropertyNames) {
                try {
                    $val = $item.ExtendedProperty($pn)
                    if ($val) { return $val }
                } catch { }
            }
        } catch { }
        return $null
    }

    function Convert-ToDateTime {
        param([object]$Value)
        if (-not $Value) { return $null }
        if ($Value -is [datetime]) { return $Value }
        try {
            $dt = $null
            $ok = [datetime]::TryParse($Value.ToString(), [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AllowWhiteSpaces, [ref]$dt)
            if ($ok) { return $dt }
            $ok = [datetime]::TryParse($Value.ToString(), [System.Globalization.CultureInfo]::CurrentCulture, [System.Globalization.DateTimeStyles]::AllowWhiteSpaces, [ref]$dt)
            if ($ok) { return $dt }
        } catch { }
        return $null
    }

    function Get-CaptureOrModifiedDate {
        param([Parameter(Mandatory=$true)][System.IO.FileInfo]$File)

        $ext = $File.Extension.ToLowerInvariant()
        $isImage = $script:ImageExts -contains $ext

        # 1) Fecha de captura (EXIF para imágenes; Shell para imágenes/video)
        $dt = $null
        if ($isImage) { $dt = Get-ExifDate -Path $File.FullName }

        if (-not $dt) {
            $shellDateRaw = Get-ShellExtendedProperty -Path $File.FullName -PropertyNames @(
                'System.Photo.DateTaken',
                'System.Media.DateRecorded',
                'System.Media.DateEncoded'
            )
            $dt = Convert-ToDateTime $shellDateRaw
            if ($dt) { Write-Verbose "Shell date usada: $dt — $($File.FullName)" }
        }

        # 2) Si no hay captura, usar MODIFICACIÓN (LastWriteTime)
        if (-not $dt) {
            $dt = $File.LastWriteTime
            Write-Verbose "Usando fecha de modificación (fallback): $dt — $($File.FullName)"
            return @{ Date=$dt; Source='Modified' }
        }

        return @{ Date=$dt; Source='Capture' }
    }

    # >>> NUEVA FUNCIÓN con tokens sin colisiones
    function Build-FileNameFromPattern {
        param(
            [Parameter(Mandatory=$true)][DateTime]$Date,
            [Parameter(Mandatory=$true)][string]$OriginalNameNoExt,
            [Parameter(Mandatory=$true)][string]$ExtensionNoDot,
            [Parameter(Mandatory=$true)][string]$Pattern
        )

        # Mapa de tokens SIN colisiones (PowerShell hash keys son case-insensitive)
        $map = [ordered]@{
            '{YYYY}' = ('{0:yyyy}' -f $Date)
            '{YY}'   = ('{0:yy}'   -f $Date)
            '{MO}'   = ('{0:MM}'   -f $Date)  # Mes
            '{DD}'   = ('{0:dd}'   -f $Date)
            '{HH}'   = ('{0:HH}'   -f $Date)
            '{MI}'   = ('{0:mm}'   -f $Date)  # Minutos (antes {mm})
            '{SS}'   = ('{0:ss}'   -f $Date)
            '{orig}' = $OriginalNameNoExt
            '{ext}'  = $ExtensionNoDot
        }

        $name = $Pattern
        foreach ($k in $map.Keys) {
            $name = $name.Replace($k, $map[$k])
        }

        # Limpia caracteres inválidos de Windows
        $invalid = ([IO.Path]::GetInvalidFileNameChars() + [char]':') -join ''
        $regex = "[{0}]" -f [Regex]::Escape($invalid)
        $name = [Regex]::Replace($name, $regex, "_")

        return $name
    }

    Write-Verbose "Enumerando archivos en: $Source"
    $files = Get-ChildItem -LiteralPath $Source -Recurse -File -ErrorAction Stop | Where-Object {
        $normalizedExts -contains $_.Extension.ToLowerInvariant()
    }

    $script:TotalFiles = $files.Count
    $i = 0
    foreach ($f in $files) {
        $i++
        Write-Progress -Activity "Procesando archivos" -Status "Archivo $i de $($script:TotalFiles)" -PercentComplete (($i/$script:TotalFiles)*100)
        try {
            $meta = Get-CaptureOrModifiedDate -File $f
            $dt   = $meta.Date
            $src  = $meta.Source

            # Construir carpeta destino según GroupBy
            $year  = ('{0:yyyy}' -f $dt)
            $month = ('{0:yyyy-MM}' -f $dt)
            $targetDir = if ($GroupBy -eq 'YearMonth') {
                Join-Path (Join-Path $Destination $year) $month
            } else {
                Join-Path $Destination $year
            }
            if (-not (Test-Path -LiteralPath $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }

            $origNoExt  = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
            $extNoDot   = $f.Extension.TrimStart('.')
            $extWithDot = $f.Extension

            if ($Rename) {
                $newBase = Build-FileNameFromPattern -Date $dt -OriginalNameNoExt $origNoExt -ExtensionNoDot $extNoDot -Pattern $RenamePattern

                # Si el patrón incluye {ext}, evitar duplicar extensión
                if ($RenamePattern -like '*{ext}*') {
                    # Asegura que termine con .ext
                    if (-not $newBase.EndsWith(".$extNoDot", [System.StringComparison]::OrdinalIgnoreCase)) {
                        $newBase = "$newBase.$extNoDot"
                    }
                    $targetPath = Resolve-UniquePathForName -Directory $targetDir -FileNameNoExt ([System.IO.Path]::GetFileNameWithoutExtension($newBase)) -ExtensionWithDot ([System.IO.Path]::GetExtension($newBase))
                } else {
                    $targetPath = Resolve-UniquePathForName -Directory $targetDir -FileNameNoExt $newBase -ExtensionWithDot $extWithDot
                }
            } else {
                $targetPath = Join-Path $targetDir $f.Name
                if (Test-Path -LiteralPath $targetPath) {
                    $targetPath = Resolve-UniquePath -Path $targetPath
                }
            }

            $action = if ($CopyInsteadOfMove) { "COPY" } else { "MOVE" }
            $what   = "{0} -> {1}" -f $f.FullName, $targetPath

            if ($PSCmdlet.ShouldProcess($what, $action)) {
                if ($CopyInsteadOfMove) {
                    Copy-Item -LiteralPath $f.FullName -Destination $targetPath
                } else {
                    Move-Item -LiteralPath $f.FullName -Destination $targetPath
                }
            }

            $script:LogItems.Add([pscustomobject]@{
                SourcePath    = $f.FullName
                TargetPath    = $targetPath
                Action        = $action
                GroupBy       = $GroupBy
                UsedDate      = $dt
                DateSource    = $src     # 'Capture' o 'Modified'
                Renamed       = [bool]$Rename
                RenamePattern = if ($Rename) { $RenamePattern } else { $null }
                Status        = "OK"
                ErrorMessage  = $null
            }) | Out-Null
            $script:SuccessFiles++
        } catch {
            $script:LogItems.Add([pscustomobject]@{
                SourcePath    = $f.FullName
                TargetPath    = $null
                Action        = if ($CopyInsteadOfMove) { "COPY" } else { "MOVE" }
                GroupBy       = $GroupBy
                UsedDate      = $null
                DateSource    = $null
                Renamed       = [bool]$Rename
                RenamePattern = if ($Rename) { $RenamePattern } else { $null }
                Status        = "ERROR"
                ErrorMessage  = $_.Exception.Message
            }) | Out-Null
            Write-Warning "Error con '$($f.FullName)': $($_.Exception.Message)"
            $script:ErrorFiles++
        }
    }
    Write-Progress -Activity "Procesando archivos" -Completed
}

end {
    try {
        if ($LogCsv) {
            $script:LogItems | Export-Csv -Path $LogCsv -NoTypeInformation -Encoding UTF8
            Write-Host "Log guardado en: $LogCsv"
        }
        Write-Host "\nResumen:"
        Write-Host "Total de archivos procesados: $($script:TotalFiles)"
        Write-Host "Exitosos: $($script:SuccessFiles)"
        Write-Host "Errores: $($script:ErrorFiles)"
    } finally {
        if ($script:ShellApp) {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($script:ShellApp) | Out-Null
        }
    }
}
