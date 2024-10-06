// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./RedBlackTree.sol";
import "./OrderQueue.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PairLib} from "./PairLib.sol";


abstract contract OrderBook {
    using RedBlackTree for RedBlackTree.Tree;
    using OrderQueue for OrderQueue.Queue;
    using OrderQueue for OrderQueue.OrderBookNode;
    using SafeERC20 for IERC20;

    struct Price {
        uint256 countTotalOrders; // Total Orders of the Node
        uint256 countValueOrders; // Sum of the value of the orders
        OrderQueue.Queue q;
    }

    RedBlackTree.Tree public tree;
    mapping(uint256 => Price) internal prices; // Mapping of keys to their corresponding nodes

    function insert(
        bytes32 key,
        uint256 value,
        address _traderAddress,
        uint256 _quantity,
        uint256 nonce,
        uint256 _expired,
        bool _isBuy
    ) internal {

        tree.insert(value);

        Price storage price = prices[value];
        price.q.push(key);
        price.countTotalOrders = price.countTotalOrders + 1;
        price.countValueOrders = price.countValueOrders + _quantity;

    }

    function remove(PairLib.Order calldata order) public {
        Price storage price = prices[order.price];
        price.countTotalOrders = price.countTotalOrders - 1;
        price.countValueOrders = price.countValueOrders - order.quantity;
        price.q.removeOrder(order.orderId);

        if (price.q.isEmpty()) {
            tree.remove(order.price);
        }
    }

    function saveOrder(
        uint256 _price,
        uint256 _quantity,
        address _trader,
        uint256 nonce,
        uint256 _expired,
        bytes32 _orderId,
        address tokenAddress,
        uint256 transferQty,
        bool isBuy
    ) internal {
        //Transfiero los tokens al contrato
        console.log("Token", tokenAddress);
        IERC20 token = IERC20(tokenAddress);
        token.safeTransferFrom(_trader, address(this), transferQty); //Transfiero la cantidad indicada
        console.log("prueba");

        //Agregar al arbol
        insert(_orderId, _price, _trader, _quantity, nonce, _expired, isBuy);
    }

    function getNextOrderId( uint256 price) public view returns (bytes32){
        return prices[price].q.first;
    }

    function getNextPrice() public virtual view returns (uint256);
}

contract SellOrderBook is OrderBook {
    using RedBlackTree for RedBlackTree.Tree;


    function saveOrder(
        uint256 _price,
        uint256 _quantity,
        address _trader,
        uint256 nonce,
        uint256 _expired,
        bytes32 _orderId,
        address tokenAddress
    ) public {
        saveOrder(_price,_quantity,_trader,nonce,_expired,_orderId,tokenAddress,_quantity * _price, false);
    }

    function getNextPrice() public override view returns (uint256){
        return tree.first();
    }
}

contract BuyOrderBook is OrderBook {
    using RedBlackTree for RedBlackTree.Tree;


    function saveOrder(
        uint256 _price,
        uint256 _quantity,
        address _trader,
        uint256 nonce,
        uint256 _expired,
        bytes32 _orderId,
        address tokenAddress) public {
        saveOrder(_price,_quantity,_trader,nonce,_expired,_orderId,tokenAddress,_quantity,true);
    }

    function getNextPrice() public override view returns (uint256){
        return tree.last();
    }



}
