// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./RedBlackTree.sol";
import "./OrderQueue.sol";

contract OrderBook {
    using RedBlackTree for RedBlackTree.Tree;
    using OrderQueue for OrderQueue.Queue;
    using OrderQueue for OrderQueue.OrderBookNode;

    error OrderBook__ValueAndKeyPairExists();
    error OrderBook__KeyDoesNotExist();

    struct Price {
        uint256 countTotalOrders; // Total Orders of the Node
        uint256 countValueOrders; // Sum of the value of the orders
        OrderQueue.Queue q;
    }

    struct Order {
        // TODO: Reorder variables to pack them more efficiently and reduce storage slots
        // uint256 and bytes32 variables should be grouped together
        bytes32 orderId;
        address traderAddress;
        bool isBuy;
        uint256 price;
        uint256 quantity;
        uint256 availableQuantity;
        uint8 status; //created 1 / partially filled 2 / filled 3 / cancelada 4
        uint256 expiresAt;
        uint256 createdAt;
    }

    RedBlackTree.Tree private tree;
    mapping(uint256 => Price) private prices; // Mapping of keys to their corresponding nodes
    mapping(bytes32 => Order) private orders;

    constructor() {}

    function keyExists(bytes32 key) internal view returns (bool _exists) {
        return orders[key] == 0;
    }

    function insert(
        bytes32 key,
        uint256 value,
        address _traderAddress,
        uint256 _quantity,
        uint256 nonce,
        uint256 _expired,
        bool _isBuy
    ) internal {
        if (keyExists(key)) revert OrderBook__ValueAndKeyPairExists();

        tree.insert(value);

        Price storage price = prices[value];
        price.q.push(_traderAddress, key, value, _quantity, nonce, _expired);
        price.countTotalOrders = price.countTotalOrders + 1;
        price.countValueOrders = price.countValueOrders + _quantity;

        Order storage newOrder = orders[key];
        newOrder.orderId = key;
        newOrder.traderAddress = _traderAddress;
        newOrder.isBuy = _isBuy;
        newOrder.price = value;
        newOrder.quantity = _quantity;
        newOrder.availableQuantity = _quantity;
        newOrder.status = 1;
        newOrder.expiresAt = _expired;
        newOrder.createdAt = nonce;
    }

    function remove(bytes32 key) internal {
        if (!keyExists(key)) revert OrderBook__KeyDoesNotExist();

        Order memory removedOrder = orders[key];
        delete orders[key];
        Price storage price = prices[removedOrder.price];
        price.countTotalOrders = price.countTotalOrders - 1;
        price.countValueOrders = price.countValueOrders - removedOrder.quantity;
        price.q.removeOrder(key);

        if (price.q.isEmpty()) {
            tree.remove(removedOrder.price);
        }
    }

    function popOrder(uint256 value) internal {
        Price storage price = prices[value];
        bytes32 poppedOrderId = price.q.pop();
        Order poppedOrder = orders[poppedOrderId];
        price.countTotalOrders = price.countTotalOrders - 1;
        price.countValueOrders = price.countValueOrders - poppedOrder.quantity;

        delete orders[poppedOrderId];

        if (price.q.isEmpty()) {
            tree.remove(value);
        }
    }

    function getOrderDetail(bytes32 orderId) public view returns (Order memory) {
        if (keyExists(orderId)) revert OrderBook__KeyDoesNotExist();
        return orders[orderId];
    }
}
