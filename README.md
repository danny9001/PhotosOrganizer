# EN VERSION

# Fotos01.ps1 — Photos Organizer (PowerShell)

Organize photos and videos by capture date. If the file has no capture metadata (e.g., screenshots), the script falls back to the file **modification date** (LastWriteTime). Optionally rename files using a **collision-safe** pattern.

> Tested on Windows PowerShell 5.1 and PowerShell 7+ on Windows (uses Windows Shell extended properties for some metadata).

---

## Features

- **Date priority**: Capture date from **EXIF** (JPEG/TIFF/RAW when supported) or Windows Shell properties (`DateTaken`, `DateRecorded`, `DateEncoded`).
- **Fallback**: If no capture date is available, use **LastWriteTime** (modification date).
- **Folder structure**: Group by `Year` (default) or `YearMonth`.
- **Renaming**: Optional renaming with a customizable pattern using safe tokens (`{YYYY}`, `{YY}`, `{MO}`, `{DD}`, `{HH}`, `{MI}`, `{SS}`, `{orig}`, `{ext}`).
- **No overwrite**: Auto-appends ` (1)`, ` (2)`, … when a name already exists.
- **WhatIf/Confirm**: Dry-run support and standard confirmation prompts.
- **CSV log**: Optional CSV with each processed item.

---

## Requirements

- Windows 10/11.
- PowerShell 5.1 or PowerShell 7+ (on Windows).
- Permissions to read source folders and write into destination.

> The script uses `System.Drawing` to read EXIF for common image formats, and Windows **Shell.Application** COM to query extended properties for images/videos.

---

## Parameters

| Name | Type | Required | Description |
|---|---|---|---|
| `-Source` | `string` | **Yes** | Source folder to scan (recursive). |
| `-Destination` | `string` | **Yes** | Destination root folder. |
| `-GroupBy` | `Year` \| `YearMonth` | No (default: `Year`) | Folder grouping scheme. |
| `-LogCsv` | `string` | No | Path to save processing log (CSV, UTF-8). |
| `-IncludeExtensions` | `string[]` | No | Extensions to include. Defaults include common photo/video formats. |
| `-CopyInsteadOfMove` | `switch` | No | Copy files instead of moving them. |
| `-Rename` | `switch` | No | Rename files according to `-RenamePattern`. |
| `-RenamePattern` | `string` | No (default: `{YYYY}-{MO}-{DD}_{HH}{MI}{SS}`) | Pattern without the dot-extension. |
| `-WhatIf` | `switch` | No | Simulate actions without changing files. |
| `-Confirm` | `switch` | No | Ask for confirmation before each operation. |

### Rename tokens (collision-safe)

- `{YYYY}`: 4-digit year (e.g., `2025`)
- `{YY}`: 2-digit year (e.g., `25`)
- `{MO}`: 2-digit month (`01`–`12`)
- `{DD}`: 2-digit day (`01`–`31`)
- `{HH}`: 2-digit hour (00–23)
- `{MI}`: 2-digit minutes (00–59)
- `{SS}`: 2-digit seconds (00–59)
- `{orig}`: original file name without extension
- `{ext}`: file extension without dot

> If the pattern already contains `{ext}`, the script will not append the extension again. Otherwise, it preserves the original extension.

---

## Usage

### Dry run (recommended first)
```powershell
.\u0046otos01.ps1 -Source "C:\\temp\\fotos" -Destination "C:\\temp\\ExportadoFotos" -Rename -RenamePattern "{YYYY}-{MO}-{DD}_{HH}{MI}{SS}" -WhatIf -Verbose
```

### Real run with CSV log
```powershell
.
otos01.ps1 -Source "C:\\temp\\fotos" -Destination "C:\\temp\\ExportadoFotos" -Rename -RenamePattern "{YYYY}{MO}{DD}_{HH}{MI}{SS}_{orig}" -LogCsv ".\\movimientos.csv" -Verbose
```

### Group by YearMonth (e.g., `2025\\2025-10`)
```powershell
.\u0046otos01.ps1 -Source "D:\\Import" -Destination "E:\\Library" -GroupBy YearMonth -Rename -RenamePattern "{YY}{MO}{DD}_{HH}{MI}{SS}"
```

---

## How it decides the date

1. **Capture date**:
   - EXIF tags (in priority order): `DateTimeOriginal (0x9003)`, `DateTimeDigitized (0x9004)`, `DateTime (0x0132)` for supported image formats.
   - Windows Shell extended properties: `System.Photo.DateTaken`, `System.Media.DateRecorded`, `System.Media.DateEncoded` (covers HEIC/HEIF and many video formats).
2. **Fallback**: If none of the above are available, the script uses the file's **LastWriteTime** (modification time).

---

## Tips

- Run with `-WhatIf -Verbose` to review actions before committing.
- If you see unexpected dates, check the `DateSource` column in the CSV log (`Capture` vs `Modified`).
- For very large libraries, process in batches by subfolders to reduce rollback risk.
- If you need a different structure (e.g., `Year/Month` names or camera model in the name), extend the rename map in `Build-FileNameFromPattern`.

---

## License

This script is provided as-is, without warranty. Use at your own risk.


# ES VERSION
# Fotos01.ps1 — Organizador y Renombrador de Fotos/Vídeos por Fecha

Organiza colecciones de **fotos y videos** en carpetas por **año** o **año/mes**, priorizando la **fecha de captura** (EXIF/propiedades del Explorador de Windows). Si un archivo **no** tiene metadatos de captura (por ejemplo, una **captura de pantalla**), usa la **fecha de modificación** (`LastWriteTime`). Opcionalmente **renombra** los archivos con un patrón **configurable**.

> **Entorno compatible:** Windows PowerShell 5.1 o PowerShell 7+ en Windows (se usa `Shell.Application` para leer propiedades extendidas y `System.Drawing` para EXIF en JPG/TIFF).

---

## Características

- 📁 Organización por `Year` (`Destino\YYYY`) o `YearMonth` (`Destino\YYYY\YYYY-MM`).
- 🗓️ Prioriza **fecha de captura** (EXIF/Shell) y si no existe usa **fecha de modificación**.
- 🔤 **Renombrado** opcional con patrón flexible y **tokens sin colisiones**.
- 🧩 Soporte para formatos comunes de **imágenes** (JPG, PNG, HEIC, RAW…) y **videos** (MP4, MOV, MKV, etc.).
- 🛡️ Evita sobrescribir archivos (agrega ` (1)`, ` (2)`, … en colisiones).
- 🧪 Soporta `-WhatIf` y `-Verbose` para simulación y diagnóstico.
- 📄 Genera **log CSV** opcional de todas las acciones.

---

## Instalación

1. Copia `Fotos01.ps1` a una carpeta, por ejemplo `C:\Script`.
2. (Opcional) Desbloquea el archivo si fue descargado:
   ```powershell
   Unblock-File .\Fotos01.ps1
   ```
3. (Opcional) Habilita la ejecución solo para la sesión actual:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```

---

## Uso rápido

Simulación (sin mover ni renombrar), con detalle:
```powershell
.\Fotos01.ps1 -Source "C:\temp\fotos" -Destination "C:\temp\ExportadoFotos" -GroupBy YearMonth -Rename -RenamePattern "{YYYY}-{MO}-{DD}_{HH}{MI}{SS}" -WhatIf -Verbose
```

Ejecución real con log CSV:
```powershell
.\Fotos01.ps1 -Source "C:\temp\fotos" -Destination "C:\temp\ExportadoFotos" -GroupBy Year -Rename -RenamePattern "{YYYY}{MO}{DD}_{HH}{MI}{SS}_{orig}" -LogCsv ".\movimientos.csv" -Verbose
```

Copiar en lugar de mover:
```powershell
.\Fotos01.ps1 -Source "D:\Importar" -Destination "E:\Medios" -CopyInsteadOfMove -Rename -RenamePattern "{YYYY}-{MO}-{DD}_{HH}{MI}{SS}"
```

---

## Parámetros

- `-Source <string>` **(obligatorio):** Carpeta de origen a procesar (recursivo).
- `-Destination <string>` **(obligatorio):** Carpeta raíz de destino.
- `-GroupBy <Year|YearMonth>` (por defecto `Year`): Estructura de carpetas en destino.
- `-IncludeExtensions <string[]>`: Lista de extensiones a incluir (sin el punto o con él).
- `-CopyInsteadOfMove`: Copia en vez de mover.
- `-Rename`: Activa renombrado según patrón.
- `-RenamePattern <string>`: Patrón de renombre (sin extensión, salvo que incluyas `{ext}`).
- `-LogCsv <string>`: Ruta del CSV de log.
- `-WhatIf`: Simula las operaciones sin realizarlas.
- `-Verbose`: Muestra detalles (incluye fuente de fecha detectada).

### Tokens del patrón de renombrado

Tokens **no ambiguos** (evitan choques con nombres/meses/minutos):

- Fecha/hora: `{YYYY}`, `{YY}`, `{MO}`, `{DD}`, `{HH}`, `{MI}`, `{SS}`
- Nombre original: `{orig}` (sin extensión)
- Extensión: `{ext}` (sin punto). Si el patrón incluye `{ext}`, **no** se añade de nuevo.

**Ejemplos:**
- `"{YYYY}-{MO}-{DD}_{HH}{MI}{SS}"` → `2025-10-24_153045.jpg`
- `"{YYYY}{MO}{DD}_{HH}{MI}{SS}_{orig}"` → `20251024_153045_IMG_1234.jpg`

---

## Cómo determina la fecha

1. **Imágenes (JPG/TIFF/…):** intenta EXIF en este orden:
   - `DateTimeOriginal (0x9003)`, `DateTimeDigitized (0x9004)`, `DateTime (0x0132)`.
2. **Imágenes/Video (vía Shell):** `System.Photo.DateTaken`, `System.Media.DateRecorded`, `System.Media.DateEncoded`.
3. Si no hay metadatos de captura: **usa `LastWriteTime`** (fecha de modificación del archivo).

> Para HEIC/RAW, EXIF puede no estar disponible vía `System.Drawing`; en ese caso se usan propiedades del Explorador (Shell).

---

## Ejemplos adicionales

Organizar por Año/Mes y mantener nombre original:
```powershell
.\Fotos01.ps1 -Source "C:\In" -Destination "D:\Out" -GroupBy YearMonth
```

Solo imágenes JPG/PNG y renombrar:
```powershell
.\Fotos01.ps1 -Source "C:\In" -Destination "D:\Out" -IncludeExtensions jpg,png -Rename -RenamePattern "{YYYY}{MO}{DD}_{HH}{MI}{SS}"
```

---

## Solución de problemas

- **No aparece `-Rename` en `Get-Help`:** Estás ejecutando una versión anterior. Verifica la ruta real:
  ```powershell
  (Get-Command .\Fotos01.ps1).Path
  Get-Help .\Fotos01.ps1 -Full
  ```
- **No usa la fecha de captura:** Ejecuta con `-Verbose` para ver si la fecha vino de `EXIF`, `Shell` o `Modified`.
- **HEIC/RAW no leen EXIF:** Es normal; dependerá de las propiedades del Shell. Si necesitas máxima cobertura, integra ExifTool.
- **Error de ejecución de scripts:**
  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  ```

---

## Estructura del proyecto

```
📁 raiz-del-repo/
├─ Fotos01.ps1           # Script principal
├─ README.md             # Este archivo
└─ ejemplos/             # (Opcional) capturas/logs de ejemplo
```

---

## Licencia

Este proyecto se publica bajo la licencia **MIT**. Puedes usarlo, modificarlo y distribuirlo manteniendo el aviso de licencia.

---

## Créditos

Creado por Daniel Landívar con soporte de M365 Copilot.
