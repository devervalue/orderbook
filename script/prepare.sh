#!/bin/sh

# Deploy OrderbookFactory
echo "Deploy OrderbookFactory"
source .env && forge script script/DeployScript.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --private-key $PRIVATE_KEY
# Deploy Token A
echo "Deploy Token A"
source .env && forge script script/DeployTokenA.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --private-key $PRIVATE_KEY_TOKEN_A
# Deploy Token B
echo "Deploy Token B"
source .env && forge script script/DeployTokenB.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --private-key $PRIVATE_KEY_TOKEN_B
# Llamar función getOwner()
echo "Get Owner"
cast call 0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0 "getOwner()" --rpc-url http://127.0.0.1:8545
# Crear Orderbook
echo "Create Orderbook"
forge script script/CreateOrderBook.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --private-key $PRIVATE_KEY
# Verificar la lista de orderbooks
echo "Get Orderbook list"
cast call 0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0 "getKeysOrderBooks()(bytes32[])" --rpc-url http://127.0.0.1:8545
# Obtener un libro especifico
echo "Get Orderbook by ID"
cast call 0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0 "getOrderBookById(bytes32)(address,address,bool,uint256,uint256)" "0xc404d413e92e9b151a97e823fece65248a27a8236ad3c9e8f92c46d3ab2d450d" --rpc-url http://127.0.0.1:8545