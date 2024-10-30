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
        // TODO: Reorder variables to pack them more efficiently and reduce storage slots
        // uint256 and bytes32 variables should be grouped together
        bytes32 id;
        uint256 price;
        uint256 quantity;
        uint256 availableQuantity;
        uint256 createdAt;
        address traderAddress;
        bool isBuy;
        uint8 status; //    ORDER_CREATED 1 / ORDER_PARTIALLY_FILLED 2
    }

    struct Book {
        RedBlackTreeLib.Tree tree;
        mapping(uint256 => PricePoint) prices; // Mapping of available prices to their corresponding orders and stats
    }

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

    function getNextOrderIdAtPrice(Book storage b, uint256 _price) internal view returns (bytes32) {
        return b.prices[_price].q.first;
    }

    function getLowestPrice(Book storage b) internal view returns (uint256) {
        return b.tree.first();
    }

    function getHighestPrice(Book storage b) internal view returns (uint256) {
        return b.tree.last();
    }

    function get3HighestPrices(Book storage b) internal view returns (uint256[3] memory) {
        uint256 last = b.tree.last();
        uint256 last2 = last == 0 ? 0 : b.tree.prev(last);
        uint256 last3 = last2 == 0 ? 0 : b.tree.prev(last2);

        return [last, last2, last3];
    }

    function get3LowestPrices(Book storage b) internal view returns (uint256[3] memory) {
        uint256 first = b.tree.first();
        uint256 first2 = first == 0 ? 0 : b.tree.next(first);
        uint256 first3 = first2 == 0 ? 0 : b.tree.next(first2);

        return [first, first2, first3];
    }

    function getPricePointData(Book storage b, uint256 _pricePoint) internal view returns (PricePoint storage) {
        return b.prices[_pricePoint];
    }
}
