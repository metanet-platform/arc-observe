-- Add column to blocks table to store complete merkle tree leaves for proof generation
-- NULL when storeAllBlockTransactions=true (not needed)
-- Array of transaction hashes (merkle leaves) when storeAllBlockTransactions=false and block has registered transactions
ALTER TABLE blocktx.blocks ADD COLUMN IF NOT EXISTS merkle_leaves BYTEA[];

-- Add comment explaining purpose
COMMENT ON COLUMN blocktx.blocks.merkle_leaves IS 'Complete ordered list of transaction hashes (merkle tree leaf nodes) in block. Used to generate merkle proofs when storeAllBlockTransactions=false. NULL when not needed.';
