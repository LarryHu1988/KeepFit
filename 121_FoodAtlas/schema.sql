PRAGMA foreign_keys = ON;
PRAGMA user_version = 1;

CREATE TABLE IF NOT EXISTS sources (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    version TEXT NOT NULL,
    url TEXT NOT NULL,
    license TEXT NOT NULL,
    commercial_use_authorized INTEGER NOT NULL CHECK (commercial_use_authorized IN (0,1)),
    retrieved_at TEXT NOT NULL,
    raw_sha256 TEXT NOT NULL,
    notes TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS foods (
    id TEXT PRIMARY KEY,
    source_id TEXT NOT NULL REFERENCES sources(id),
    source_food_id TEXT NOT NULL,
    name TEXT NOT NULL,
    name_zh TEXT,
    name_en TEXT,
    category TEXT,
    data_type TEXT NOT NULL,
    source_url TEXT NOT NULL,
    edible_percent REAL,
    calories_kcal REAL,
    protein_g REAL,
    fat_g REAL,
    carbs_g REAL,
    energy_method TEXT NOT NULL DEFAULT 'source',
    UNIQUE (source_id, source_food_id)
);
CREATE TABLE IF NOT EXISTS nutrients (
    food_id TEXT NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
    nutrient_id TEXT NOT NULL,
    name TEXT NOT NULL,
    unit TEXT NOT NULL,
    amount REAL,
    qualifier TEXT NOT NULL,
    raw_value TEXT NOT NULL,
    method TEXT NOT NULL,
    PRIMARY KEY (food_id, nutrient_id)
) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS portions (
    id TEXT PRIMARY KEY,
    food_id TEXT NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
    label TEXT NOT NULL,
    amount REAL NOT NULL CHECK (amount > 0),
    unit TEXT NOT NULL,
    gram_weight REAL NOT NULL CHECK (gram_weight > 0),
    basis TEXT NOT NULL,
    source_portion_id TEXT
);
CREATE TABLE IF NOT EXISTS aliases (
    food_id TEXT NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
    alias TEXT NOT NULL,
    language TEXT NOT NULL,
    provenance TEXT NOT NULL,
    PRIMARY KEY (food_id, alias)
) WITHOUT ROWID;
CREATE INDEX IF NOT EXISTS foods_source ON foods(source_id);
CREATE INDEX IF NOT EXISTS portions_food ON portions(food_id);
CREATE INDEX IF NOT EXISTS aliases_name ON aliases(alias);

CREATE VIEW IF NOT EXISTS portion_nutrition AS
SELECT f.id AS food_id, COALESCE(f.name_zh, f.name) AS name,
       f.name_en, f.source_id, p.id AS portion_id, p.label,
       p.amount, p.unit, p.gram_weight,
       p.gram_weight / p.amount AS grams_per_unit,
       f.calories_kcal * p.gram_weight / 100.0 AS calories_kcal,
       f.protein_g * p.gram_weight / 100.0 AS protein_g,
       f.fat_g * p.gram_weight / 100.0 AS fat_g,
       f.carbs_g * p.gram_weight / 100.0 AS carbs_g,
       f.calories_kcal * p.gram_weight / p.amount / 100.0 AS calories_per_unit_kcal,
       f.protein_g * p.gram_weight / p.amount / 100.0 AS protein_per_unit_g,
       f.fat_g * p.gram_weight / p.amount / 100.0 AS fat_per_unit_g,
       f.carbs_g * p.gram_weight / p.amount / 100.0 AS carbs_per_unit_g,
       p.basis, f.source_url, s.license, s.commercial_use_authorized
FROM foods f JOIN portions p ON p.food_id = f.id
JOIN sources s ON s.id = f.source_id;

CREATE VIEW IF NOT EXISTS commercial_foods AS
SELECT f.* FROM foods f JOIN sources s ON f.source_id = s.id
WHERE s.commercial_use_authorized = 1;

-- Supplemental raw labels do not share the normalized per-100g nutrient table.
CREATE TABLE IF NOT EXISTS food_metadata (
    food_id TEXT PRIMARY KEY REFERENCES foods(id) ON DELETE CASCADE,
    kind TEXT NOT NULL,
    barcode TEXT,
    brand TEXT,
    manufacturer TEXT,
    ingredients TEXT,
    net_content TEXT,
    storage TEXT,
    origin TEXT,
    basis_quantity REAL,
    basis_unit TEXT,
    basis_status TEXT NOT NULL,
    detail_status TEXT NOT NULL,
    portion_description TEXT,
    raw_json TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS food_metadata_barcode ON food_metadata(barcode);
CREATE TABLE IF NOT EXISTS label_nutrients (
    food_id TEXT NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
    nutrient_id TEXT NOT NULL,
    name TEXT NOT NULL,
    unit TEXT NOT NULL,
    amount REAL,
    qualifier TEXT NOT NULL,
    raw_value TEXT NOT NULL,
    PRIMARY KEY (food_id, nutrient_id)
) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS ingestion_jobs (
    id TEXT PRIMARY KEY,
    status TEXT NOT NULL,
    total INTEGER NOT NULL,
    completed INTEGER NOT NULL,
    failed INTEGER NOT NULL,
    updated_at TEXT NOT NULL,
    notes TEXT NOT NULL
);
