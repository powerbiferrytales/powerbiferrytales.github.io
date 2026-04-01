import json
import os
import re
from pathlib import Path
from collections import defaultdict

# Base path
base_path = r"C:\Users\ferry\Documents\Power BI Ferry Tales\Claude"
tables_path = Path(base_path) / "Deneb.SemanticModel" / "definition" / "tables"
report_path = Path(base_path) / "Deneb.Report" / "definition" / "pages"

# Step 1: Extract all measures from .tmdl files
all_measures = {}  # {table: [measures]}
measure_dax = {}  # {table.measure: dax_expression}

print("=" * 80)
print("STEP 1: Extracting all measures from .tmdl files")
print("=" * 80)

for tmdl_file in tables_path.glob("*.tmdl"):
    table_name = tmdl_file.stem
    content = tmdl_file.read_text(encoding='utf-8')

    # Find all measure definitions
    measure_pattern = r"^\s*measure\s+'?([^'=\n]+)'?\s*="
    measures = re.findall(measure_pattern, content, re.MULTILINE)

    if measures:
        all_measures[table_name] = [m.strip() for m in measures]

        # Extract DAX for each measure to check for references
        for measure in measures:
            measure_clean = measure.strip()
            # Find the DAX expression for this measure
            measure_block_pattern = rf"measure\s+'?{re.escape(measure_clean)}'?\s*=\s*```(.*?)```"
            measure_block_match = re.search(measure_block_pattern, content, re.DOTALL)

            if measure_block_match:
                measure_dax[f"{table_name}.{measure_clean}"] = measure_block_match.group(1)
            else:
                # Try without triple backticks (single line)
                measure_line_pattern = rf"measure\s+'?{re.escape(measure_clean)}'?\s*=(.*?)(?=\n\s*(?:measure|column|partition|annotation|changedProperty|lineageTag|formatString)|\Z)"
                measure_line_match = re.search(measure_line_pattern, content, re.DOTALL)
                if measure_line_match:
                    measure_dax[f"{table_name}.{measure_clean}"] = measure_line_match.group(1)

total_measures = sum(len(m) for m in all_measures.values())
print(f"\nFound {total_measures} measures across {len(all_measures)} tables\n")

# Step 2: Find measures used in visuals
measures_in_visuals = set()

print("=" * 80)
print("STEP 2: Finding measures used in visuals")
print("=" * 80)

visual_files = list(report_path.glob("*/visuals/*/visual.json"))
print(f"\nAnalyzing {len(visual_files)} visual files...")

for visual_file in visual_files:
    try:
        with open(visual_file, 'r', encoding='utf-8') as f:
            visual_data = json.load(f)

        # Convert to string for easier searching
        visual_str = json.dumps(visual_data)

        # Look for Measure references
        if '"Measure"' in visual_str:
            # Find all Property fields that follow Measure
            measure_pattern = r'"Measure":\s*{[^}]*?"Property":\s*"([^"]+)"'
            found_measures = re.findall(measure_pattern, visual_str)
            measures_in_visuals.update(found_measures)

    except Exception as e:
        print(f"Error reading {visual_file}: {e}")

print(f"\nFound {len(measures_in_visuals)} unique measures used in visuals")
print(f"Measures: {sorted(measures_in_visuals)}\n")

# Step 3: Find measures referenced by other measures
measures_referenced_by_measures = set()

print("=" * 80)
print("STEP 3: Finding measures referenced by other measures")
print("=" * 80)

for table_measure, dax in measure_dax.items():
    # Look for [MeasureName] patterns in DAX
    referenced_measures = re.findall(r'\[([^\]]+)\]', dax)
    measures_referenced_by_measures.update(referenced_measures)

print(f"\nFound {len(measures_referenced_by_measures)} measures referenced in DAX expressions")

# Step 4: Check filters (basic check in visual JSON)
measures_in_filters = set()

print("=" * 80)
print("STEP 4: Checking for measures in filters")
print("=" * 80)

for visual_file in visual_files:
    try:
        with open(visual_file, 'r', encoding='utf-8') as f:
            visual_data = json.load(f)

        visual_str = json.dumps(visual_data)

        # Look for filter references
        if '"filter"' in visual_str.lower() or '"filters"' in visual_str.lower():
            measure_pattern = r'"Measure":\s*{[^}]*?"Property":\s*"([^"]+)"'
            found_measures = re.findall(measure_pattern, visual_str)
            measures_in_filters.update(found_measures)

    except Exception as e:
        pass

print(f"Found {len(measures_in_filters)} measures potentially used in filters\n")

# Step 5: Identify unused measures
print("=" * 80)
print("STEP 5: Identifying UNUSED measures")
print("=" * 80)

used_measures = measures_in_visuals | measures_referenced_by_measures | measures_in_filters
unused_measures = []

for table_name, measures in all_measures.items():
    for measure in measures:
        # Check if measure is used
        if measure not in used_measures:
            # Double check - sometimes table name is included
            full_name = f"{table_name}.{measure}"
            if full_name not in used_measures:
                unused_measures.append((table_name, measure))

print(f"\nTotal unused measures: {len(unused_measures)}\n")

# Generate report
print("=" * 80)
print("UNUSED MEASURES REPORT")
print("=" * 80)
print()

for table_name, measure in sorted(unused_measures):
    print(f"Table: {table_name}")
    print(f"  Measure: {measure}")
    print(f"  Reason: Not used in visuals, not referenced by other measures, not in filters")
    print()

# Summary statistics
print("=" * 80)
print("SUMMARY STATISTICS")
print("=" * 80)
print(f"Total measures defined: {total_measures}")
print(f"Measures used in visuals: {len(measures_in_visuals)}")
print(f"Measures referenced by other measures: {len(measures_referenced_by_measures)}")
print(f"Measures in filters: {len(measures_in_filters)}")
print(f"Total unique used measures: {len(used_measures)}")
print(f"UNUSED MEASURES: {len(unused_measures)}")
print(f"Usage rate: {((total_measures - len(unused_measures)) / total_measures * 100):.1f}%")
