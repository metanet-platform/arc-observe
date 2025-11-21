package postgresql

import (
	"context"

	"github.com/lib/pq"

	"github.com/bitcoin-sv/arc/pkg/tracing"
)

func (p *PostgreSQL) UpsertBlockMerkleTree(ctx context.Context, blockHash []byte, merkleLeaves [][]byte) (err error) {
	ctx, span := tracing.StartTracing(ctx, "UpsertBlockMerkleTree", p.tracingEnabled, p.tracingAttributes...)
	defer func() {
		tracing.EndTracing(span, err)
	}()

	// Update the blocks table to store the complete merkle tree leaves array
	// This is used for merkle proof generation when storeAllBlockTransactions=false
	q := `
		UPDATE blocktx.blocks
		SET merkle_leaves = $2
		WHERE hash = $1
	`

	_, err = p.db.ExecContext(ctx, q, blockHash, pq.Array(merkleLeaves))
	if err != nil {
		return err
	}

	return nil
}
