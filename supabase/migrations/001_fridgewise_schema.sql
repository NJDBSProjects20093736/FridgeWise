-- ThriftyChef — Supabase / Postgres schema
-- Run in Supabase SQL Editor or via scripts/apply_supabase_schema.py

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Reference: recipe catalogue (read-heavy)
CREATE TABLE IF NOT EXISTS recipes (
    recipe_id BIGINT PRIMARY KEY,
    recipe_name TEXT NOT NULL,
    minutes INT,
    ingredients JSONB NOT NULL DEFAULT '[]',
    cleaned_ingredients JSONB NOT NULL DEFAULT '[]',
    tags JSONB NOT NULL DEFAULT '[]',
    dietary_tags JSONB NOT NULL DEFAULT '[]',
    cuisine_tags JSONB NOT NULL DEFAULT '[]',
    difficulty_level TEXT,
    n_ingredients INT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recipes_name ON recipes USING gin (to_tsvector('english', recipe_name));

-- App users (links to auth.users when using Supabase Auth)
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    auth_user_id UUID UNIQUE,
    legacy_user_id BIGINT,
    allergies JSONB NOT NULL DEFAULT '[]',
    dietary_type TEXT NOT NULL DEFAULT 'none',
    preferred_cuisines JSONB NOT NULL DEFAULT '[]',
    region TEXT DEFAULT 'Global',
    openness_to_new_cuisines REAL DEFAULT 0.5,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_fridge_inventory (
    id BIGSERIAL PRIMARY KEY,
    user_profile_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    ingredient_name TEXT NOT NULL,
    cleaned_ingredient_name TEXT NOT NULL,
    quantity TEXT,
    days_to_expiry INT NOT NULL DEFAULT 7,
    expiry_priority_score REAL NOT NULL DEFAULT 0.5,
    barcode TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fridge_user ON user_fridge_inventory(user_profile_id);

CREATE TABLE IF NOT EXISTS interactions (
    id BIGSERIAL PRIMARY KEY,
    user_profile_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    recipe_id BIGINT NOT NULL REFERENCES recipes(recipe_id),
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review TEXT,
    interaction_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_profile_id, recipe_id)
);

CREATE TABLE IF NOT EXISTS open_food_products (
    barcode TEXT PRIMARY KEY,
    product_name TEXT,
    generic_ingredient_name TEXT,
    allergens TEXT,
    nutriscore_grade TEXT,
    nutrition_score REAL DEFAULT 0.5,
    raw_json JSONB
);

CREATE TABLE IF NOT EXISTS shelf_life (
    cleaned_ingredient_name TEXT PRIMARY KEY,
    category TEXT,
    storage_type TEXT,
    shelf_life_days_min INT,
    shelf_life_days_max INT,
    shelf_life_days_avg INT,
    expiry_priority_score REAL DEFAULT 0.5,
    source TEXT
);

-- RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_fridge_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE interactions ENABLE ROW LEVEL SECURITY;

-- Recipes & reference data: public read
ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE open_food_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE shelf_life ENABLE ROW LEVEL SECURITY;

CREATE POLICY recipes_public_read ON recipes FOR SELECT USING (true);
CREATE POLICY off_public_read ON open_food_products FOR SELECT USING (true);
CREATE POLICY shelf_public_read ON shelf_life FOR SELECT USING (true);

-- Service role bypasses RLS; for authenticated users:
CREATE POLICY profiles_own ON user_profiles
    FOR ALL USING (auth.uid() = auth_user_id);

CREATE POLICY fridge_own ON user_fridge_inventory
    FOR ALL USING (
        user_profile_id IN (SELECT id FROM user_profiles WHERE auth_user_id = auth.uid())
    );

CREATE POLICY interactions_own ON interactions
    FOR ALL USING (
        user_profile_id IN (SELECT id FROM user_profiles WHERE auth_user_id = auth.uid())
    );

-- Demo profile for API without auth (legacy_user_id = 5060)
-- Created by seed script
