# PowerShell script to analyze Power BI measures
$ErrorActionPreference = "Continue"

$basePath = "C:\Users\ferry\Documents\Power BI Ferry Tales\Claude"
$tablesPath = Join-Path $basePath "Deneb.SemanticModel\definition\tables"
$reportPath = Join-Path $basePath "Deneb.Report\definition\pages"

# Step 1: Extract all measures
Write-Host "=" * 80
Write-Host "STEP 1: Extracting all measures from .tmdl files"
Write-Host "=" * 80

$allMeasures = @{}
$measureDAX = @{}

Get-ChildItem -Path $tablesPath -Filter "*.tmdl" | ForEach-Object {
    $tableName = $_.BaseName
    $content = Get-Content $_.FullName -Raw -Encoding UTF8

    # Find all measures
    $measures = [regex]::Matches($content, "^\s*measure\s+'?([^'=\n]+)'?\s*=", [System.Text.RegularExpressions.RegexOptions]::Multiline)

    if ($measures.Count -gt 0) {
        $measureList = $measures | ForEach-Object { $_.Groups[1].Value.Trim() }
        $allMeasures[$tableName] = $measureList

        foreach ($measure in $measureList) {
            # Store DAX expression
            $measureDAX["$tableName.$measure"] = $content
        }
    }
}

$totalMeasures = ($allMeasures.Values | Measure-Object -Sum Count).Sum
Write-Host "`nFound $totalMeasures measures across $($allMeasures.Count) tables`n"

# Step 2: Find measures used in visuals
Write-Host "=" * 80
Write-Host "STEP 2: Finding measures used in visuals"
Write-Host "=" * 80

$measuresInVisuals = @{}

$visualFiles = Get-ChildItem -Path $reportPath -Filter "visual.json" -Recurse

Write-Host "`nAnalyzing $($visualFiles.Count) visual files..."

foreach ($visualFile in $visualFiles) {
    try {
        $content = Get-Content $visualFile.FullName -Raw -Encoding UTF8

        # Look for Measure references
        if ($content -match '"Measure"') {
            # Find Property fields after Measure
            $matches = [regex]::Matches($content, '"Measure"[^}]*?"Property":\s*"([^"]+)"')
            foreach ($match in $matches) {
                $measureName = $match.Groups[1].Value
                $measuresInVisuals[$measureName] = $true
            }
        }
    }
    catch {
        Write-Host "Error reading $($visualFile.FullName): $_"
    }
}

Write-Host "`nFound $($measuresInVisuals.Count) unique measures used in visuals"

# Step 3: Find measures referenced by other measures
Write-Host "`n" + ("=" * 80)
Write-Host "STEP 3: Finding measures referenced by other measures"
Write-Host "=" * 80

$measuresReferencedByMeasures = @{}

foreach ($tableMeasure in $measureDAX.Keys) {
    $dax = $measureDAX[$tableMeasure]
    # Look for [MeasureName] patterns
    $refs = [regex]::Matches($dax, '\[([^\]]+)\]')
    foreach ($ref in $refs) {
        $refMeasure = $ref.Groups[1].Value
        $measuresReferencedByMeasures[$refMeasure] = $true
    }
}

Write-Host "`nFound $($measuresReferencedByMeasures.Count) measures referenced in DAX expressions"

# Step 4: Identify unused measures
Write-Host "`n" + ("=" * 80)
Write-Host "STEP 4: Identifying UNUSED measures"
Write-Host "=" * 80

$unusedMeasures = @()

foreach ($tableName in $allMeasures.Keys) {
    foreach ($measure in $allMeasures[$tableName]) {
        $isUsed = $false

        # Check if in visuals
        if ($measuresInVisuals.ContainsKey($measure)) {
            $isUsed = $true
        }

        # Check if referenced by other measures
        if ($measuresReferencedByMeasures.ContainsKey($measure)) {
            $isUsed = $true
        }

        if (-not $isUsed) {
            $unusedMeasures += [PSCustomObject]@{
                Table = $tableName
                Measure = $measure
            }
        }
    }
}

Write-Host "`nTotal unused measures: $($unusedMeasures.Count)`n"

# Generate report
Write-Host "=" * 80
Write-Host "UNUSED MEASURES REPORT"
Write-Host "=" * 80
Write-Host ""

$unusedMeasures | Sort-Object Table, Measure | ForEach-Object {
    Write-Host "Table: $($_.Table)"
    Write-Host "  Measure: $($_.Measure)"
    Write-Host "  Reason: Not used in visuals, not referenced by other measures"
    Write-Host ""
}

# Summary
Write-Host "=" * 80
Write-Host "SUMMARY STATISTICS"
Write-Host "=" * 80
$usedCount = $totalMeasures - $unusedMeasures.Count
$usageRate = [math]::Round(($usedCount / $totalMeasures * 100), 1)
Write-Host "Total measures defined: $totalMeasures"
Write-Host "Measures used in visuals: $($measuresInVisuals.Count)"
Write-Host "Measures referenced by other measures: $($measuresReferencedByMeasures.Count)"
Write-Host "UNUSED MEASURES: $($unusedMeasures.Count)"
Write-Host "Usage rate: $usageRate%"
