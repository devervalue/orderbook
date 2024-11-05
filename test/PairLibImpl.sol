// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "../src/QueueLib.sol";
import "forge-std/console.sol";
import "../src/RedBlackTreeLib.sol";
import "../src/PairLib.sol";

contract PairLibImpl {
    using PairLib for PairLib.Pair;
    using OrderBookLib for OrderBookLib.Order;
    using OrderBookLib for OrderBookLib.Book;
    using RedBlackTreeLib for RedBlackTreeLib.Tree;

    PairLib.Pair private pair;

    constructor(address tokenA, address tokenB) {
        pair.baseToken = tokenA;
        pair.quoteToken = tokenB;
        pair.lastTradePrice = 0;
        pair.enabled = true;
        pair.fee = 0x0;
        pair.feeAddress = address(0x7);
    }

    function disable() public {
        pair.enabled = false;
    }

    function lastTradePrice() public view returns (uint256 _lastTradePrice) {
        _lastTradePrice = pair.lastTradePrice;
    }

    function createOrder(bool isBuy, uint256 price, uint256 quantity) public {
        if (isBuy) {
            addBuyBaseToken(price, quantity, msg.sender, block.timestamp + price + quantity);
        } else {
            addSellBaseToken(price, quantity, msg.sender, block.timestamp + price + quantity);
        }
    }

    function addBuyBaseToken(uint256 _price, uint256 _quantity, address _trader, uint256 nonce) public {
        pair.addBuyOrder(_price, _quantity, nonce);
    }

    function addSellBaseToken(uint256 _price, uint256 _quantity, address _trader, uint256 nonce) public {
        pair.addSellOrder(_price, _quantity, nonce);
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

    function getFirstOrderBuyByPrice(uint256 _price) public returns (bytes32) {
        return pair.getNextBuyOrderId(_price);
    }

    function getCancelOrder(bytes32 _orderId) public {
        return pair.cancelOrder(_orderId);
    }

    function getTraderOrders(address _trader) public returns (bytes32[] memory) {
        return pair.getTraderOrders(_trader);
    }

    function getOrderById(bytes32 _orderId) public returns (OrderBookLib.Order memory _order) {
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

    function getTop3BuyPrices() public view returns (uint256[3] memory) {
        return pair.getTop3BuyPrices();
    }

    function getTop3SellPrices() public view returns (uint256[3] memory) {
        return pair.getTop3SellPrices();
    }

    function getPrice(uint256 price, bool isBuy) public view returns (uint256, uint256) {
        OrderBookLib.PricePoint storage pp = pair.getPrice(price, isBuy);
        return (pp.orderValue, pp.orderCount);
    }
}
