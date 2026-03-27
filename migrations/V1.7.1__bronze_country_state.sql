ALTER TABLE bronze.promoter_score DROP COLUMN region;
ALTER TABLE bronze.promoter_score ADD COLUMN country STRING(2);
ALTER TABLE bronze.promoter_score ADD COLUMN state STRING(2);
