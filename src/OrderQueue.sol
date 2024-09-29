// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library OrderQueue {
    /* Errors */
    error OrderQueue__CantPopAnEmptyQueue();
    error OrderQueue__CantRemoveFromAnEmptyQueue();

    /**
     *  @notice Structure of an order within the node.
     */
    struct OrderBookNode {
        bytes32 orderId;
        address traderAddress;
        bool isBuy;
        uint256 price;
        uint256 quantity;
        uint256 availableQuantity;
        uint8 status; //created 1 / partially filled 2 / filled 3 / cancelada 4
        uint256 expiresAt;
        uint256 createdAt;
        bytes32 next;
        bytes32 prev;
    }

    struct Queue {
        mapping(bytes32 => OrderBookNode) orders;
        bytes32 first;
        bytes32 last;
    }

    //Existe la orden
    function orderExists(Queue storage q, bytes32 _orderId) internal view returns (bool exists) {
        return q.orders[_orderId].orderId != 0;
    }

    //Cola Vacia
    function isEmpty(Queue storage q) internal view returns (bool empty) {
        return q.first == 0;
    }

    //Insertar
    function push(
        Queue storage q,
        address _traderAddress,
        bytes32 _orderId,
        uint256 _price,
        uint256 _quantity,
        uint256 nonce,
        uint256 _expired
    ) internal {
        //TODO QUE PASA SI INTENTO AGREGAR UN VALOR O ID QUE YA EXISTE ? PUEDE SUCEDER?
        if (q.first == 0) q.first = _orderId;
        if (q.last != 0) {
            q.orders[q.last].next = _orderId;
        }
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
    function pop(Queue storage q) internal returns (OrderBookNode memory _order) {
        if (q.first == 0) revert OrderQueue__CantPopAnEmptyQueue();

        OrderBookNode memory orderBookNode = q.orders[q.first];
        delete q.orders[q.first];
        q.first = orderBookNode.next;
        if (q.first == 0) {
            q.last = 0;
        } else {
            delete q.orders[q.first].prev;
            //queue.orders[first].prev = 0;
        }
        _order = orderBookNode;
    }

    //Eliminar index
    function removeOrder(Queue storage q, bytes32 orderId) internal {
        if (q.first == 0) revert OrderQueue__CantRemoveFromAnEmptyQueue();
        //TODO VERIFICAR QUE LA ORDEN EXISTA DEBEMOS VALIDAR?
        OrderBookNode memory orderBookNode = q.orders[orderId];
        delete q.orders[orderId];
        if (q.first == orderId) {
            q.first = orderBookNode.next;
        }
        if (q.last == orderId) {
            q.last = orderBookNode.prev;
        }

        if (orderBookNode.next != 0) {
            q.orders[orderBookNode.next].prev = orderBookNode.prev;
        }

        if (orderBookNode.prev != 0) {
            q.orders[orderBookNode.prev].next = orderBookNode.next;
        }
    }
}
