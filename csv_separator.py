#!/usr/bin/env python3
"""
Row Expander for Multi-Value Columns

This script processes tab-delimited files containing multi-value columns
by creating separate rows for each value within the specified columns.

Usage:
    python row_expander.py input.tsv output.tsv --separator ','
    python row_expander.py input.tsv output.tsv --split-cols 5,6 --separator ','

Arguments:
    input_file:   Path to the input tab-delimited file
    output_file:  Path to the output tab-delimited file
    --split-cols: Comma-separated list of zero-based indices of columns to split (optional)
                  If not provided, all columns except column 0 will be checked for splitting
    --separator:  Character that separates multiple values (default: ',')
    --verbose:    Print verbose output for debugging
"""

import argparse
import sys

def parse_args():
    parser = argparse.ArgumentParser(description="Create separate rows for multi-value fields")
    parser.add_argument("input_file", help="Input file path")
    parser.add_argument("output_file", help="Output file path")
    parser.add_argument("--split-cols", 
                        help="Comma-separated list of column indices to split (optional)")
    parser.add_argument("--separator", default=",", help="Value separator (default: ',')")
    parser.add_argument("--verbose", action="store_true", help="Print verbose output")
    return parser.parse_args()

def main():
    args = parse_args()
    
    # Parse columns to split if provided
    explicit_split_cols = []
    if args.split_cols:
        explicit_split_cols = [int(col.strip()) for col in args.split_cols.split(',')]
    
    try:
        # Read the header and data
        lines = []
        
        with open(args.input_file, 'r', encoding='utf-8') as infile:
            lines = [line.rstrip('\n') for line in infile]
        
        if not lines:
            print("Input file is empty")
            return
        
        # Get header and determine columns to check for splitting
        header = lines[0].split('\t')
        
        # If no explicit columns provided, we'll check all columns except column 0
        auto_detect = not explicit_split_cols
        
        if auto_detect:
            # We'll detect which columns actually need splitting by scanning the file
            columns_with_separator = set()
            
            # Scan all data rows to find columns with the separator
            for line_num, line in enumerate(lines[1:], 2):
                row = line.split('\t')
                for col_idx in range(1, len(row)):  # Skip column 0
                    if col_idx < len(row) and args.separator in row[col_idx]:
                        columns_with_separator.add(col_idx)
            
            split_cols = sorted(list(columns_with_separator))
            
            if args.verbose:
                print(f"Auto-detected columns that need splitting: {split_cols}")
        else:
            split_cols = explicit_split_cols
        
        # Write the output file
        with open(args.output_file, 'w', encoding='utf-8') as outfile:
            # Write header (unchanged)
            outfile.write(lines[0] + '\n')
            
            # Process data rows
            for line_num, line in enumerate(lines[1:], 2):  # Start at 2 to account for header
                row = line.split('\t')
                
                # Check if any of the specified columns need splitting in this row
                need_splitting = False
                for col_idx in split_cols:
                    if col_idx < len(row) and args.separator in row[col_idx]:
                        need_splitting = True
                        break
                
                if not need_splitting:
                    # If no splitting needed, write the row as is
                    outfile.write(line + '\n')
                    continue
                
                # For rows that need splitting, we'll create multiple output rows
                # First, collect all values for columns that need splitting
                split_values = {}
                for col_idx in split_cols:
                    if col_idx < len(row) and row[col_idx]:
                        if args.separator in row[col_idx]:
                            split_values[col_idx] = [v.strip() for v in row[col_idx].split(args.separator)]
                        else:
                            split_values[col_idx] = [row[col_idx]]
                    else:
                        split_values[col_idx] = [""]
                
                # Calculate how many rows we need to create
                max_values = max([len(values) for values in split_values.values()])
                
                if args.verbose:
                    print(f"Line {line_num}: Creating {max_values} rows")
                    for col_idx, values in split_values.items():
                        print(f"  Column {col_idx}: {values}")
                
                # Create each output row
                for i in range(max_values):
                    new_row = row.copy()
                    
                    # Update the split columns with their respective values
                    for col_idx in split_cols:
                        if col_idx < len(new_row):
                            if i < len(split_values[col_idx]):
                                new_row[col_idx] = split_values[col_idx][i]
                            else:
                                new_row[col_idx] = ""
                    
                    # Write the new row
                    outfile.write('\t'.join(new_row) + '\n')
        
        print(f"Successfully processed {args.input_file} to {args.output_file}")
        if auto_detect:
            print(f"Auto-detected and split columns: {split_cols}")
        else:
            print(f"Split columns: {split_cols}")
        
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        if args.verbose:
            import traceback
            traceback.print_exc(file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
