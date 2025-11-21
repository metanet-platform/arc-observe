package postgresql

import (
	"context"
)

// GetAllRegisteredHashes returns all registered transaction hashes
func (p *PostgreSQL) GetAllRegisteredHashes(ctx context.Context) ([][]byte, error) {
	const q = `SELECT hash FROM blocktx.registered_transactions`

	rows, err := p.db.QueryContext(ctx, q)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var hashes [][]byte
	for rows.Next() {
		var hash []byte
		if err := rows.Scan(&hash); err != nil {
			return nil, err
		}
		hashes = append(hashes, hash)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return hashes, nil
}
