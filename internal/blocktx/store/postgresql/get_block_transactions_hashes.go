package postgresql

import (
	"context"
	"errors"

	"github.com/lib/pq"
	"github.com/libsv/go-p2p/chaincfg/chainhash"

	"github.com/bitcoin-sv/arc/internal/blocktx/store"
	"github.com/bitcoin-sv/arc/pkg/tracing"
)

func (p *PostgreSQL) GetBlockTransactionsHashes(ctx context.Context, blockHash []byte) (txHashes []*chainhash.Hash, err error) {
	ctx, span := tracing.StartTracing(ctx, "GetBlockTransactionsHashes", p.tracingEnabled, p.tracingAttributes...)
	defer func() {
		tracing.EndTracing(span, err)
	}()

	// First, try to get complete merkle leaves from blocks.merkle_leaves column
	// This column stores complete merkle tree leaves for blocks when storeAllBlockTransactions=false
	qFromBlocks := `
		SELECT merkle_leaves
		FROM blocktx.blocks
		WHERE hash = $1 AND merkle_leaves IS NOT NULL
	`

	var txHashesBytes [][]byte
	err = p.db.QueryRowContext(ctx, qFromBlocks, blockHash).Scan(pq.Array(&txHashesBytes))
	if err == nil && len(txHashesBytes) > 0 {
		// Found merkle_leaves in blocks table, convert to chainhash format
		txHashes = make([]*chainhash.Hash, len(txHashesBytes))
		for i, hashBytes := range txHashesBytes {
			cHash, err := chainhash.NewHash(hashBytes)
			if err != nil {
				return nil, errors.Join(store.ErrFailedToParseHash, err)
			}
			txHashes[i] = cHash
		}
		return txHashes, nil
	}

	// Fallback to block_transactions table for backward compatibility
	// or when storeAllBlockTransactions=true (tx_hashes column is NULL)
	q := `
		SELECT
			bt.hash
		FROM blocktx.block_transactions AS bt
			JOIN blocktx.blocks AS b ON bt.block_id = b.id
		WHERE b.hash = $1
		ORDER BY bt.merkle_tree_index ASC
	`

	rows, err := p.db.QueryContext(ctx, q, blockHash)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var txHash []byte
		err = rows.Scan(&txHash)
		if err != nil {
			return nil, errors.Join(store.ErrFailedToGetRows, err)
		}

		cHash, err := chainhash.NewHash(txHash)
		if err != nil {
			return nil, errors.Join(store.ErrFailedToParseHash, err)
		}

		txHashes = append(txHashes, cHash)
	}

	return txHashes, nil
}
