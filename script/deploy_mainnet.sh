#!/bin/sh

# Deploy OrderbookFactory Mainnet
echo "Deploy Mainnet"
source .env && forge script script/DeployMainnetScript.s.sol --rpc-url $RPC_ARBISCAN_URL --broadcast --private-key $PRIVATE_KEY_ARBISCAN