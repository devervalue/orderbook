// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./RedBlackTree.sol";
import "./OrderQueue.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
        console.log(order.price);
        console.logBytes32(order.orderId);
        Price storage price = b.prices[order.price];
        price.countTotalOrders = price.countTotalOrders - 1;
        price.countValueOrders = price.countValueOrders - order.quantity;
        price.q.removeOrder(order.orderId);

        if (price.q.isEmpty()) {
            b.tree.remove(order.price);
        }
        console.log("REMOVE ALL");
    }

    function saveOrder(Book storage b, uint256 _price, uint256 _quantity, bytes32 _orderId, address tokenAddress, uint256 transferQty)
        internal
    {
        //Transfiero los tokens al contrato
        console.log("Token", tokenAddress);
        IERC20 token = IERC20(tokenAddress);
        console.log(msg.sender);
        token.safeTransferFrom(msg.sender, address(this), transferQty); //Transfiero la cantidad indicada
        console.log("prueba");

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
}
