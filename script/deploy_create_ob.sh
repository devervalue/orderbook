#!/bin/sh

# Crear Orderbook
echo "Create Orderbook"
source .env && forge script script/deploy_create_orderbook.sol --rpc-url https://arbitrum.meowrpc.com --broadcast --private-key $PRIVATE_KEY
