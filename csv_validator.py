#!/usr/bin/env python3
"""
CSV Validator - Find potential issues in CSV files that might cause parsing problems

Usage:
    python csv_validator.py path/to/file.csv [options]

Options:
    --delimiter=CHAR   Specify the delimiter (default: auto-detect)
    --encoding=ENC     Specify file encoding (default: utf-8)
    --output=FILE      Write report to file instead of stdout
    --verbose          Show more detailed information
"""

import csv
import sys
import os
import re
import argparse
from collections import defaultdict
import codecs

def detect_delimiter(file_path, encoding='utf-8', sample_size=10):
    """
    Auto-detect the delimiter by examining the first few lines of the file.
    Returns the detected delimiter and detailed analysis for debugging.
    """
    delimiters = [',', '\t', ';', '|']
    delimiter_counts = {d: 0 for d in delimiters}
    analysis = {
        'line_counts': {},
        'consistency': {},
        'field_counts': defaultdict(list)
    }
    
    try:
        with codecs.open(file_path, 'r', encoding=encoding, errors='replace') as f:
            # Read the first few lines
            lines = []
            for i in range(sample_size):
                line = f.readline()
                if not line:
                    break
                line = line.strip()
                if line:
                    lines.append((i+1, line))
            
            # Count occurrences of each delimiter and analyze field counts
            for line_num, line in lines:
                analysis['line_counts'][line_num] = {}
                for d in delimiters:
                    count = line.count(d)
                    delimiter_counts[d] += count
                    analysis['line_counts'][line_num][d] = count
                    
                    # Check how many fields this would create with this delimiter
                    if count > 0:
                        fields = len(line.split(d))
                        analysis['field_counts'][d].append((line_num, fields))
    
            # Calculate consistency scores
            for d in delimiters:
                if len(analysis['field_counts'][d]) > 1:
                    field_counts = [count for _, count in analysis['field_counts'][d]]
                    most_common = max(set(field_counts), key=field_counts.count)
                    consistent_count = field_counts.count(most_common)
                    consistency_score = consistent_count / len(field_counts)
                    analysis['consistency'][d] = {
                        'score': consistency_score,
                        'most_common_field_count': most_common,
                        'field_count_occurrences': {
                            count: field_counts.count(count) 
                            for count in set(field_counts)
                        }
                    }
            
            # Determine best delimiter based on consistency and frequency
            best_delimiter = ','  # Default
            best_score = 0
            
            for d in delimiters:
                if d in analysis['consistency']:
                    score = analysis['consistency'][d]['score'] * sum(line.count(d) for _, line in lines)
                    if score > best_score:
                        best_score = score
                        best_delimiter = d
            
            return best_delimiter, analysis
                
    except Exception as e:
        print(f"Error detecting delimiter: {e}")
        return ',', {'error': str(e)}  # Default to comma

def validate_csv(file_path, delimiter=None, encoding='utf-8', verbose=False):
    """
    Validate a CSV file and return a list of potential issues.
    """
    issues = []
    stats = {}
    row_count = 0
    
    try:
        # Auto-detect delimiter if not specified
        if delimiter is None:
            detected_delimiter, delimiter_analysis = detect_delimiter(file_path, encoding)
            delimiter = detected_delimiter
            stats['delimiter_analysis'] = delimiter_analysis
            print(f"Auto-detected delimiter: '{delimiter}' " + 
                  ("(tab)" if delimiter == '\t' else 
                   "(comma)" if delimiter == ',' else 
                   "(semicolon)" if delimiter == ';' else 
                   "(pipe)" if delimiter == '|' else ""))
        
        # First pass: read with csv module to check basic structure
        with codecs.open(file_path, 'r', encoding=encoding, errors='replace') as f:
            sample = f.read(4096)
            # Check for BOM
            if sample.startswith('\ufeff'):
                issues.append(("File has UTF-8 BOM marker which may cause issues with some parsers", "File", 0))
            
            # Check if file appears to be binary
            if '\0' in sample:
                issues.append(("File contains null bytes, might be a binary file not a CSV", "File", 0))
        
        # Try all potential delimiters to see which one gives the most consistent field counts
        all_delimiters = [',', '\t', ';', '|']
        delimiter_field_counts = {}
        
        for test_delimiter in all_delimiters:
            with codecs.open(file_path, 'r', encoding=encoding, errors='replace') as f:
                reader = csv.reader(f, delimiter=test_delimiter)
                field_counts = defaultdict(int)
                total_rows = 0
                
                try:
                    expected_count = len(next(reader))  # Header count
                    
                    for row in reader:
                        total_rows += 1
                        field_counts[len(row)] += 1
                    
                    # Calculate consistency percentage
                    if total_rows > 0:
                        max_count = max(field_counts.values())
                        consistency = max_count / total_rows
                        delimiter_field_counts[test_delimiter] = {
                            'expected': expected_count,
                            'counts': dict(field_counts),
                            'total_rows': total_rows,
                            'consistency': consistency
                        }
                except Exception:
                    pass
        
        stats['delimiter_field_analysis'] = delimiter_field_counts
        
        # If our initially detected delimiter doesn't give the best consistency,
        # suggest using a different one
        if delimiter in delimiter_field_counts:
            best_delimiter = max(delimiter_field_counts.keys(), 
                                key=lambda d: delimiter_field_counts[d]['consistency'])
            
            if best_delimiter != delimiter and delimiter_field_counts[best_delimiter]['consistency'] > delimiter_field_counts[delimiter]['consistency'] + 0.1:
                issues.append((f"Detected delimiter '{delimiter}' may not be optimal. Consider using '{best_delimiter}' for better field consistency", "Warning", 0))
        
        # Read the file with csv module using the selected delimiter
        with codecs.open(file_path, 'r', encoding=encoding, errors='replace') as f:
            csv_reader = csv.reader(f, delimiter=delimiter)
            
            # Get headers
            try:
                headers = next(csv_reader)
                headers = [h.strip() for h in headers]
                stats['header_count'] = len(headers)
                stats['headers'] = headers
                
                # Check empty headers
                for i, header in enumerate(headers):
                    if not header:
                        issues.append((f"Empty header at column {i+1}", "Header", i+1))
                
                # Check duplicate headers
                seen_headers = {}
                for i, header in enumerate(headers):
                    if header in seen_headers:
                        issues.append((f"Duplicate header '{header}' at column {i+1}", "Header", i+1))
                    seen_headers[header] = i+1
                
                # Initialize column statistics
                column_stats = {
                    'missing_values': defaultdict(int),
                    'data_types': defaultdict(set),
                    'min_length': defaultdict(lambda: float('inf')),
                    'max_length': defaultdict(int),
                }
                
                # Process rows
                uneven_rows = []
                problematic_rows_content = []
                
                for row_num, row in enumerate(csv_reader, start=2):  # Start from 2 to account for header
                    row_count += 1
                    
                    # Check row length compared to headers
                    if len(row) != len(headers):
                        uneven_rows.append((row_num, len(row)))
                        
                        # Store content of problematic rows for debugging
                        if len(problematic_rows_content) < 10:  # Limit to first 10 problematic rows
                            problematic_rows_content.append({
                                'row_num': row_num,
                                'expected': len(headers),
                                'actual': len(row),
                                'content': row[:min(len(row), len(headers) + 2)],  # Include a bit extra if available
                                'raw_content': ','.join(row)[:100] + ('...' if len(','.join(row)) > 100 else '')
                            })
                            
                        issues.append((f"Row {row_num} has {len(row)} fields, expected {len(headers)}", "Structure", row_num))
                        
                        # We'll still analyze available fields
                        if len(row) < len(headers):
                            row = row + [''] * (len(headers) - len(row))
                        else:
                            row = row[:len(headers)]
                    
                    # Analyze each field in the row
                    for i, value in enumerate(row):
                        if i < len(headers):
                            header = headers[i]
                            
                            # Check for missing values
                            if not value.strip():
                                column_stats['missing_values'][header] += 1
                            
                            # Infer data type
                            try:
                                int(value)
                                column_stats['data_types'][header].add('int')
                            except ValueError:
                                try:
                                    float(value)
                                    column_stats['data_types'][header].add('float')
                                except ValueError:
                                    column_stats['data_types'][header].add('string')
                            
                            # Track field length
                            field_length = len(value)
                            column_stats['min_length'][header] = min(column_stats['min_length'][header], field_length)
                            column_stats['max_length'][header] = max(column_stats['max_length'][header], field_length)
                
                # Finalize stats
                stats['row_count'] = row_count
                stats['column_stats'] = column_stats
                stats['uneven_rows'] = uneven_rows
                stats['problematic_rows'] = problematic_rows_content
                
                # Report on missing values
                for header, count in column_stats['missing_values'].items():
                    pct = (count / row_count) * 100
                    if pct > 0:
                        severity = "Warning" if pct > 10 else "Info"
                        issues.append((f"Column '{header}' has {count} missing values ({pct:.1f}%)", severity, seen_headers[header]))
                
                # Report on data type inconsistencies
                for header, types in column_stats['data_types'].items():
                    if len(types) > 1:
                        issues.append((f"Column '{header}' has mixed data types: {', '.join(types)}", "Warning", seen_headers[header]))
                
                # Report on field length variability
                for header in headers:
                    min_len = column_stats['min_length'][header]
                    max_len = column_stats['max_length'][header]
                    
                    if min_len == float('inf'):
                        min_len = 0
                    
                    if max_len > 0 and (max_len - min_len) > max_len * 0.5:
                        issues.append((f"Column '{header}' has highly variable field lengths (min={min_len}, max={max_len})", "Info", seen_headers[header]))
                
                # Check for uneven rows pattern
                if uneven_rows:
                    total_uneven = len(uneven_rows)
                    uneven_pct = (total_uneven / row_count) * 100
                    
                    # Group by actual field count
                    field_count_groups = defaultdict(int)
                    for _, count in uneven_rows:
                        field_count_groups[count] += 1
                    
                    field_count_summary = ", ".join([f"{count} fields: {instances} rows" 
                                                  for count, instances in sorted(field_count_groups.items())])
                    
                    severity = "Error" if uneven_pct > 1 else "Warning"
                    issues.append((f"File has {total_uneven} rows ({uneven_pct:.2f}%) with incorrect number of fields. {field_count_summary}", 
                                  severity, 0))
                    
                    # Special case for ArrayIndexOutOfBoundsException
                    if any(count < len(headers) for _, count in uneven_rows):
                        issues.append(("Some rows have fewer fields than headers, which can cause ArrayIndexOutOfBoundsException in Java", 
                                      "Error", 0))
                
            except StopIteration:
                issues.append(("File is empty or has no headers", "Error", 0))
        
        # Second pass: check for encoding and special character issues
        special_chars_by_column = defaultdict(set)
        with codecs.open(file_path, 'r', encoding=encoding, errors='replace') as f:
            line_num = 0
            raw_problematic_lines = []
            for line in f:
                line_num += 1
                
                # Check for control characters
                if re.search(r'[\x00-\x08\x0B\x0C\x0E-\x1F]', line):
                    issues.append((f"Line {line_num} contains control characters", "Warning", line_num))
                
                # Check for replacement character (encoding issues)
                if '\ufffd' in line:
                    issues.append((f"Line {line_num} has character encoding issues", "Error", line_num))
                    
                # Check for quoted fields with delimiter inside
                if delimiter in line and '"' in line:
                    quote_pattern = r'"[^"]*' + re.escape(delimiter) + r'[^"]*"'
                    if re.search(quote_pattern, line):
                        issues.append((f"Line {line_num} has quoted field(s) containing the delimiter", "Warning", line_num))
                
                # Check for non-ASCII characters and track them
                non_ascii_match = re.search(r'[^\x00-\x7F]', line)
                if non_ascii_match:
                    issues.append((f"Line {line_num} contains non-ASCII characters", "Warning", line_num))
                    
                    # Store the raw line for reference (limited to first 20)
                    if len(raw_problematic_lines) < 20:
                        raw_problematic_lines.append({
                            'line_num': line_num,
                            'content': line.strip()[:100] + ('...' if len(line.strip()) > 100 else ''),
                            'non_ascii': re.findall(r'[^\x00-\x7F]', line)
                        })
                        
                    # Try to identify which fields contain non-ASCII characters
                    try:
                        fields = line.strip().split(delimiter)
                        for i, field in enumerate(fields):
                            if re.search(r'[^\x00-\x7F]', field) and i < len(headers):
                                header_name = headers[i] if i < len(headers) else f"Column {i+1}"
                                special_chars = re.findall(r'[^\x00-\x7F]', field)
                                for char in special_chars:
                                    special_chars_by_column[header_name].add(char)
                    except Exception:
                        pass
        
        # Add special character analysis to stats
        stats['special_chars_by_column'] = {k: list(v) for k, v in special_chars_by_column.items()}
        stats['raw_problematic_lines'] = raw_problematic_lines
        
        # If we found columns with non-ASCII characters, add a specific issue about it
        if special_chars_by_column:
            columns_with_special = [
                f"{col} ({', '.join(chars)})" 
                for col, chars in special_chars_by_column.items()
            ]
            issues.append((
                f"Non-ASCII characters found in columns: {', '.join(columns_with_special)}. " +
                "This may cause Java ArrayIndexOutOfBoundsException if character encoding is mishandled.", 
                "Warning", 0
            ))
            
        return issues, stats
    
    except Exception as e:
        return [("Error validating file: " + str(e), "Error", 0)], {}

def format_report(file_path, issues, stats, verbose=False):
    """Format validation report as text"""
    report = []
    report.append(f"CSV Validation Report for: {os.path.basename(file_path)}")
    report.append(f"{'=' * 50}")
    
    # Basic statistics
    report.append("\nFile Statistics:")
    report.append(f"- Number of columns: {stats.get('header_count', 'unknown')}")
    report.append(f"- Number of data rows: {stats.get('row_count', 'unknown')}")
    
    # Delimiter information
    if 'delimiter_field_analysis' in stats:
        report.append("\nDelimiter Analysis:")
        delimiter_analysis = stats['delimiter_field_analysis']
        for delim, analysis in sorted(delimiter_analysis.items(), 
                                     key=lambda x: x[1]['consistency'], 
                                     reverse=True):
            delim_name = "tab" if delim == '\t' else "comma" if delim == ',' else "semicolon" if delim == ';' else "pipe"
            report.append(f"- '{delim}' ({delim_name}): {analysis['consistency']*100:.1f}% field count consistency")
            field_counts = sorted(analysis['counts'].items())
            report.append(f"  * Expected fields: {analysis['expected']}")
            report.append(f"  * Actual field counts: " + 
                         ", ".join([f"{count} fields: {instances} rows" for count, instances in field_counts]))
    
    # Issues by severity
    errors = [i for i in issues if i[1] == "Error"]
    warnings = [i for i in issues if i[1] == "Warning"]
    infos = [i for i in issues if i[1] == "Info"]
    
    report.append(f"\nIssues Found: {len(issues)}")
    report.append(f"- Errors: {len(errors)}")
    report.append(f"- Warnings: {len(warnings)}")
    report.append(f"- Info: {len(infos)}")
    
    # Group issues by type
    issue_types = defaultdict(list)
    for issue, severity, location in issues:
        issue_types[severity].append((issue, location))
    
    # Show errors first
    if errors:
        report.append("\nERRORS:")
        for issue, location in issue_types.get("Error", []):
            report.append(f"- {issue}")
    
    # Then warnings
    if warnings:
        report.append("\nWARNINGS:")
        for issue, location in issue_types.get("Warning", []):
            report.append(f"- {issue}")
    
    # Then informational
    if verbose and infos:
        report.append("\nINFO:")
        for issue, location in issue_types.get("Info", []):
            report.append(f"- {issue}")
    
    # Show problematic rows if available
    if 'problematic_rows' in stats and stats['problematic_rows']:
        report.append("\nProblematic Rows (Field Count Issues):")
        for row in stats['problematic_rows']:
            report.append(f"- Row {row['row_num']}: Expected {row['expected']} fields, found {row['actual']}")
            report.append(f"  Content: {', '.join(str(x) for x in row['content'])}")
            
    # Show special characters if found
    if 'special_chars_by_column' in stats and stats['special_chars_by_column']:
        report.append("\nNon-ASCII Characters by Column:")
        for col, chars in stats['special_chars_by_column'].items():
            report.append(f"- {col}: {', '.join(chars)}")
    
    # Column stats
    if verbose and 'column_stats' in stats:
        report.append("\nColumn Statistics:")
        col_stats = stats['column_stats']
        for header in col_stats['data_types'].keys():
            missing = col_stats['missing_values'].get(header, 0)
            missing_pct = (missing / stats['row_count']) * 100 if stats['row_count'] > 0 else 0
            types = ", ".join(col_stats['data_types'][header])
            min_len = col_stats['min_length'][header]
            max_len = col_stats['max_length'][header]
            
            if min_len == float('inf'):
                min_len = 0
                
            report.append(f"- {header}:")
            report.append(f"  * Types: {types}")
            report.append(f"  * Missing: {missing} ({missing_pct:.1f}%)")
            report.append(f"  * Length: min={min_len}, max={max_len}")
    
    # Debugging for Java ArrayIndexOutOfBoundsException
    report.append("\nPotential Causes for ArrayIndexOutOfBoundsException:")
    has_potential_causes = False
    
    # Check for rows with too few fields
    if 'uneven_rows' in stats and any(count < stats.get('header_count', 0) for _, count in stats['uneven_rows']):
        report.append("- Some rows have fewer fields than expected by the header")
        report.append("  This is a common cause of ArrayIndexOutOfBoundsException when code assumes all rows have the same number of fields")
        has_potential_causes = True
    
    # Check for encoding issues that might cause field parsing problems
    if any("encoding" in i[0].lower() for i in issues):
        report.append("- Character encoding issues detected")
        report.append("  This can cause field delimiters to be misinterpreted, resulting in incorrect field counts")
        has_potential_causes = True
    
    # Check for delimiter inconsistency
    if 'delimiter_field_analysis' in stats:
        best_delimiter = max(stats['delimiter_field_analysis'].keys(), 
                           key=lambda d: stats['delimiter_field_analysis'][d]['consistency'] 
                           if d in stats['delimiter_field_analysis'] else 0)
        
        if stats['delimiter_field_analysis'].get(best_delimiter, {}).get('consistency', 0) < 0.9:
            report.append("- No delimiter gives consistent field counts (best is only " +
                        f"{stats['delimiter_field_analysis'].get(best_delimiter, {}).get('consistency', 0)*100:.1f}% consistent)")
            report.append("  This suggests the file may have mixed delimiters or structural issues")
            has_potential_causes = True
    
    if not has_potential_causes:
        report.append("- No clear issues that would directly cause ArrayIndexOutOfBoundsException")
        report.append("  Check your Java code to ensure it properly handles variable-length rows and missing fields")
    
    # Recommendations
    report.append("\nRecommendations:")
    has_recommendations = False
    
    if any(i[1] == "Error" for i in issues):
        report.append("- Address all errors before attempting to use this file")
        has_recommendations = True
    
    if any("encoding" in i[0].lower() for i in issues):
        report.append("- Check file encoding and ensure it's consistent")
        report.append("  Use UTF-8 encoding in both your files and Java application")
        has_recommendations = True
    
    if any("uneven" in i[0].lower() or "incorrect number" in i[0].lower() for i in issues):
        report.append("- Fix rows with incorrect number of fields")
        report.append("  For Java applications, ensure all rows have the expected number of fields")
        has_recommendations = True
    
    if any("missing" in i[0].lower() for i in issues):
        report.append("- Consider filling in missing values or ensuring your parser can handle them")
        report.append("  In Java, always check if array indices exist before accessing them")
        has_recommendations = True
        
    if any("non-ASCII" in i[0].lower() for i in issues):
        report.append("- Ensure your Java application handles non-ASCII characters correctly:")
        report.append("  1. Use UTF-8 encoding when reading files")
        report.append("  2. Consider normalizing text with Normalizer class")
        report.append("  3. Use explicit encoding in FileReader/InputStreamReader")
        report.append("     Example: new InputStreamReader(new FileInputStream(file), \"UTF-8\")")
        has_recommendations = True
    
    if 'uneven_rows' in stats and stats.get('uneven_rows'):
        report.append("- To avoid ArrayIndexOutOfBoundsException in Java:")
        report.append("  1. Always check array length before accessing elements")
        report.append("  2. Use defensive programming: if (i < array.length) { access array[i] }")
        report.append("  3. Consider a more robust CSV parser library like Apache Commons CSV or OpenCSV")
        has_recommendations = True
    
    if not has_recommendations:
        report.append("- No specific recommendations - file appears mostly valid")
    
    return "\n".join(report)

def main():
    parser = argparse.ArgumentParser(description='Validate CSV files and identify potential parsing issues')
    parser.add_argument('file', help='CSV file to validate')
    parser.add_argument('--delimiter', help='Specify delimiter character')
    parser.add_argument('--encoding', default='utf-8', help='File encoding (default: utf-8)')
    parser.add_argument('--output', help='Write report to file instead of stdout')
    parser.add_argument('--verbose', action='store_true', help='Show more detailed information')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.file):
        print(f"Error: File '{args.file}' not found")
        sys.exit(1)
    
    delimiter = args.delimiter
    if delimiter:
        # Handle special cases like tab
        if delimiter == '\\t':
            delimiter = '\t'
    
    issues, stats = validate_csv(args.file, delimiter, args.encoding, args.verbose)
    report = format_report(args.file, issues, stats, args.verbose)
    
    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(report)
        print(f"Report written to {args.output}")
    else:
        print(report)

if __name__ == '__main__':
    main()
