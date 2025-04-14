#!/usr/bin/env python3
"""
SQLite to PostgreSQL Migration Script

This script migrates data from an SQLite database to PostgreSQL.
It handles schema conversion and data transfer between the two databases.

Requirements:
- psycopg2
- sqlite3 (Python standard library)
"""

import sqlite3
import psycopg2
import sys
import re
import argparse
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

def get_sqlite_tables(sqlite_cursor):
    """Get all table names from SQLite database"""
    sqlite_cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
    return [table[0] for table in sqlite_cursor.fetchall()]

def get_sqlite_schema(sqlite_cursor, table):
    """Get schema for a specific table from SQLite"""
    sqlite_cursor.execute(f"PRAGMA table_info({table});")
    return sqlite_cursor.fetchall()

def sqlite_type_to_postgres(sqlite_type):
    """Convert SQLite data type to PostgreSQL data type"""
    sqlite_type = sqlite_type.upper()
    
    # Type mapping
    type_map = {
        'INTEGER': 'INTEGER',
        'INT': 'INTEGER',
        'TINYINT': 'SMALLINT',
        'SMALLINT': 'SMALLINT',
        'MEDIUMINT': 'INTEGER',
        'BIGINT': 'BIGINT',
        'UNSIGNED BIG INT': 'BIGINT',
        'INT2': 'SMALLINT',
        'INT8': 'BIGINT',
        'TEXT': 'TEXT',
        'CLOB': 'TEXT',
        'CHARACTER': 'CHARACTER',
        'VARCHAR': 'VARCHAR',
        'VARYING CHARACTER': 'VARCHAR',
        'NCHAR': 'CHAR',
        'NATIVE CHARACTER': 'CHAR',
        'NVARCHAR': 'VARCHAR',
        'REAL': 'REAL',
        'DOUBLE': 'DOUBLE PRECISION',
        'DOUBLE PRECISION': 'DOUBLE PRECISION',
        'FLOAT': 'REAL',
        'NUMERIC': 'NUMERIC',
        'DECIMAL': 'DECIMAL',
        'BOOLEAN': 'BOOLEAN',
        'DATE': 'DATE',
        'DATETIME': 'TIMESTAMP',
        'TIMESTAMP': 'TIMESTAMP',
        'BLOB': 'BYTEA'
    }
    
    # Handle types with length specification like VARCHAR(255)
    match = re.match(r'(\w+)\((\d+)\)', sqlite_type)
    if match:
        base_type = match.group(1).upper()
        length = match.group(2)
        
        if base_type in type_map:
            pg_type = type_map[base_type]
            return f"{pg_type}({length})"
        
    # Handle simple types
    for sqlite_pattern, pg_type in type_map.items():
        if sqlite_pattern in sqlite_type:
            return pg_type
            
    # Default to TEXT if type is unknown
    return 'TEXT'

def create_postgres_table(pg_cursor, table, schema):
    """Create table in PostgreSQL based on SQLite schema"""
    columns = []
    primary_keys = []
    
    for col in schema:
        col_id, col_name, col_type, not_null, default_value, is_pk = col
        
        pg_type = sqlite_type_to_postgres(col_type)
        column_def = f'"{col_name}" {pg_type}'
        
        if not_null:
            column_def += ' NOT NULL'
            
        if default_value is not None:
            # Handle default values appropriately for PostgreSQL
            if default_value.upper() == 'CURRENT_TIMESTAMP':
                column_def += ' DEFAULT CURRENT_TIMESTAMP'
            elif pg_type in ['INTEGER', 'BIGINT', 'SMALLINT', 'REAL', 'DOUBLE PRECISION', 'NUMERIC', 'DECIMAL']:
                column_def += f' DEFAULT {default_value}'
            else:
                column_def += f" DEFAULT '{default_value}'"
                
        columns.append(column_def)
        
        if is_pk:
            primary_keys.append(f'"{col_name}"')
    
    # Create the table
    create_query = f'CREATE TABLE IF NOT EXISTS "{table}" (\n    '
    create_query += ',\n    '.join(columns)
    
    # Add primary key constraint if there are primary keys
    if primary_keys:
        create_query += f',\n    PRIMARY KEY ({", ".join(primary_keys)})'
        
    create_query += '\n);'
    
    pg_cursor.execute(create_query)
    
    return create_query

def copy_table_data(sqlite_cursor, pg_cursor, table):
    """Copy data from SQLite table to PostgreSQL table"""
    # Get column names from sqlite
    sqlite_cursor.execute(f"PRAGMA table_info({table});")
    columns = [col[1] for col in sqlite_cursor.fetchall()]
    columns_str = ', '.join([f'"{col}"' for col in columns])
    
    # Get data from SQLite
    sqlite_cursor.execute(f"SELECT * FROM {table};")
    rows = sqlite_cursor.fetchall()
    
    if not rows:
        print(f"Table {table} is empty, skipping data transfer")
        return 0
    
    # Prepare the insert statement
    placeholders = ', '.join(['%s'] * len(columns))
    insert_query = f'INSERT INTO "{table}" ({columns_str}) VALUES ({placeholders});'
    
    # Insert data in batches
    batch_size = 1000
    count = 0
    
    for i in range(0, len(rows), batch_size):
        batch = rows[i:i+batch_size]
        pg_cursor.executemany(insert_query, batch)
        count += len(batch)
        print(f"Inserted {count}/{len(rows)} rows into {table}")
    
    return count

def migrate_foreign_keys(sqlite_cursor, pg_cursor):
    """Migrate foreign key constraints from SQLite to PostgreSQL"""
    sqlite_cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
    tables = [table[0] for table in sqlite_cursor.fetchall()]
    
    fk_count = 0
    
    for table in tables:
        sqlite_cursor.execute(f"PRAGMA foreign_key_list({table});")
        foreign_keys = sqlite_cursor.fetchall()
        
        for fk in foreign_keys:
            fk_id, seq, ref_table, from_col, to_col, on_update, on_delete, match = fk
            
            fk_name = f"fk_{table}_{from_col}_to_{ref_table}_{to_col}"
            
            # Create foreign key constraint
            fk_query = f'ALTER TABLE "{table}" ADD CONSTRAINT "{fk_name}" '
            fk_query += f'FOREIGN KEY ("{from_col}") REFERENCES "{ref_table}" ("{to_col}")'
            
            # Add ON DELETE action if specified
            if on_delete != 'NO ACTION':
                fk_query += f' ON DELETE {on_delete}'
                
            # Add ON UPDATE action if specified
            if on_update != 'NO ACTION':
                fk_query += f' ON UPDATE {on_update}'
                
            fk_query += ';'
            
            try:
                pg_cursor.execute(fk_query)
                fk_count += 1
                print(f"Created foreign key: {fk_name}")
            except psycopg2.Error as e:
                print(f"Error creating foreign key {fk_name}: {e}")
    
    return fk_count

def migrate_indexes(sqlite_cursor, pg_cursor):
    """Migrate indexes from SQLite to PostgreSQL"""
    sqlite_cursor.execute(
        "SELECT name, tbl_name, sql FROM sqlite_master "
        "WHERE type='index' AND sql IS NOT NULL AND name NOT LIKE 'sqlite_%';"
    )
    indexes = sqlite_cursor.fetchall()
    
    idx_count = 0
    
    for idx_name, table, sql in indexes:
        # Skip indexes for primary keys as they're already created
        if idx_name.startswith('sqlite_autoindex_'):
            continue
            
        # Parse the SQLite index to extract fields
        match = re.search(r'CREATE\s+(?:UNIQUE\s+)?INDEX\s+(?:\w+\s+)?ON\s+\w+\s*\(([^)]+)\)', sql, re.IGNORECASE)
        if match:
            columns = match.group(1)
            is_unique = 'UNIQUE' in sql.upper()
            
            # Create index in PostgreSQL
            pg_idx_query = f"CREATE {'UNIQUE ' if is_unique else ''}INDEX "
            pg_idx_query += f'"{idx_name}" ON "{table}" ({columns});'
            
            try:
                pg_cursor.execute(pg_idx_query)
                idx_count += 1
                print(f"Created index: {idx_name}")
            except psycopg2.Error as e:
                print(f"Error creating index {idx_name}: {e}")
    
    return idx_count

def main():
    parser = argparse.ArgumentParser(description='Migrate SQLite database to PostgreSQL')
    parser.add_argument('sqlite_db', help='Path to SQLite database file')
    parser.add_argument('pg_dbname', help='PostgreSQL database name')
    parser.add_argument('--pg-user', help='PostgreSQL username', default='postgres')
    parser.add_argument('--pg-password', help='PostgreSQL password')
    parser.add_argument('--pg-host', help='PostgreSQL host', default='localhost')
    parser.add_argument('--pg-port', help='PostgreSQL port', default='5432')
    parser.add_argument('--drop-existing', action='store_true', help='Drop existing PostgreSQL database')
    
    args = parser.parse_args()
    
    # Connect to SQLite database
    try:
        sqlite_conn = sqlite3.connect(args.sqlite_db)
        sqlite_cursor = sqlite_conn.cursor()
        print(f"Connected to SQLite database: {args.sqlite_db}")
    except sqlite3.Error as e:
        print(f"SQLite error: {e}")
        return 1
    
    # Check if PostgreSQL database exists and create if needed
    try:
        # Connect to PostgreSQL server to check if database exists
        conn_string = f"host={args.pg_host} port={args.pg_port} user={args.pg_user}"
        if args.pg_password:
            conn_string += f" password={args.pg_password}"
            
        pg_server_conn = psycopg2.connect(f"{conn_string} dbname=postgres")
        pg_server_conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        pg_server_cursor = pg_server_conn.cursor()
        
        # Check if database exists
        pg_server_cursor.execute("SELECT 1 FROM pg_database WHERE datname = %s;", (args.pg_dbname,))
        db_exists = pg_server_cursor.fetchone() is not None
        
        if db_exists:
            if args.drop_existing:
                print(f"Dropping existing database: {args.pg_dbname}")
                pg_server_cursor.execute(f'DROP DATABASE "{args.pg_dbname}";')
                db_exists = False
            else:
                print(f"Database '{args.pg_dbname}' already exists. Use --drop-existing to recreate it.")
                return 1
                
        if not db_exists:
            print(f"Creating PostgreSQL database: {args.pg_dbname}")
            pg_server_cursor.execute(f'CREATE DATABASE "{args.pg_dbname}";')
            
        pg_server_conn.close()
        
    except psycopg2.Error as e:
        print(f"PostgreSQL error: {e}")
        return 1
    
    # Connect to the PostgreSQL database
    try:
        pg_conn = psycopg2.connect(f"{conn_string} dbname={args.pg_dbname}")
        pg_conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        pg_cursor = pg_conn.cursor()
        print(f"Connected to PostgreSQL database: {args.pg_dbname}")
    except psycopg2.Error as e:
        print(f"PostgreSQL error: {e}")
        return 1
    
    # Get tables from SQLite
    tables = get_sqlite_tables(sqlite_cursor)
    print(f"Found {len(tables)} tables in SQLite database")
    
    # Create tables in PostgreSQL
    for table in tables:
        print(f"Processing table: {table}")
        schema = get_sqlite_schema(sqlite_cursor, table)
        create_query = create_postgres_table(pg_cursor, table, schema)
        print(f"Created table: {table}")
    
    # Copy data
    total_rows = 0
    for table in tables:
        rows = copy_table_data(sqlite_cursor, pg_cursor, table)
        total_rows += rows
        print(f"Copied {rows} rows from table {table}")
    
    # Create foreign keys
    fk_count = migrate_foreign_keys(sqlite_cursor, pg_cursor)
    print(f"Created {fk_count} foreign key constraints")
    
    # Create indexes
    idx_count = migrate_indexes(sqlite_cursor, pg_cursor)
    print(f"Created {idx_count} indexes")
    
    # Close connections
    sqlite_conn.close()
    pg_conn.close()
    
    print(f"Migration completed successfully!")
    print(f"Total {len(tables)} tables, {total_rows} rows, {fk_count} foreign keys, and {idx_count} indexes migrated.")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
