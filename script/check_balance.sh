#!/bin/sh

echo "Get Orderbook balance"
cast call 0x663F3ad617193148711d28f5334eE4Ed07016602 "balanceOf(address)(uint256)" "0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0" --rpc-url http://127.0.0.1:8545
cast call 0x8464135c8F25Da09e49BC8782676a84730C318bC "balanceOf(address)(uint256)" "0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0" --rpc-url http://127.0.0.1:8545