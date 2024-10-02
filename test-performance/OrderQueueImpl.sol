// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "../src/OrderQueue.sol";
import "forge-std/console.sol";

contract OrderQueueImpl {
    using OrderQueue for OrderQueue.Queue;
    using OrderQueue for OrderQueue.OrderBookNode;

    OrderQueue.Queue private queue;

    constructor() public {}

    // Get first queue item
    function queueFirst() public view returns (bytes32 _first) {
        _first = queue.first;
    }

    //  Get Last queue item
    function queueLast() public view returns (bytes32 _last) {
        _last = queue.last;
    }

    //  Check if order exists
    function orderExists(bytes32 _orderId) public view returns (bool _exists) {
        _exists = queue.orderExists(_orderId);
    }

    //  Check if the queue is empty
    function isEmpty() public view returns (bool _empty) {
        _empty = queue.isEmpty();
    }

    //  Push an order to tue queue
    function push(
        address _traderAddress,
        bytes32 _orderId,
        uint256 _price,
        uint256 _quantity,
        uint256 _nonce,
        uint256 _expired
    ) public {
        queue.push(_traderAddress, _orderId, _price, _quantity, _nonce, _expired);
    }

    // Pop the first order from the queue
    function pop() public returns (OrderQueue.OrderBookNode memory _order) {
        _order = queue.pop();
    }

    // Remove a specific order from the queue
    function removeOrder(bytes32 _orderId) public {
        queue.removeOrder(_orderId);
    }

    function batchPopUntil(bytes32 _newFirstOrderId) public returns (bytes32 _firstRemoved) {
        _firstRemoved = queue.batchPopUntil(_newFirstOrderId);
        console.logBytes32(_firstRemoved);
    }
}
