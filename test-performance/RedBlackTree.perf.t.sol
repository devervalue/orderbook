// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./RedBlackTreeImpl.sol";

abstract contract RedBlackTreeHelper is Test {
    RedBlackTreeImpl public tree;
    address public trader1 = makeAddr("trader1");
}

contract EmptyTreeTest is RedBlackTreeHelper {
    //---------  SET UP

    function setUp() public {
        tree = new RedBlackTreeImpl();
    }

    //---------   Tree Tests

    function testInsertion() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        uint256 startGas = gasleft();
        tree.insert(orderId, 10, trader1, 100, 1, 999999);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for inserting node on empty tree: %d", gasUsed);
    }

    function testRemove() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        tree.insert(orderId, 10, trader1, 100, 1, 999999);
        uint256 startGas = gasleft();
        tree.remove(orderId, 10);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for removing node on empty tree: %d", gasUsed);
    }

    function testPopOrder() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        tree.insert(orderId, 10, trader1, 100, 1, 999999);
        uint256 startGas = gasleft();
        tree.popOrder(10);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for popping order on empty tree: %d", gasUsed);
    }
}

contract SmallTreeTest is RedBlackTreeHelper {
    //---------  SET UP

    function setUp() public {
        tree = new RedBlackTreeImpl();
        uint256 numOrders = 10;

        bytes32[] memory orderIds = new bytes32[](numOrders);

        for (uint256 i = 1; i <= numOrders; i++) {
            bytes32 orderId = keccak256(abi.encodePacked(address(this), i * 2));
            orderIds[i - 1] = orderId;
            tree.insert(orderId, i * 2, trader1, 1, i, 999999);
        }
    }

    //---------   Tree Tests

    function testInsertionMiddle() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        uint256 startGas = gasleft();
        tree.insert(orderId, 11, trader1, 100, 1, 999999);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for inserting node on small tree: %d", gasUsed);
    }

    function testInsertionFirst() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        uint256 startGas = gasleft();
        tree.insert(orderId, 1, trader1, 100, 1, 999999);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for inserting first node on small tree: %d", gasUsed);
    }

    function testInsertionLast() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        uint256 startGas = gasleft();
        tree.insert(orderId, 100, trader1, 100, 1, 999999);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for inserting last node on small tree: %d", gasUsed);
    }

    function testRemove() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        tree.insert(orderId, 11, trader1, 100, 1, 999999);
        uint256 startGas = gasleft();
        tree.remove(orderId, 11);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for removing node on small tree: %d", gasUsed);
    }

    function testRemoveFirst() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        tree.insert(orderId, 1, trader1, 100, 1, 999999);
        uint256 startGas = gasleft();
        tree.remove(orderId, tree.first());
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for removing first node on small tree: %d", gasUsed);
    }

    function testRemoveLast() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        tree.insert(orderId, 100, trader1, 100, 1, 999999);
        uint256 startGas = gasleft();
        tree.remove(orderId, tree.last());
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for removing node on small tree: %d", gasUsed);
    }

    function testPopOrder() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        tree.insert(orderId, 11, trader1, 100, 1, 999999);
        uint256 startGas = gasleft();
        tree.popOrder(11);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for popping order on small tree: %d", gasUsed);
    }

    function testPopOrderFirst() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        tree.insert(orderId, 1, trader1, 100, 1, 999999);
        uint256 startGas = gasleft();
        tree.popOrder(tree.first());
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for popping order on first node small tree: %d", gasUsed);
    }

    function testPopOrderLast() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        tree.insert(orderId, 100, trader1, 100, 1, 999999);
        uint256 startGas = gasleft();
        tree.popOrder(tree.last());
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for popping order on last node small tree: %d", gasUsed);
    }

    function testPopOrderRoot() public {
        uint256 startGas = gasleft();
        tree.popOrder(tree.root());
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for popping order on root node small tree: %d", gasUsed);
    }

    function testFirst() public {
        uint256 startGas = gasleft();
        tree.first();
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used to get first node on small tree: %d", gasUsed);
    }

    function testLast() public {
        uint256 startGas = gasleft();
        tree.last();
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used to get last node on small tree: %d", gasUsed);
    }

    function testPopAllLeft() public {
        uint256 startGas = gasleft();
        while (tree.first() != 0) {
            tree.popOrder(tree.first());
        }
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used to pop all from the left on small tree: %d", gasUsed);
    }

    function testPopAllRight() public {
        uint256 startGas = gasleft();
        while (tree.last() != 0) {
            tree.popOrder(tree.last());
        }
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used to pop all from the right on small tree: %d", gasUsed);
    }
}

contract MediumTreeTest is RedBlackTreeHelper {
    //---------  SET UP

    function setUp() public {
        tree = new RedBlackTreeImpl();
        uint256 numOrders = 1000;

        bytes32[] memory orderIds = new bytes32[](numOrders);

        for (uint256 i = 1; i <= numOrders; i++) {
            bytes32 orderId = keccak256(abi.encodePacked(address(this), i * 2));
            orderIds[i - 1] = orderId;
            tree.insert(orderId, i * 2, trader1, 1, i, 999999);
        }
    }

    //---------   Tree Tests

    function testInsertion() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        uint256 startGas = gasleft();
        tree.insert(orderId, 101, trader1, 100, 1, 999999);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for inserting node on medium tree: %d", gasUsed);
    }

    function testInsertionFirst() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        uint256 startGas = gasleft();
        tree.insert(orderId, 1, trader1, 100, 1, 999999);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for inserting first node on medium tree: %d", gasUsed);
    }

    function testInsertionLast() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        uint256 startGas = gasleft();
        tree.insert(orderId, 1000, trader1, 100, 1, 999999);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for inserting last node on medium tree: %d", gasUsed);
    }

    function testRemove() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        tree.insert(orderId, 101, trader1, 100, 1, 999999);
        uint256 startGas = gasleft();
        tree.remove(orderId, 101);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for removing node on medium tree: %d", gasUsed);
    }

    function testRemoveFirst() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        tree.insert(orderId, 1, trader1, 100, 1, 999999);
        uint256 startGas = gasleft();
        tree.remove(orderId, tree.first());
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for removing first node on medium tree: %d", gasUsed);
    }

    function testRemoveLast() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        tree.insert(orderId, 1000, trader1, 100, 1, 999999);
        uint256 startGas = gasleft();
        tree.remove(orderId, tree.last());
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for removing node on medium tree: %d", gasUsed);
    }

    function testPopOrder() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        tree.insert(orderId, 101, trader1, 100, 1, 999999);
        uint256 startGas = gasleft();
        tree.popOrder(101);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for popping order on medium tree: %d", gasUsed);
    }

    function testPopOrderFirst() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        tree.insert(orderId, 1, trader1, 100, 1, 999999);
        uint256 startGas = gasleft();
        tree.popOrder(tree.first());
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for popping order on first node medium tree: %d", gasUsed);
    }

    function testPopOrderLast() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        tree.insert(orderId, 1000, trader1, 100, 1, 999999);
        uint256 startGas = gasleft();
        tree.popOrder(tree.last());
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for popping order on last node medium tree: %d", gasUsed);
    }

    function testPopOrderRoot() public {
        uint256 startGas = gasleft();
        tree.popOrder(tree.root());
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for popping order on root node medium tree: %d", gasUsed);
    }

    function testFirst() public {
        uint256 startGas = gasleft();
        tree.first();
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used to get first node on medium tree: %d", gasUsed);
    }

    function testLast() public {
        uint256 startGas = gasleft();
        tree.last();
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used to get last node on medium tree: %d", gasUsed);
    }

    function testPopHalfLeft() public {
        uint256 startGas = gasleft();
        uint256 count = 0;
        while (tree.first() != 0 && tree.first() < 1000) {
            tree.popOrder(tree.first());
            ++count;
        }
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used to pop all from the left on medium tree: %d", gasUsed, count);
    }

    function testPopHalfRight() public {
        uint256 startGas = gasleft();
        uint256 count = 0;
        while (tree.last() != 0 && tree.last() > 1000) {
            tree.popOrder(tree.last());
            ++count;
        }
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used to pop all from the right on medium tree: %d", gasUsed, count);
    }
}

contract LargeTreeTest is RedBlackTreeHelper {
    //---------  SET UP

    function setUp() public {
        tree = new RedBlackTreeImpl();
        uint256 numOrders = 10000;

        bytes32[] memory orderIds = new bytes32[](numOrders);

        for (uint256 i = 1; i <= numOrders; i++) {
            bytes32 orderId = keccak256(abi.encodePacked(address(this), i * 2));
            orderIds[i - 1] = orderId;
            tree.insert(orderId, i * 2, trader1, 1, i, 999999);
        }
    }

    //---------   Tree Tests

    function testInsertion() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        uint256 startGas = gasleft();
        tree.insert(orderId, 10001, trader1, 100, 1, 999999);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for inserting node on large tree: %d", gasUsed);
    }

    function testInsertionFirst() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        uint256 startGas = gasleft();
        tree.insert(orderId, 1, trader1, 100, 1, 999999);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for inserting first node on large tree: %d", gasUsed);
    }

    function testInsertionLast() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        uint256 startGas = gasleft();
        tree.insert(orderId, 100000, trader1, 100, 1, 999999);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for inserting last node on large tree: %d", gasUsed);
    }

    function testRemove() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        tree.insert(orderId, 10001, trader1, 100, 1, 999999);
        uint256 startGas = gasleft();
        tree.remove(orderId, 10001);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for removing node on large tree: %d", gasUsed);
    }

    function testRemoveFirst() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        tree.insert(orderId, 1, trader1, 100, 1, 999999);
        uint256 startGas = gasleft();
        tree.remove(orderId, tree.first());
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for removing first node on large tree: %d", gasUsed);
    }

    function testRemoveLast() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        tree.insert(orderId, 100000, trader1, 100, 1, 999999);
        uint256 startGas = gasleft();
        tree.remove(orderId, tree.last());
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for removing node on large tree: %d", gasUsed);
    }

    function testPopOrder() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        tree.insert(orderId, 10001, trader1, 100, 1, 999999);
        uint256 startGas = gasleft();
        tree.popOrder(10001);
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for popping order on large tree: %d", gasUsed);
    }

    function testPopOrderFirst() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        tree.insert(orderId, 1, trader1, 100, 1, 999999);
        uint256 startGas = gasleft();
        tree.popOrder(tree.first());
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for popping order on first node large tree: %d", gasUsed);
    }

    function testPopOrderLast() public {
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
        tree.insert(orderId, 100000, trader1, 100, 1, 999999);
        uint256 startGas = gasleft();
        tree.popOrder(tree.last());
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for popping order on last node large tree: %d", gasUsed);
    }

    function testPopOrderRoot() public {
        uint256 startGas = gasleft();
        tree.popOrder(tree.root());
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used for popping order on root node large tree: %d", gasUsed);
    }

    function testFirst() public {
        uint256 startGas = gasleft();
        tree.first();
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used to get first node on large tree: %d", gasUsed);
    }

    function testLast() public {
        uint256 startGas = gasleft();
        tree.last();
        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used to get last node on large tree: %d", gasUsed);
    }

        function testPopAllLeft() public {
            uint256 startGas = gasleft();
            while (tree.first() != 0){
                tree.popOrder(tree.first());
            }
            uint256 gasUsed = startGas - gasleft();
            console.log("Gas used to pop all from the left on large tree: %d", gasUsed);
        }
    //
    //    function testPopAllRight() public {
    //        uint256 startGas = gasleft();
    //        while (tree.last() != 0){
    //            tree.popOrder(tree.last());
    //        }
    //        uint256 gasUsed = startGas - gasleft();
    //        console.log("Gas used to pop all from the right on large tree: %d", gasUsed);
    //    }
}
