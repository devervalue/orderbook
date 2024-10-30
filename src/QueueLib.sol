// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/console.sol";

library QueueLib {
    /* Errors */
    error QL__EmptyQueue();
    error QL__ItemAlreadyExists();
    error QL__ItemDoesNotExist();

    /**
     *  @notice Structure of an order within the node.
     */
    struct Item {
        bytes32 id;
        bytes32 next;
        bytes32 prev;
    }

    struct Queue {
        bytes32 first;
        bytes32 last;
        mapping(bytes32 => Item) items;
    }

    function itemExists(Queue storage q, bytes32 _itemId) internal view returns (bool) {
        return q.items[_itemId].id != 0;
    }

    function isEmpty(Queue storage q) internal view returns (bool) {
        return q.first == 0;
    }

    function push(Queue storage q, bytes32 _itemId) internal {
        if (_itemId == 0 || itemExists(q, _itemId)) revert QL__ItemAlreadyExists();

        if (q.last != 0) {
            q.items[q.last].next = _itemId;
        } else {
            q.first = _itemId;
        }

        q.items[_itemId] = Item({id: _itemId, prev: q.last, next: 0});
        q.last = _itemId;
    }

    //Eliminar index
    function remove(Queue storage q, bytes32 _itemId) internal {
        if (isEmpty(q)) revert QL__EmptyQueue();
        if (_itemId == 0 || !itemExists(q, _itemId)) revert QL__ItemDoesNotExist();

        Item memory removedItem = q.items[_itemId];
        delete q.items[_itemId];

        if (q.first == _itemId) {
            q.first = removedItem.next;
        }
        if (q.last == _itemId) {
            q.last = removedItem.prev;
        }

        if (removedItem.next != 0) {
            q.items[removedItem.next].prev = removedItem.prev;
        }

        if (removedItem.prev != 0) {
            q.items[removedItem.prev].next = removedItem.next;
        }
    }
}
