// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library OrderQueue {
    /* Errors */
    // TODO: Consider using custom error strings instead of error types to save gas
    // Custom errors with strings are more gas-efficient than error types in Solidity 0.8.4+
    error OrderQueue__CantPopAnEmptyQueue();
    error OrderQueue__CantRemoveFromAnEmptyQueue();

    // TODO: If these errors are used frequently, consider using shorter names to reduce deployment cost
    // For example:
    // error OQ__EmptyQueuePop();
    // error OQ__EmptyQueueRemove();

    /**
     *  @notice Structure of an order within the node.
     */
    struct OrderBookNode {
        // TODO: Reorder variables to pack them more efficiently and reduce storage slots
        // uint256 and bytes32 variables should be grouped together
        bytes32 orderId;
        bytes32 next;
        bytes32 prev;
    }
    // TODO: Consider using enum for status instead of uint8 for better readability
    // TODO: If possible, combine isBuy and status into a single uint8 to save storage

    struct Queue {
        // TODO: Consider using uint256 instead of bytes32 for 'first' and 'last' if they represent indices
        // This could potentially save gas in arithmetic operations
        mapping(bytes32 => OrderBookNode) orders;
        bytes32 first;
        bytes32 last;
    }
    // TODO: If possible, combine 'first' and 'last' into a single uint256 to save storage
    // The lower 128 bits could represent 'first' and the upper 128 bits 'last'

    //Existe la orden
    function orderExists(Queue storage q, bytes32 _orderId) internal view returns (bool exists) {
        // TODO: Consider using assembly to check if orderId is non-zero for potential gas savings
        // TODO: If possible, use a bitmap to track existing orders instead of checking the full struct
        return q.orders[_orderId].orderId != 0;
    }

    //Cola Vacia
    function isEmpty(Queue storage q) internal view returns (bool empty) {
        // TODO: Consider using assembly for this simple check to potentially save gas
        // TODO: If 'first' is frequently accessed, consider caching it in a uint256 state variable
        // TODO: If possible, use a boolean flag to track emptiness instead of checking 'first'
        return q.first == 0;
    }

    //Insertar
    function push(Queue storage q, bytes32 _orderId) internal {
        // TODO: Add a check if the order already exists to prevent overwriting
        // TODO: Consider using unchecked blocks for arithmetic operations where overflow is impossible
        // TODO: Use assembly for simple storage reads and writes to save gas
        // TODO: Consider packing _price, _quantity, nonce, and _expired into a single storage slot if possible
        // TODO: Use custom errors instead of require statements for more gas-efficient reverts
        // TODO: Consider using a struct for input parameters to reduce stack usage

        //TODO QUE PASA SI INTENTO AGREGAR UN VALOR O ID QUE YA EXISTE ? PUEDE SUCEDER?
        if (q.first == 0) q.first = _orderId;
        if (q.last != 0) {
            q.orders[q.last].next = _orderId;
        }
        // TODO: Consider using assembly for this storage operation to save gas
        q.orders[_orderId] = OrderBookNode({orderId: _orderId, prev: q.last, next: 0});
        q.last = _orderId;
        // TODO: Consider emitting an event for off-chain tracking (if not already done elsewhere)
    }

    /*    //Insertar
    function push(
        Queue storage q,
        address _traderAddress,
        bytes32 _orderId,
        uint256 _price,
        uint256 _quantity,
        uint256 nonce,
        uint256 _expired
    ) internal {
        require(_orderId != 0, "OrderQueue: Invalid order ID");
        require(_traderAddress != address(0), "OrderQueue: Invalid trader address");
        require(_price > 0, "OrderQueue: Price must be greater than zero");
        require(_quantity > 0, "OrderQueue: Quantity must be greater than zero");
        require(_expired > block.timestamp, "OrderQueue: Expiration time must be in the future");

        // Check if the order already exists
        require(!orderExists(q, _orderId), "OrderQueue: Order with this ID already exists");

        if (q.last != 0) {
            q.orders[q.last].next = _orderId;
        } else if (q.first == 0) q.first = _orderId;

        q.orders[_orderId] = OrderBookNode({
            orderId: _orderId,
            traderAddress: _traderAddress,
            isBuy: true,
            price: _price,
            quantity: _quantity,
            availableQuantity: _quantity,
            status: 1, //created 1 / partially filled 2 / filled 3 / cancelada 4
            expiresAt: _expired,
            createdAt: nonce,
            prev: q.last,
            next: 0
        });
        q.last = _orderId;

        emit OrderPushed(_orderId, _traderAddress, _price, _quantity, _expired);
    }

    event OrderPushed(bytes32 indexed orderId, address indexed trader, uint256 price, uint256 quantity, uint256 expiresAt);*/

    //Eliminar
    function pop(Queue storage q) internal returns (bytes32 _orderID) {
        // TODO: Use a custom error without a message to save gas
        if (q.first == 0) revert OrderQueue__CantPopAnEmptyQueue();

        // TODO: Consider using assembly for storage reads and writes to save gas
        OrderBookNode memory orderBookNode = q.orders[q.first];
        // TODO: Consider using assembly for deleting storage to save gas
        delete q.orders[q.first];
        q.first = orderBookNode.next;
        // TODO: Consider combining these two operations to reduce storage writes
        if (q.first == 0) {
            q.last = 0;
        } else {
            // TODO: Use assembly to set q.orders[q.first].prev to 0 instead of deleting
            delete q.orders[q.first].prev;
            //queue.orders[first].prev = 0;
        }
        // TODO: Consider returning the struct directly instead of copying to memory
        return orderBookNode.orderId;
    }

    //Eliminar index
    function removeOrder(Queue storage q, bytes32 orderId) internal {
        // TODO: Use a custom error without a message to save gas
        if (q.first == 0) revert OrderQueue__CantRemoveFromAnEmptyQueue();
        // TODO: Add a check if the order exists to prevent unnecessary operations
        // TODO: Consider using assembly for storage reads to save gas
        //TODO VERIFICAR QUE LA ORDEN EXISTA DEBEMOS VALIDAR?
        OrderBookNode memory orderBookNode = q.orders[orderId];
        // TODO: Use assembly for deleting storage to save gas
        delete q.orders[orderId];
        // TODO: Consider combining these conditions to reduce storage reads
        if (q.first == orderId) {
            q.first = orderBookNode.next;
        }
        if (q.last == orderId) {
            q.last = orderBookNode.prev;
        }
        // TODO: Consider using assembly for these storage operations
        if (orderBookNode.next != 0) {
            q.orders[orderBookNode.next].prev = orderBookNode.prev;
        }

        if (orderBookNode.prev != 0) {
            q.orders[orderBookNode.prev].next = orderBookNode.next;
        }
        // TODO: Consider emitting an event for off-chain tracking
    }

    /*     TODO Review batch pop operation
    function batchPopUntil(Queue storage q, bytes32 _newFirstOrderId) internal returns (bytes32 _firstRemoved) {
        require(orderExists(q, _newFirstOrderId), "OrderQueue: New first order does not exist");
        _firstRemoved = q.first;
        // If the new first is already the first, do nothing
        if (_firstRemoved == _newFirstOrderId) {
            return 0;
        }

    //        bytes32 prev;
    //        bytes32 currentId = _newFirstOrderId;
    //        // Find the new first order and count removed elements
    //        while (currentId != 0 ) {
    //            prev = q.orders[currentId].prev;
    //            delete q.orders[currentId];
    //            currentId = prev;
    //            unchecked { ++removed; }
    //        }

        // If we've reached the end without finding newFirst, revert
    //        require(current != 0, "OrderQueue: New first order not found in queue");

        // Update the first pointer
        q.first = _newFirstOrderId;

        // Set the next of the last obsolete element to 0
        q.orders[q.orders[_newFirstOrderId].prev].next = 0;

        // Set the prev of the new first element to 0
        q.orders[_newFirstOrderId].prev = 0;

        // If queue becomes empty (shouldn't happen if newFirst exists, but just in case)
        if (_newFirstOrderId == 0) {
            q.last = 0;
        }

        return _firstRemoved;

    }*/
}
