// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "../src/OrderQueue.sol";
import "forge-std/console.sol";
import "../src/RedBlackTree.sol";
import "../src/OrderBookLib.sol";

contract OrderBookImpl {
    using OrderBookLib for OrderBookLib.OrderBook;
    using RedBlackTree for RedBlackTree.Tree;

    OrderBookLib.OrderBook private book;

    constructor(address tokenA, address tokenB) public {
        book.baseToken = tokenA;
        book.quoteToken = tokenB;
        book.lastTradePrice = 0;
        book.status = true;
        book.owner = address(0x6);
        book.fee = 0x0;
        book.feeAddress = address(0x7);
    }

    function lastTradePrice() public view returns (uint256 _lastTradePrice) {
        _lastTradePrice = book.lastTradePrice;
    }

    function addBuyBaseToken(uint256 _price, uint256 _quantity, address _trader, uint256 nonce, uint256 _expired)
        public
    {
        book.addBuyOrder(_price, _quantity, _trader, nonce, _expired);
    }

    function addSellBaseToken(uint256 _price, uint256 _quantity, address _trader, uint256 nonce, uint256 _expired)
        public
    {
        book.addSellOrder(_price, _quantity, _trader, nonce, _expired);
    }

    function getFirstBuyOrders() public returns (uint256) {
        return book.buyOrders.first();
    }

    function getFirstSellOrders() public returns (uint256) {
        return book.sellOrders.first();
    }

    function getLastBuyOrders() public returns (uint256) {
        return book.buyOrders.last();
    }

    function getLastSellOrders() public returns (uint256) {
        return book.sellOrders.last();
    }

    function getFirstOrderBuyById(uint256 keyNode) public returns (bytes32) {
        return book.buyOrders.nodes[keyNode].orders.first;
    }

    function getCancelOrder(bytes32 _orderId) public {
        return book.cancelOrder(_orderId);
    }

    function getTraderOrders(address _trader) public returns (bytes32[] memory) {
        return book.getTraderOrders(_trader);
    }

    function getOrderById(address _trader, bytes32 _orderId) public returns (OrderQueue.OrderBookNode memory) {
        return book.getOrderById(_trader, _orderId);
    }
}
