-- Remove merkle_leaves column from blocks table
ALTER TABLE blocktx.blocks DROP COLUMN IF EXISTS merkle_leaves;
