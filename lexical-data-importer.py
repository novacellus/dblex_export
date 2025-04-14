from datetime import datetime
def import_with_entity_mapping(cursor, csv_file, entity_mappings, delimiter='\t', 
                                multi_value_columns=None, split_pattern=r'[,;\s]+', 
                                source_id=None, resource_id=None, **kwargs):
    """
    Import a CSV file with complex entity mappings
    
    Parameters:
    - cursor: SQLite cursor
    - csv_file: Path to CSV file
    - entity_mappings: Dictionary defining how columns map to entities
    - delimiter: CSV delimiter (default: tab)
    - multi_value_columns: List of column names that may have multiple values
    - split_pattern: Regular expression pattern for splitting multi-value fields
    """
    # Set default for multi-value columns if None
    if multi_value_columns is None:
        multi_value_columns = []
        
    # Cache for entity type IDs
    entity_type_ids = {}
    
    with open(csv_file, 'r', encoding='utf-8') as f:
        reader = csv.reader(f, delimiter=delimiter)
        headers = next(reader)
        
        # Get all attribute IDs in advance
        attribute_ids = get_attribute_ids(cursor, headers)
        
        # Process each row
        for row in reader:
            if not row:
                continue
                
            # Convert row to a dictionary
            row_dict = {headers[i]: value for i, value in enumerate(row) if i < len(headers)}
            
            # Dictionary to store created entity IDs for this row
            created_entities = {}
            
            # First pass: Create all entities
            for entity_type, mapping in entity_mappings.items():
                # Check if this entity has an ID in this row
                id_column = mapping.get('id_column')
                if not id_column or id_column not in row_dict or not row_dict[id_column]:
                    continue
                    
                entity_id = row_dict[id_column]
                
                # Get entity type ID (or create if not exists)
                if entity_type not in entity_type_ids:
                    cursor.execute('SELECT type_id FROM entity_types WHERE type_name = ?', (entity_type,))
                    result = cursor.fetchone()
                    if result:
                        entity_type_ids[entity_type] = result[0]
                    else:
                        cursor.execute('INSERT INTO entity_types (type_name) VALUES (?)', (entity_type,))
                        entity_type_ids[entity_type] = cursor.lastrowid
                
                # Insert entity
                cursor.execute(
                    'INSERT OR IGNORE INTO entities (entity_id, type_id) VALUES (?, ?)',
                    (entity_id, entity_type_ids[entity_type])
                )
                
                # Link entity to source and resource if IDs are provided
                if source_id is not None and resource_id is not None:
                    cursor.execute('''
                    INSERT OR IGNORE INTO entity_source_links 
                    (entity_id, source_id, resource_id) 
                    VALUES (?, ?, ?)
                    ''', (entity_id, source_id, resource_id))
                
                # Store entity ID for potential relationship creation
                created_entities[entity_type] = entity_id
                
                # Process entity attributes
                columns = mapping.get('columns', [])
                for column in columns:
                    if column in row_dict and row_dict[column]:
                        # Check if this is a multi-value column
                        if column in multi_value_columns:
                            values = split_values(row_dict[column], split_pattern)
                            if not values:
                                values = [row_dict[column]]
                        else:
                            values = [row_dict[column]]
                        
                        # Insert each value
                        for value in values:
                            cursor.execute(
                                'INSERT INTO entity_values (entity_id, attribute_id, value_text) VALUES (?, ?, ?)',
                                (entity_id, attribute_ids[column], value)
                            )
            
            # Second pass: Create relationships between entities (only if relationships are defined)
            for entity_type, mapping in entity_mappings.items():
                # Skip if this entity wasn't created
                if entity_type not in created_entities:
                    continue
                    
                source_entity_id = created_entities[entity_type]
                
                # Process explicit relationships defined in the mapping
                relationships = mapping.get('relationships', {})
                for rel_column, rel_info in relationships.items():
                    if rel_column in row_dict and row_dict[rel_column]:
                        target_entity_id = row_dict[rel_column]
                        
                        # Get relationship type, with fallback
                        relationship_type = rel_info.get('relationship_name', f'has_{rel_column}')
                        
                        # Optional: check if there's a specific parent entity type
                        parent_entity_type = rel_info.get('parent_entity_type')
                        
                        # Insert relationship
                        cursor.execute(
                            'INSERT INTO entity_relationships (source_entity_id, target_entity_id, relationship_type) VALUES (?, ?, ?)',
                            (source_entity_id, target_entity_id, relationship_type)
                        )

import sqlite3
import csv
import re
import os
import json
import argparse
from pathlib import Path

def create_schema(cursor):
    """Create the database schema if it doesn't exist"""
    # Entity types table
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS entity_types (
        type_id INTEGER PRIMARY KEY AUTOINCREMENT,
        type_name TEXT UNIQUE
    )
    ''')

    # Try to insert common entity types
    for entity_type in ['entry', 'sense', 'definition']:
        cursor.execute('INSERT OR IGNORE INTO entity_types (type_name) VALUES (?)', (entity_type,))

    # Entities table
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS entities (
        entity_id TEXT PRIMARY KEY,
        type_id INTEGER,
        FOREIGN KEY (type_id) REFERENCES entity_types(type_id)
    )
    ''')

    # Attributes table
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS attributes (
        attribute_id INTEGER PRIMARY KEY AUTOINCREMENT,
        attribute_name TEXT UNIQUE
    )
    ''')

    # Values table
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS entity_values (
        value_id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_id TEXT,
        attribute_id INTEGER,
        value_text TEXT,
        FOREIGN KEY (entity_id) REFERENCES entities(entity_id),
        FOREIGN KEY (attribute_id) REFERENCES attributes(attribute_id)
    )
    ''')
    
    # Entity relationships table
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS entity_relationships (
        relationship_id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_entity_id TEXT,
        target_entity_id TEXT,
        relationship_type TEXT,
        FOREIGN KEY (source_entity_id) REFERENCES entities(entity_id),
        FOREIGN KEY (target_entity_id) REFERENCES entities(entity_id)
    )
    ''')
    
    # New table for lexical resources
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS lexical_resources (
        resource_id INTEGER PRIMARY KEY AUTOINCREMENT,
        resource_name TEXT UNIQUE,
        resource_abbreviation TEXT,
        description TEXT,
        metadata TEXT  -- JSON string for additional metadata
    )
    ''')

    # New table for data sources
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS data_sources (
        source_id INTEGER PRIMARY KEY AUTOINCREMENT,
        filename TEXT,
        import_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        lexical_resource_id INTEGER,
        additional_metadata TEXT,  -- JSON string for flexibility
        FOREIGN KEY (lexical_resource_id) REFERENCES lexical_resources(resource_id)
    )
    ''')
    
    # New table to link entities to their data sources and resources
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS entity_source_links (
        link_id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_id TEXT,
        source_id INTEGER,
        resource_id INTEGER,
        FOREIGN KEY (entity_id) REFERENCES entities(entity_id),
        FOREIGN KEY (source_id) REFERENCES data_sources(source_id),
        FOREIGN KEY (resource_id) REFERENCES lexical_resources(resource_id),
        UNIQUE(entity_id, source_id, resource_id)
    )
    ''')

    # Add indexes
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_entity_values_entity_id ON entity_values(entity_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_entity_values_attribute_id ON entity_values(attribute_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_entity_values_value_text ON entity_values(value_text)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_entity_relationships_source ON entity_relationships(source_entity_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_entity_relationships_target ON entity_relationships(target_entity_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_entity_relationships_type ON entity_relationships(relationship_type)')

def split_values(text, split_pattern=r'[,;\s]+'):
    """Split a text value into multiple values based on separators"""
    if not text or text.strip() == '':
        return []
    return [val.strip() for val in re.split(split_pattern, text) if val.strip()]

def get_attribute_ids(cursor, attribute_names):
    """Get or create attribute IDs for the given names"""
    attribute_ids = {}
    for attr_name in attribute_names:
        # Try to get existing attribute ID
        cursor.execute('SELECT attribute_id FROM attributes WHERE attribute_name = ?', (attr_name,))
        result = cursor.fetchone()
        
        if result:
            attribute_ids[attr_name] = result[0]
        else:
            # Create new attribute
            cursor.execute('INSERT INTO attributes (attribute_name) VALUES (?)', (attr_name,))
            attribute_ids[attr_name] = cursor.lastrowid
    
    return attribute_ids

def import_csv(cursor, csv_file, id_column, delimiter='\t', 
               multi_value_columns=None, split_pattern=r'[,;\s]+', 
               entity_type='entry', **kwargs):
    """
    Import a CSV file into the EAV database
    
    Parameters:
    - cursor: SQLite cursor
    - csv_file: Path to CSV file
    - id_column: Column name or index to use as entity_id
    - delimiter: CSV delimiter (default: tab)
    - multi_value_columns: List of column names that may have multiple values
    - split_pattern: Regular expression pattern for splitting multi-value fields
    - entity_type: Type of entity being imported (entry, sense, etc.)
    """
    # Set default for multi-value columns if None
    if multi_value_columns is None:
        multi_value_columns = []
    
    # Get entity type ID
    cursor.execute('SELECT type_id FROM entity_types WHERE type_name = ?', (entity_type,))
    result = cursor.fetchone()
    if not result:
        cursor.execute('INSERT INTO entity_types (type_name) VALUES (?)', (entity_type,))
        type_id = cursor.lastrowid
    else:
        type_id = result[0]
    
    with open(csv_file, 'r', encoding='utf-8') as f:
        # Check if file has headers
        first_line = f.readline().strip()
        f.seek(0)  # Reset file pointer
        
        reader = csv.reader(f, delimiter=delimiter)
        headers = next(reader)
        
        # Get attribute IDs
        attribute_ids = get_attribute_ids(cursor, headers)
        
        # Process each row
        for row in reader:
            if not row:
                continue
                
            # Get entity_id (either by index or column name)
            if isinstance(id_column, int):
                entity_id = row[id_column]
            else:
                try:
                    id_index = headers.index(id_column)
                    entity_id = row[id_index]
                except ValueError:
                    raise ValueError(f"Column '{id_column}' not found in CSV headers")
            
            # Insert or ignore the entity
            cursor.execute('INSERT OR IGNORE INTO entities (entity_id, type_id) VALUES (?, ?)', 
                          (entity_id, type_id))
            
            # Process each column
            for i, value in enumerate(row):
                if i >= len(headers):
                    continue
                    
                attr_name = headers[i]
                attr_id = attribute_ids[attr_name]
                
                # Check if this is a multi-value column
                if attr_name in multi_value_columns and value:
                    values = split_values(value, split_pattern)
                    # If split returned nothing, use the original value
                    if not values:
                        values = [value]
                else:
                    values = [value] if value else []
                
                # Insert each value
                for val in values:
                    cursor.execute('''
                    INSERT INTO entity_values (entity_id, attribute_id, value_text)
                    VALUES (?, ?, ?)
                    ''', (entity_id, attr_id, val))

def import_files(db_path, file_path, **kwargs):
    # Extract new parameters
    resource_name = kwargs.pop('resource_name', None)
    resource_abbreviation = kwargs.pop('resource_abbreviation', None)
    resource_description = kwargs.pop('resource_description', None)
    resource_metadata = kwargs.pop('resource_metadata', None)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Create schema (now includes new tables)
    create_schema(cursor)
    
    # Determine files to import
    path = Path(file_path)
    
    if path.is_dir():
        csv_files = list(path.glob('*.csv'))
    elif '*' in file_path:
        parent_dir = Path(os.path.dirname(file_path) or '.')
        pattern = os.path.basename(file_path)
        csv_files = list(parent_dir.glob(pattern))
    elif path.is_file():
        csv_files = [path]
    else:
        raise FileNotFoundError(f"No files found matching {file_path}")
    
    # Get or create lexical resource
    resource_id = get_or_create_lexical_resource(
        cursor, 
        resource_name, 
        resource_abbreviation, 
        resource_description, 
        resource_metadata
    )
    
    # Process each file
    for csv_file in csv_files:
        print(f"Importing {csv_file}...")
        
        # Record data source
        cursor.execute('''
            INSERT INTO data_sources 
            (filename, lexical_resource_id, additional_metadata) 
            VALUES (?, ?, ?)
        ''', (str(csv_file), resource_id, json.dumps({
            'import_timestamp': datetime.now().isoformat(),
            'original_path': str(csv_file.resolve())
        })))
        
        # Get the source_id for potential further use
        source_id = cursor.lastrowid
        
        # Existing import logic
        if kwargs.get('entity_mapping'):
            import_with_entity_mapping(
                cursor, 
                csv_file, 
                kwargs['entity_mapping'], 
                source_id=source_id,
                resource_id=resource_id,
                **{k:v for k,v in kwargs.items() if k != 'entity_mapping'}
            )
        else:
            import_csv(cursor, csv_file, **{**kwargs, 'source_id': source_id, 'resource_id': resource_id})
        print(f"Imported {csv_file} as part of {resource_name or 'Unknown Resource'}")
    

    
    # Commit and close
    conn.commit()
    conn.close()
    
    print(f"Imported {len(csv_files)} files into {db_path}")

def get_or_create_lexical_resource(cursor, resource_name=None, abbreviation=None, description=None, metadata=None):
    """
    Get existing or create a new lexical resource entry
    
    Parameters:
    - cursor: SQLite cursor
    - resource_name: Full name of the lexical resource
    - abbreviation: Short identifier for the resource
    - description: Optional description
    - metadata: Optional additional metadata as dictionary
    
    Returns: resource_id
    """
    if not resource_name and not abbreviation:
        # Default if no information provided
        resource_name = 'Unknown Lexical Resource'
        abbreviation = 'UNKNOWN'
    
    # Convert metadata to JSON string if it's a dictionary
    metadata_json = json.dumps(metadata) if isinstance(metadata, dict) else metadata

    # Try to find existing resource
    cursor.execute('''
        SELECT resource_id FROM lexical_resources 
        WHERE resource_name = ? OR resource_abbreviation = ?
    ''', (resource_name, abbreviation))
    result = cursor.fetchone()
    
    if result:
        return result[0]
    
    # Create new resource
    cursor.execute('''
        INSERT INTO lexical_resources 
        (resource_name, resource_abbreviation, description, metadata) 
        VALUES (?, ?, ?, ?)
    ''', (resource_name, abbreviation, description, metadata_json))
    
    return cursor.lastrowid
def main():
    parser = argparse.ArgumentParser(description='Import CSV data into SQLite EAV database')
    
    parser.add_argument('--db', required=True, help='SQLite database file')
    parser.add_argument('--input', required=True, 
                        help='Input file, directory, or pattern (e.g., "data/*.csv")')
    
    # Entity mapping or single entity parameters
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--entity-mapping', help='JSON file with entity mapping definitions')
    group.add_argument('--id-column', help='Column name to use as entity_id (e.g., "entry_id", "sense_id")')
    
    parser.add_argument('--entity-type', 
                        help='Type of entity being imported (required when using --id-column)')
    parser.add_argument('--delimiter', default='\t', help='CSV delimiter')
    parser.add_argument('--multi-value-columns', default='', 
                        help='Comma-separated list of columns that may have multiple values')
    parser.add_argument('--split-pattern', default=r'[,;\s]+', 
                        help='Regex pattern for splitting multi-value fields')
    
    # New optional arguments for resource metadata
    parser.add_argument('--resource-name', help='Full name of the lexical resource')
    parser.add_argument('--resource-abbr', help='Abbreviation for the lexical resource')
    parser.add_argument('--resource-desc', help='Description of the lexical resource')
    
    args = parser.parse_args()
    
    # Validate arguments
    if args.id_column and not args.entity_type:
        parser.error("--entity-type is required when using --id-column")
    
    # Process id_column
    id_column = None
    if args.id_column:
        # Try to convert id_column to int if it's a number
        try:
            id_column = int(args.id_column)
        except ValueError:
            id_column = args.id_column
    
    # Split multi-value columns
    multi_value_columns = [col.strip() for col in args.multi_value_columns.split(',')] if args.multi_value_columns else []
    
    import_files(
        args.db, 
        args.input, 
        id_column=id_column,
        delimiter=args.delimiter,
        multi_value_columns=multi_value_columns,
        split_pattern=args.split_pattern,
        entity_type=args.entity_type,
        entity_mapping=json.load(open(args.entity_mapping)) if args.entity_mapping else None,
        resource_name=args.resource_name,
        resource_abbreviation=args.resource_abbr,
        resource_description=args.resource_desc
    )

if __name__ == '__main__':
    main()
