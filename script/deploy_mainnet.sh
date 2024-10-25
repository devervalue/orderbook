#!/bin/sh

# Deploy OrderbookFactory
echo "Deploy OrderbookFactory"
source .env && forge script script/DeployScript.s.sol --rpc-url https://arbitrum.meowrpc.com --broadcast --private-key $PRIVATE_KEY
