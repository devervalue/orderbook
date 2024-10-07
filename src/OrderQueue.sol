// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/console.sol";


library OrderQueue {
    /* Errors */
    // TODO: Consider using custom error strings instead of error types to save gas
    // Custom errors with strings are more gas-efficient than error types in Solidity 0.8.4+
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
        bytes32 first;
        bytes32 last;
        mapping(bytes32 => OrderBookNode) orders;
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
        // TODO: Use custom errors instead of require statements for more gas-efficient reverts

        //TODO QUE PASA SI INTENTO AGREGAR UN VALOR O ID QUE YA EXISTE ? PUEDE SUCEDER?
        if (q.last != 0) {
            q.orders[q.last].next = _orderId;
        } else if (q.first == 0) {
            q.first = _orderId;
        }

        // TODO: Consider using assembly for this storage operation to save gas
        q.orders[_orderId] = OrderBookNode({orderId: _orderId, prev: q.last, next: 0});
        q.last = _orderId;
        // TODO: Consider emitting an event for off-chain tracking (if not already done elsewhere)
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
        // Combine conditions to reduce storage reads
        bytes32 newFirst = q.first;
        bytes32 newLast = q.last;

        if (newFirst == orderId) {
            newFirst = orderBookNode.next;
        }
        if (newLast == orderId) {
            newLast = orderBookNode.prev;
        }

        // Only update storage if values have changed
        if (newFirst != q.first) {
            q.first = newFirst;
        }
        if (newLast != q.last) {
            q.last = newLast;
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
}
