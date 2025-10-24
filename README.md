## 🇬🇧 English

### Description
Organize your photos and videos by **year** or **year/month**, prioritizing the **capture date** (EXIF / Windows Shell properties). If that metadata is missing (e.g., screenshots), it falls back to the **modification date** (`LastWriteTime`). It can also **rename** files with a configurable pattern using **collision-safe tokens**.

### Requirements
- Windows PowerShell 5.1 or PowerShell 7+
- Read/write permissions on source and destination folders
- (Optional) For the current session:
  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  ```

### Parameters
**Parameters**

| Name | Type | Required | Description |
|---|---|---:|---|
| -Source | string | Yes | Source folder to scan (recursive). |
| -Destination | string | Yes | Destination root folder. |
| -GroupBy | Year \| YearMonth | No (default: Year) | Folder grouping scheme. |
| -LogCsv | string | No | Path to save processing log (CSV, UTF-8). |
| -IncludeExtensions | string[] | No | Extensions to include. Defaults include common photo/video formats. |
| -CopyInsteadOfMove | switch | No | Copy files instead of moving them. |
| -Rename | switch | No | Rename files according to -RenamePattern. |
| -RenamePattern | string | No (default: {YYYY}-{MO}-{DD}_{HH}{MI}{SS}) | Pattern without the dot-extension. |
| -WhatIf | switch | No | Simulate actions without changing files. |
| -Confirm | switch | No | Ask for confirmation before each operation. |

### Rename tokens
Use **uppercase** tokens to avoid collisions (e.g., minute vs. month):

- `{YYYY}` full year (e.g., `2025`)
- `{YY}` short year (e.g., `25`)
- `{MO}` month (`01`–`12`)
- `{DD}` day (`01`–`31`)
- `{HH}` 24-hour (`00`–`23`)
- `{MI}` minutes (`00`–`59`)
- `{SS}` seconds (`00`–`59`)
- `{orig}` original name without extension
- `{ext}` extension without the dot (if included, the script will not duplicate it)

**Pattern examples**
- `"{YYYY}-{MO}-{DD}_{HH}{MI}{SS}"` → `2025-10-24_142355.jpg`
- `"{YYYY}{MO}{DD}_{HH}{MI}{SS}_{orig}"` → `20251024_142355_IMG_1234.jpg`

### Usage examples
**Dry-run with rename**
```powershell
.\Fotos01.ps1 -Source "C:\\temp\\fotos" -Destination "C:\\temp\\ExportadoFotos" -Rename -RenamePattern "{YYYY}-{MO}-{DD}_{HH}{MI}{SS}" -WhatIf -Verbose
```

**Real execution with log**
```powershell
.\Fotos01.ps1 -Source "C:\\temp\\fotos" -Destination "C:\\temp\\ExportadoFotos" -Rename -RenamePattern "{YYYY}{MO}{DD}_{HH}{MI}{SS}_{orig}" -LogCsv ".\\movimientos.csv" -Verbose
```

**Group by Year\\Month and rename**
```powershell
.\Fotos01.ps1 -Source "C:\\temp\\fotos" -Destination "C:\\temp\\ExportadoFotos" -GroupBy YearMonth -Rename -RenamePattern "{YY}{MO}{DD}_{HH}{MI}{SS}"
```

### Date logic
1. **Capture**: try EXIF (`DateTimeOriginal`, `DateTimeDigitized`, `DateTime`) for compatible images, and Windows Shell properties (`System.Photo.DateTaken`, `System.Media.DateRecorded`, `System.Media.DateEncoded`) for images/videos.
2. **Fallback**: if capture is missing, use the **modification date** (`LastWriteTime`).

### Collisions & duplicates
- If the destination name already exists, a suffix ` (1)`, ` (2)`, ... is added automatically.
- If multiple files share the exact same timestamp and pattern, the suffix resolves conflicts.

### Logging (CSV)
When `-LogCsv` is provided, a CSV is generated with columns like: `SourcePath, TargetPath, Action, GroupBy, UsedDate, DateSource, Renamed, RenamePattern, Status, ErrorMessage`.

### Notes
- For **HEIC/RAW**, if .NET cannot read EXIF, the script uses **Explorer (Shell) properties** when available.
- Always start with `-WhatIf` to validate the outcome before moving/copying.
- Unblock the script if downloaded:
  ```powershell
  Unblock-File .\Fotos01.ps1
  ```
---

# Fotos01 – Organizador de fotos y videos (v2)
# Photos & Videos Organizer (v2)

Este README está disponible en **español** e **inglés**. / This README is available in **Spanish** and **English**.

---

## 🇪🇸 Español

### Descripción
Organiza tus fotos y videos por **año** o **año/mes**, priorizando la **fecha de captura** (EXIF / propiedades del Explorador). Si no existe dicha fecha (por ejemplo, capturas de pantalla), usa la **fecha de modificación** (`LastWriteTime`). Además, permite **renombrar** los archivos con un patrón configurable usando **tokens sin colisiones**.

### Requisitos
- Windows PowerShell 5.1 o PowerShell 7+
- Permisos de lectura/escritura en las carpetas de origen y destino
- (Opcional) Ejecutar la sesión con:
  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  ```

### Parámetros
**Parameters**

| Name | Type | Required | Description |
|---|---|---:|---|
| -Source | string | Yes | Source folder to scan (recursive). |
| -Destination | string | Yes | Destination root folder. |
| -GroupBy | Year \| YearMonth | No (default: Year) | Folder grouping scheme. |
| -LogCsv | string | No | Path to save processing log (CSV, UTF-8). |
| -IncludeExtensions | string[] | No | Extensions to include. Defaults include common photo/video formats. |
| -CopyInsteadOfMove | switch | No | Copy files instead of moving them. |
| -Rename | switch | No | Rename files according to -RenamePattern. |
| -RenamePattern | string | No (default: {YYYY}-{MO}-{DD}_{HH}{MI}{SS}) | Pattern without the dot-extension. |
| -WhatIf | switch | No | Simulate actions without changing files. |
| -Confirm | switch | No | Ask for confirmation before each operation. |

> *Nota:* La tabla se muestra en inglés para mantener exactitud de parámetros y descripciones; el resto del README en español explica su uso.

### Tokens de renombrado
Usa tokens **mayúsculos** para evitar colisiones con nombres de mes/minuto, etc.

- `{YYYY}` año completo (p. ej., `2025`)
- `{YY}` año corto (p. ej., `25`)
- `{MO}` mes (`01`–`12`)
- `{DD}` día (`01`–`31`)
- `{HH}` hora 24h (`00`–`23`)
- `{MI}` minutos (`00`–`59`)
- `{SS}` segundos (`00`–`59`)
- `{orig}` nombre original sin extensión
- `{ext}` extensión sin el punto (si se incluye, no se duplicará la extensión)

**Ejemplos de patrón**
- `"{YYYY}-{MO}-{DD}_{HH}{MI}{SS}"` → `2025-10-24_142355.jpg`
- `"{YYYY}{MO}{DD}_{HH}{MI}{SS}_{orig}"` → `20251024_142355_IMG_1234.jpg`

### Ejemplos de uso
**Simulación con renombrado**
```powershell
.\Fotos01.ps1 -Source "C:\\temp\\fotos" -Destination "C:\\temp\\ExportadoFotos" -Rename -RenamePattern "{YYYY}-{MO}-{DD}_{HH}{MI}{SS}" -WhatIf -Verbose
```

**Ejecución real con log**
```powershell
.\Fotos01.ps1 -Source "C:\\temp\\fotos" -Destination "C:\\temp\\ExportadoFotos" -Rename -RenamePattern "{YYYY}{MO}{DD}_{HH}{MI}{SS}_{orig}" -LogCsv ".\\movimientos.csv" -Verbose
```

**Organizar por Año\\Mes y renombrar**
```powershell
.\Fotos01.ps1 -Source "C:\\temp\\fotos" -Destination "C:\\temp\\ExportadoFotos" -GroupBy YearMonth -Rename -RenamePattern "{YY}{MO}{DD}_{HH}{MI}{SS}"
```

### Lógica de fechas
1. **Captura**: intenta EXIF (`DateTimeOriginal`, `DateTimeDigitized`, `DateTime`) para imágenes compatibles, y propiedades del Shell (`System.Photo.DateTaken`, `System.Media.DateRecorded`, `System.Media.DateEncoded`) para imágenes/vídeos.
2. **Respaldo**: si no hay captura, usa **fecha de modificación** (`LastWriteTime`).

### Colisiones y duplicados
- Si el nombre destino ya existe, se agrega sufijo ` (1)`, ` (2)`, ... automáticamente.
- Si varios archivos comparten la misma marca de tiempo y patrón idéntico, el sufijo resolverá el conflicto.

### Registro (CSV)
Si pasas `-LogCsv`, se generará un CSV con columnas como: `SourcePath, TargetPath, Action, GroupBy, UsedDate, DateSource, Renamed, RenamePattern, Status, ErrorMessage`.

### Notas
- Para **HEIC/RAW**, si el EXIF no es legible por .NET, se usa la **propiedad del Explorador** (Shell) cuando esté disponible.
- Ejecuta primero con `-WhatIf` para validar el resultado antes de mover/copiar.
- Desbloquea el script si fue descargado:
  ```powershell
  Unblock-File .\Fotos01.ps1
  ```

