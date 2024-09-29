// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./OrderQueueContract.sol";

abstract contract QueueHelper {
    OrderQueueContract public queue;
}

contract EmptyQueueTest is Test, QueueHelper {

    //---------  SET UP

    function setUp() public {
        queue = new OrderQueueContract();
    }

    //---------   Queue Tests

    function testPush() public {
        uint i = 1;
        bytes32 orderId = keccak256(abi.encodePacked(address(this), i));
        uint256 startGas = gasleft();
        queue.push(address(this), orderId, i, 100, block.timestamp, block.timestamp + 1 days);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for pushing order on empty queue: %d", gasUsed);
    }
}

contract SmallQueueTest is Test, QueueHelper {

    //---------  SET UP

    function setUp() public {
        queue = new OrderQueueContract();
        uint numOrders = 10;

        bytes32[] memory orderIds = new bytes32[](numOrders);

        for (uint256 i = 0; i < numOrders; i++) {
            bytes32 orderId = keccak256(abi.encodePacked(address(this), i));
            orderIds[i] = orderId;
            queue.push(address(this), orderId, i, 100, block.timestamp, block.timestamp + 1 days);
        }
    }

    //---------   Queue Tests

    function testPush() public {
        uint i = 11;
        bytes32 orderId = keccak256(abi.encodePacked(address(this), i));
        uint256 startGas = gasleft();
        queue.push(address(this), orderId, i, 100, block.timestamp, block.timestamp + 1 days);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for pushing order on small queue: %d", gasUsed);
    }
}

contract LargeQueueTest is Test, QueueHelper {

    //---------  SET UP

    function setUp() public {
        queue = new OrderQueueContract();
        uint numOrders = 10000;

        bytes32[] memory orderIds = new bytes32[](numOrders);

        for (uint256 i = 0; i < numOrders; i++) {
            bytes32 orderId = keccak256(abi.encodePacked(address(this), i));
            orderIds[i] = orderId;
            queue.push(address(this), orderId, i, 100, block.timestamp, block.timestamp + 1 days);
        }
    }

    //---------   Queue Tests

    function testPush() public {
        uint i = 10001;
        bytes32 orderId = keccak256(abi.encodePacked(address(this), i));
        uint256 startGas = gasleft();
        queue.push(address(this), orderId, i, 100, block.timestamp, block.timestamp + 1 days);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for pushing order on large queue: %d", gasUsed);
    }
}
