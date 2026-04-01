# Comprehensive Power BI Measure Usage Analysis
$ErrorActionPreference = "Continue"

$basePath = "C:\Users\ferry\Documents\Power BI Ferry Tales\Claude"
$tablesPath = Join-Path $basePath "Deneb.SemanticModel\definition\tables"

Write-Host "=" * 100
Write-Host "COMPREHENSIVE POWER BI MEASURE ANALYSIS"
Write-Host "=" * 100
Write-Host ""

# Step 1: Extract all measures from .tmdl files
Write-Host "STEP 1: Extracting ALL measures from .tmdl files..."
Write-Host "-" * 100

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
            $measureDAX["$tableName|$measure"] = $content
        }
    }
}

$totalMeasures = ($allMeasures.Values | Measure-Object -Sum Count).Sum
Write-Host "Total measures found: $totalMeasures"
Write-Host ""

# Step 2: Get measures used in visuals (from our previous extraction)
Write-Host "STEP 2: Measures used in visuals..."
Write-Host "-" * 100

$measuresInVisualsStr = @"
24
25
Actual
Actual % Measure
Actual YoY% All
Average No Smoothing
Average of Lowess
Bonus
Bonus Pts by GW TopN
Customers
Customers YoY% All
DateRange
Dif
Ita_Pop
Labels Top1
MapMeasure3
Name title
Orders YoY% All
Plan
Pts all rounds
Pts by GW
Pts by GW TopN
Pts Pos %
Reviews YoY% All
Round Top1
RoundCounts
sel%
sel%_
Selected % GW
Selected Player % TopN
SelTeam
SizeTextFilter2
SPN
State_Pop
Sum of Orders
Sum of Reviews
Target
Target%
Target2
ThermoTest Value
Total Points
Total pts by GW
Total pts by GW ALL round
Total pts cum
TValue
X
x_
x_wf
Y
Yellow
"@

$measuresInVisuals = @{}
$measuresInVisualsStr.Split("`n") | Where-Object { $_.Trim() } | ForEach-Object {
    $measuresInVisuals[$_.Trim()] = $true
}

Write-Host "Measures used in visuals: $($measuresInVisuals.Count)"
Write-Host ""

# Step 3: Find measures referenced by other measures
Write-Host "STEP 3: Analyzing measure-to-measure references..."
Write-Host "-" * 100

$measuresReferencedByMeasures = @{}

foreach ($key in $measureDAX.Keys) {
    $dax = $measureDAX[$key]
    # Look for [MeasureName] patterns
    $refs = [regex]::Matches($dax, '\[([^\]]+)\]')
    foreach ($ref in $refs) {
        $refMeasure = $ref.Groups[1].Value.Trim()
        $measuresReferencedByMeasures[$refMeasure] = $true
    }
}

Write-Host "Measures referenced by other measures: $($measuresReferencedByMeasures.Count)"
Write-Host ""

# Step 4: Identify unused measures
Write-Host "STEP 4: Identifying UNUSED measures..."
Write-Host "-" * 100
Write-Host ""

$unusedMeasures = @()
$usedMeasures = @()

foreach ($tableName in $allMeasures.Keys | Sort-Object) {
    foreach ($measure in $allMeasures[$tableName]) {
        $isUsedInVisual = $measuresInVisuals.ContainsKey($measure)
        $isReferencedByMeasure = $measuresReferencedByMeasures.ContainsKey($measure)

        $isUsed = $isUsedInVisual -or $isReferencedByMeasure

        if ($isUsed) {
            $usedMeasures += [PSCustomObject]@{
                Table = $tableName
                Measure = $measure
                UsedInVisuals = $isUsedInVisual
                ReferencedByMeasures = $isReferencedByMeasure
            }
        }
        else {
            $unusedMeasures += [PSCustomObject]@{
                Table = $tableName
                Measure = $measure
            }
        }
    }
}

# Generate detailed report
Write-Host "=" * 100
Write-Host "UNUSED MEASURES DETAILED REPORT"
Write-Host "=" * 100
Write-Host ""

$groupedUnused = $unusedMeasures | Group-Object Table

foreach ($group in $groupedUnused | Sort-Object Name) {
    Write-Host "TABLE: $($group.Name)" -ForegroundColor Yellow
    Write-Host "$('=' * 100)"

    foreach ($item in $group.Group | Sort-Object Measure) {
        Write-Host "  - Measure: $($item.Measure)"
        Write-Host "    Reason: Not used in any visuals AND not referenced by other measures"
        Write-Host ""
    }
}

# Summary Statistics
Write-Host "=" * 100
Write-Host "SUMMARY STATISTICS"
Write-Host "=" * 100
$usageRate = [math]::Round((($totalMeasures - $unusedMeasures.Count) / $totalMeasures * 100), 1)

Write-Host ""
Write-Host "Total measures defined:              $totalMeasures"
Write-Host "Measures used in visuals:            $($measuresInVisuals.Count)"
Write-Host "Measures referenced by other measures: $($measuresReferencedByMeasures.Count)"
Write-Host "Unique used measures (total):        $($usedMeasures.Count)"
Write-Host "UNUSED MEASURES (total):             $($unusedMeasures.Count)" -ForegroundColor Red
Write-Host "Usage rate:                          $usageRate%"
Write-Host ""

# Breakdown by table
Write-Host "=" * 100
Write-Host "UNUSED MEASURES BY TABLE"
Write-Host "=" * 100
Write-Host ""

$groupedUnused | Sort-Object Count -Descending | ForEach-Object {
    Write-Host "$($_.Name): $($_.Count) unused measures"
}

Write-Host ""
Write-Host "=" * 100
Write-Host "ANALYSIS COMPLETE"
Write-Host "=" * 100
