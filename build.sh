#!/bin/bash
# Build ARC binary from source

set -e

echo "=== Building ARC binary ==="

# Ensure Go is available
if ! command -v go &> /dev/null; then
    echo "Error: Go is not installed. Please run setup-pm2.sh first."
    exit 1
fi

# Ensure GCC is available (required for CGO)
if ! command -v gcc &> /dev/null; then
    echo "Error: GCC is not installed. Installing build-essential..."
    apt-get update && apt-get install -y build-essential
fi

# Display Go version
echo "Using Go version: $(go version)"

# Enable CGO (required for some dependencies)
export CGO_ENABLED=1

# Build the binary
echo "Building arc binary with CGO enabled..."
go build -o arc ./cmd/arc/main.go

# Make it executable
chmod +x arc

# Display binary info
echo ""
echo "=== Build Complete ==="
echo "Binary: $(pwd)/arc"
echo "Size: $(ls -lh arc | awk '{print $5}')"
echo ""
echo "Test with: ./arc -h"
