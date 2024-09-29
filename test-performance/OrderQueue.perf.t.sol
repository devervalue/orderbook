// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./OrderQueueImpl.sol";

abstract contract QueueHelper {
    OrderQueueImpl public queue;
}

contract EmptyQueueTest is Test, QueueHelper {

    //---------  SET UP

    function setUp() public {
        queue = new OrderQueueImpl();
    }

    //---------   Queue Tests

    function testIsEmpty() public {
        uint256 startGas = gasleft();
        bool isEmpty = queue.isEmpty();
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for isEmpty on empty queue: %d", gasUsed);
    }

    function testOrderExists() public {
        bytes32 orderId = keccak256(abi.encodePacked(address(this), uint(1)));
        uint256 startGas = gasleft();
        bool exists = queue.orderExists(orderId);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for orderExists on empty queue: %d", gasUsed);
    }

    function testPush() public {
        uint i = 10001;
        bytes32 orderId = keccak256(abi.encodePacked(address(this), i));
        uint256 startGas = gasleft();
        queue.push(address(this), orderId, i, 100, block.timestamp, block.timestamp + 1 days);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for pushing order on empty queue: %d", gasUsed);
    }

    function testPop() public {
        // First, push an order
        uint i = 10001;
        bytes32 orderId = keccak256(abi.encodePacked(address(this), i));
        queue.push(address(this), orderId, i, 100, block.timestamp, block.timestamp + 1 days);

        // Now, test pop
        uint256 startGas = gasleft();
        OrderQueue.OrderBookNode memory node = queue.pop();
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for popping order from queue with one element: %d", gasUsed);
    }

    function testRemoveOrder() public {
        // First, push an order
        uint i = 10001;
        bytes32 orderId = keccak256(abi.encodePacked(address(this), i));
        queue.push(address(this), orderId, i, 100, block.timestamp, block.timestamp + 1 days);

        // Now, test removeOrder
        uint256 startGas = gasleft();
        queue.removeOrder(orderId);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for removing order from queue with one element: %d", gasUsed);
    }

}

contract SmallQueueTest is Test, QueueHelper {

    //---------  SET UP

    function setUp() public {
        queue = new OrderQueueImpl();
        uint numOrders = 10;

        bytes32[] memory orderIds = new bytes32[](numOrders);

        for (uint256 i = 0; i < numOrders; i++) {
            bytes32 orderId = keccak256(abi.encodePacked(address(this), i));
            orderIds[i] = orderId;
            queue.push(address(this), orderId, i, 100, block.timestamp, block.timestamp + 1 days);
        }
    }

    //---------   Queue Tests

    function testIsEmpty() public {
        uint256 startGas = gasleft();
        bool isEmpty = queue.isEmpty();
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for isEmpty on empty queue: %d", gasUsed);
    }

    function testOrderExists() public {
        bytes32 orderId = keccak256(abi.encodePacked(address(this), uint(1)));
        uint256 startGas = gasleft();
        bool exists = queue.orderExists(orderId);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for orderExists on empty queue: %d", gasUsed);
    }

    function testPush() public {
        uint i = 10001;
        bytes32 orderId = keccak256(abi.encodePacked(address(this), i));
        uint256 startGas = gasleft();
        queue.push(address(this), orderId, i, 100, block.timestamp, block.timestamp + 1 days);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for pushing order on empty queue: %d", gasUsed);
    }

    function testPop() public {
        // First, push an order
        uint i = 10001;
        bytes32 orderId = keccak256(abi.encodePacked(address(this), i));
        queue.push(address(this), orderId, i, 100, block.timestamp, block.timestamp + 1 days);

        // Now, test pop
        uint256 startGas = gasleft();
        OrderQueue.OrderBookNode memory node = queue.pop();
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for popping order from queue with one element: %d", gasUsed);
    }

    function testRemoveOrder() public {
        // First, push an order
        uint i = 10001;
        bytes32 orderId = keccak256(abi.encodePacked(address(this), i));
        queue.push(address(this), orderId, i, 100, block.timestamp, block.timestamp + 1 days);

        // Now, test removeOrder
        uint256 startGas = gasleft();
        queue.removeOrder(orderId);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for removing order from queue with one element: %d", gasUsed);
    }
}

contract LargeQueueTest is Test, QueueHelper {

    //---------  SET UP

    function setUp() public {
        queue = new OrderQueueImpl();
        uint numOrders = 10000;

        bytes32[] memory orderIds = new bytes32[](numOrders);

        for (uint256 i = 0; i < numOrders; i++) {
            bytes32 orderId = keccak256(abi.encodePacked(address(this), i));
            orderIds[i] = orderId;
            queue.push(address(this), orderId, i, 100, block.timestamp, block.timestamp + 1 days);
        }
    }

    //---------   Queue Tests

    function testIsEmpty() public {
        uint256 startGas = gasleft();
        bool isEmpty = queue.isEmpty();
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for isEmpty on empty queue: %d", gasUsed);
    }

    function testOrderExists() public {
        bytes32 orderId = keccak256(abi.encodePacked(address(this), uint(1)));
        uint256 startGas = gasleft();
        bool exists = queue.orderExists(orderId);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for orderExists on empty queue: %d", gasUsed);
    }

    function testPush() public {
        uint i = 10001;
        bytes32 orderId = keccak256(abi.encodePacked(address(this), i));
        uint256 startGas = gasleft();
        queue.push(address(this), orderId, i, 100, block.timestamp, block.timestamp + 1 days);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for pushing order on empty queue: %d", gasUsed);
    }

    function testPop() public {
        // First, push an order
        uint i = 10001;
        bytes32 orderId = keccak256(abi.encodePacked(address(this), i));
        queue.push(address(this), orderId, i, 100, block.timestamp, block.timestamp + 1 days);

        // Now, test pop
        uint256 startGas = gasleft();
        OrderQueue.OrderBookNode memory node = queue.pop();
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for popping order from queue with one element: %d", gasUsed);
    }

    function testRemoveOrder() public {
        // First, push an order
        uint i = 10001;
        bytes32 orderId = keccak256(abi.encodePacked(address(this), i));
        queue.push(address(this), orderId, i, 100, block.timestamp, block.timestamp + 1 days);

        // Now, test removeOrder
        uint256 startGas = gasleft();
        queue.removeOrder(orderId);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for removing order from queue with one element: %d", gasUsed);
    }
}
