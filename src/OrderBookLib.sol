// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./OrderBookLib.sol";
import "./OrderQueue.sol";
import "./RedBlackTree.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "forge-std/console.sol";

library OrderBookLib {
    using RedBlackTree for RedBlackTree.Tree;
    using OrderQueue for OrderQueue.Queue;
    using OrderQueue for OrderQueue.OrderBookNode;
    using SafeERC20 for IERC20;

    struct Price {
        uint256 countTotalOrders; // Total Orders of the Node
        uint256 countValueOrders; // Sum of the value of the orders
        OrderQueue.Queue q;
    }

    struct Order {
        // TODO: Reorder variables to pack them more efficiently and reduce storage slots
        // uint256 and bytes32 variables should be grouped together
        bytes32 orderId;
        uint256 price;
        uint256 quantity;
        uint256 availableQuantity;
        uint256 expiresAt;
        uint256 createdAt;
        address traderAddress;
        bool isBuy;
        uint8 status; //created 1 / partially filled 2 / filled 3 / cancelada 4
    }

    struct Book {
    RedBlackTree.Tree tree;
    mapping(uint256 => Price) prices; // Mapping of keys to their corresponding nodes
    }

    function insert(Book storage b, bytes32 key, uint256 value, uint256 _quantity) internal {
        b.tree.insert(value);

        Price storage price = b.prices[value];
        price.q.push(key);
        price.countTotalOrders = price.countTotalOrders + 1;
        price.countValueOrders = price.countValueOrders + _quantity;
    }

    function remove(Book storage b, Order calldata order) public {
        Price storage price = b.prices[order.price];
        price.countTotalOrders = price.countTotalOrders - 1;
        price.countValueOrders = price.countValueOrders - order.quantity;
        price.q.removeOrder(order.orderId);

        if (price.q.isEmpty()) {
            b.tree.remove(order.price);
        }
    }

    function update(Book storage b, Order calldata order, uint256 quantity) public {
        Price storage price = b.prices[order.price];
        price.countValueOrders = price.countValueOrders - quantity;
    }

    function saveOrder(Book storage b, uint256 _price, uint256 _quantity, bytes32 _orderId, address tokenAddress, uint256 transferQty)
        internal
    {
        //Transfiero los tokens al contrato
        IERC20 token = IERC20(tokenAddress);
        token.safeTransferFrom(msg.sender, address(this), transferQty); //Transfiero la cantidad indicada

        //Agregar al arbol
        insert(b,_orderId, _price, _quantity);
    }

    function getNextOrderId(Book storage b, uint256 price) internal view returns (bytes32) {
        return b.prices[price].q.first;
    }

    function getLowestPrice(Book storage b) internal view returns (uint256){
        return b.tree.first();
    }

    function getHighestPrice(Book storage b) internal view returns (uint256){
        return b.tree.last();
    }

    function getTop3BuyPrices(Book storage b) internal view returns (uint256[3] memory){
        uint256 last = b.tree.last();
        uint256 last2 = last == 0? 0: b.tree.prev(last);
        uint256 last3 = last2 == 0? 0: b.tree.prev(last2);

        return [last, last2, last3];
    }

    function getTop3SellPrices(Book storage b) internal view returns (uint256[3] memory){
        uint256 first = b.tree.first();
        uint256 first2 = first == 0? 0: b.tree.next(first);
        uint256 first3 = first2 == 0? 0: b.tree.next(first2);

        return [first, first2, first3];
    }

    function getPrice(Book storage b, uint256 price) internal view returns (Price storage){
        return b.prices[price];
    }
}
