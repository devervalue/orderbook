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
        OrderQueue.Queue orders;
    }

    RedBlackTree.Tree private tree;
    mapping(uint256 => Price) private prices; // Mapping of keys to their corresponding nodes

    constructor(){

    }

    function keyExists(bytes32 key, uint256 value) internal view returns (bool _exists) {
        if (!tree.exists(value)) return false;
        return prices[value].orders.orderExists(key);
    }

    function insert(
        bytes32 key,
        uint256 value,
        address _traderAddress,
        uint256 _quantity,
        uint256 nonce,
        uint256 _expired
    ) internal {
        if (keyExists(key, value)) revert OrderBook__ValueAndKeyPairExists();

        tree.insert(value);

        Price storage price = prices[value];
        price.orders.push(_traderAddress, key, value, _quantity, nonce, _expired);
        price.countTotalOrders = price.countTotalOrders + 1;
        price.countValueOrders = price.countValueOrders + _quantity;

    }

    function remove(bytes32 key, uint256 value) internal {
        if (!keyExists(key, value)) revert OrderBook__KeyDoesNotExist();

        Price storage price = prices[value];
        price.countTotalOrders = price.countTotalOrders - 1;
        price.countValueOrders = price.countValueOrders - price.orders.orders[key].quantity;
        price.orders.removeOrder(key);

        if (price.orders.isEmpty()) {
            tree.remove(value);
        }

        }

    function popOrder(uint256 value) internal {
        Price storage price = prices[value];
        OrderQueue.OrderBookNode poppedOrder = price.orders.pop();
        price.countTotalOrders = price.countTotalOrders - 1;
        price.countValueOrders = price.countValueOrders - poppedOrder.quantity;

        if (price.orders.isEmpty()) {
            tree.remove(value);
        }
    }

    function getOrderDetail(bytes32 orderId, uint256 value) public view
    returns (OrderQueue.OrderBookNode memory)
    {
        if (prices[value].orders.orderExists(orderId)) revert OrderBook__KeyDoesNotExist();
        return prices[value].orders[orderId];
    }

    }




