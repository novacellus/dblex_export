-- Enhanced SQLite schema with entity types

-- Entity types table
CREATE TABLE entity_types (
    type_id INTEGER PRIMARY KEY AUTOINCREMENT,
    type_name TEXT UNIQUE
);

-- Insert common entity types
INSERT INTO entity_types (type_name) VALUES ('entry');
INSERT INTO entity_types (type_name) VALUES ('sense');
-- Add more types as needed

-- Entries table (contains IDs and their types)
CREATE TABLE entities (
    entity_id TEXT PRIMARY KEY,
    type_id INTEGER,
    FOREIGN KEY (type_id) REFERENCES entity_types(type_id)
);

-- Attributes table (defines all possible attributes)
CREATE TABLE attributes (
    attribute_id INTEGER PRIMARY KEY AUTOINCREMENT,
    attribute_name TEXT UNIQUE
);

-- Values table (stores all values with their relationship to entities and attributes)
CREATE TABLE entity_values (
    value_id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_id TEXT,
    attribute_id INTEGER,
    value_text TEXT,
    FOREIGN KEY (entity_id) REFERENCES entities(entity_id),
    FOREIGN KEY (attribute_id) REFERENCES attributes(attribute_id)
);

CREATE TABLE entity_relationships (
    relationship_id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_entity_id TEXT,
    target_entity_id TEXT,
    relationship_type TEXT,
    FOREIGN KEY (source_entity_id) REFERENCES entities(entity_id),
    FOREIGN KEY (target_entity_id) REFERENCES entities(entity_id)
);

-- Add indexes for performance
CREATE INDEX idx_entity_values_entity_id ON entity_values(entity_id);
CREATE INDEX idx_entity_values_attribute_id ON entity_values(attribute_id);
CREATE INDEX idx_entity_values_value_text ON entity_values(value_text);
