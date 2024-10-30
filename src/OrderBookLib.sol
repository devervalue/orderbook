// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./QueueLib.sol";
import "./RedBlackTreeLib.sol";
import "forge-std/console.sol";

library OrderBookLib {
    using RedBlackTreeLib for RedBlackTreeLib.Tree;
    using QueueLib for QueueLib.Queue;
    using QueueLib for QueueLib.Item;

    uint256 private constant ORDER_CREATED = 1;
    uint256 private constant ORDER_PARTIALLY_FILLED = 2;

    struct PricePoint {
        uint256 orderCount; // Total Orders of the Node
        uint256 orderValue; // Sum of the value of the orders
        QueueLib.Queue q;
    }

    struct Order {
        bytes32 id;
        uint256 price;
        uint256 quantity;
        uint256 availableQuantity;
        uint256 createdAt;
        uint256 status; //    ORDER_CREATED 1 / ORDER_PARTIALLY_FILLED 2
        address traderAddress;
        bool isBuy;
    }

    struct Book {
        RedBlackTreeLib.Tree tree;
        mapping(uint256 => PricePoint) prices; // Mapping of available prices to their corresponding orders and stats
    }

    // Order management functions

    function insert(Book storage b, bytes32 _orderId, uint256 _price, uint256 _quantity) internal {
        b.tree.insert(_price);

        PricePoint storage pricePoint = b.prices[_price];
        pricePoint.q.push(_orderId);
        pricePoint.orderCount = pricePoint.orderCount + 1;
        pricePoint.orderValue = pricePoint.orderValue + _quantity;
    }

    function remove(Book storage b, Order memory _order) internal {
        PricePoint storage price = b.prices[_order.price];
        price.orderCount = price.orderCount - 1;
        price.orderValue = price.orderValue - _order.availableQuantity;
        price.q.remove(_order.id);

        if (price.q.isEmpty()) {
            b.tree.remove(_order.price);
        }
    }

    function update(Book storage b, uint256 _pricePoint, uint256 _quantity) internal {
        PricePoint storage price = b.prices[_pricePoint];
        price.orderValue = price.orderValue - _quantity;
    }

    // Price-related functions

    function getLowestPrice(Book storage b) internal view returns (uint256) {
        return b.tree.first();
    }

    function getHighestPrice(Book storage b) internal view returns (uint256) {
        return b.tree.last();
    }

    function get3Prices(Book storage b, bool highest) internal view returns (uint256[3] memory) {
        uint256[3] memory prices;
        uint256 price = highest ? b.tree.last() : b.tree.first();

        for (uint256 i = 0; i < 3 && price != 0; i++) {
            prices[i] = price;
            price = highest ? b.tree.prev(price) : b.tree.next(price);
        }

        return prices;
    }

    // Utility functions

    function getNextOrderIdAtPrice(Book storage b, uint256 _price) internal view returns (bytes32) {
        return b.prices[_price].q.first;
    }

    function getPricePointData(Book storage b, uint256 _pricePoint) internal view returns (PricePoint storage) {
        return b.prices[_pricePoint];
    }
}
