// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "../src/QueueLib.sol";
import "forge-std/console.sol";
import "../src/RedBlackTreeLib.sol";
import "../src/PairLib.sol";

contract OrderBookImpl {
    using PairLib for PairLib.Pair;
    using OrderBookLib for OrderBookLib.Order;
    using OrderBookLib for OrderBookLib.Book;
    using RedBlackTreeLib for RedBlackTreeLib.Tree;

    PairLib.Pair private pair;

    constructor(address tokenA, address tokenB) {
        pair.baseToken = tokenA;
        pair.quoteToken = tokenB;
        pair.lastTradePrice = 0;
        pair.status = true;
        pair.owner = address(0x6);
        pair.fee = 0x0;
        pair.feeAddress = address(0x7);
    }

    function lastTradePrice() public view returns (uint256 _lastTradePrice) {
        _lastTradePrice = pair.lastTradePrice;
    }

    function addBuyBaseToken(uint256 _price, uint256 _quantity, address _trader, uint256 nonce, uint256 _expired)
        public
    {
        pair.addBuyOrder(_price, _quantity, nonce, _expired);
    }

    function addSellBaseToken(uint256 _price, uint256 _quantity, address _trader, uint256 nonce, uint256 _expired)
        public
    {
        pair.addSellOrder(_price, _quantity, nonce, _expired);
    }

    function getFirstBuyOrders() public returns (uint256) {
        return pair.getLowestBuyPrice();
    }

    function getFirstSellOrders() public returns (uint256) {
        return pair.getLowestSellPrice();
    }

    function getLastBuyOrders() public returns (uint256) {
        return pair.getHighestBuyPrice();
    }

    function getLastSellOrders() public returns (uint256) {
        return pair.getHighestBuyPrice();
    }

    function getFirstOrderBuyById(uint256 keyNode) public returns (bytes32) {
        return pair.getNextBuyOrderId(keyNode);
    }

    function getCancelOrder(bytes32 _orderId) public {
        return pair.cancelOrder(_orderId);
    }

    function getTraderOrders(address _trader) public returns (bytes32[] memory) {
        return pair.getTraderOrders(_trader);
    }

    function getOrderById(address _trader, bytes32 _orderId) public returns (OrderBookLib.Order memory _order) {
        OrderBookLib.Order storage orderDetail = pair.getOrderDetail(_orderId);
        _order = OrderBookLib.Order({
            id: orderDetail.id,
            price: orderDetail.price,
            quantity: orderDetail.quantity,
            availableQuantity: orderDetail.availableQuantity,
            isBuy: orderDetail.isBuy,
            createdAt: orderDetail.createdAt,
            traderAddress: orderDetail.traderAddress,
            status: orderDetail.status
        });
    }
}
