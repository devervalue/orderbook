// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";
import "./OrderBookLib.sol";

library PairLib {
    using SafeERC20 for IERC20;
    using OrderBookLib for OrderBookLib.Order;
    using OrderBookLib for OrderBookLib.Book;
    using OrderBookLib for OrderBookLib.Price;

    error PairLib__TraderDoesNotCorrespond();
    error PairLib__KeyDoesNotExist();
    error PairLib__KeyAlreadyExists();

    struct TraderOrders {
        bytes32[] orderIds;
        mapping(bytes32 => uint256) index;
    }

    struct Pair {
        address baseToken;
        address quoteToken;
        address owner;
        address feeAddress;
        uint256 lastTradePrice;
        uint256 fee;
        bool status;
        OrderBookLib.Book buyOrders;
        OrderBookLib.Book sellOrders;
        mapping(address => TraderOrders) traderOrders;
        mapping(bytes32 => OrderBookLib.Order) orders;
    }

    /**
     *  @notice Evento que se emite cuando se crea una nueva orden.
     */
    event OrderCreated(bytes32 indexed id, address indexed baseToken, address indexed quoteToken, address trader);

    /**
     *  @notice Evento que se emite cuando se ejecutar una orden complete.
     */
    event OrderExecuted(bytes32 indexed id, address indexed baseToken, address indexed quoteToken, address trader);

    /**
     *  @notice Evento que se emite cuando se ejecuta una orden parcial.
     */
    event OrderPartialExecuted(
        bytes32 indexed id, address indexed baseToken, address indexed quoteToken, address trader
    );

    function abs(int256 x) private pure returns (int256) {
        return x >= 0 ? x : -x;
    }

    function saveOrder(Pair storage pair, OrderBookLib.Order memory newOrder) private {

        if (keyExists(pair, newOrder.orderId)) revert PairLib__KeyAlreadyExists();

        pair.traderOrders[msg.sender].orderIds.push(newOrder.orderId);
        pair.traderOrders[msg.sender].index[newOrder.orderId] = pair.traderOrders[msg.sender].orderIds.length - 1;

        //Agregar al arbol
        if (newOrder.isBuy) {
            pair.buyOrders.saveOrder(newOrder.price, newOrder.quantity, newOrder.orderId, pair.quoteToken, newOrder.quantity * newOrder.price / (10 ** 18));
        } else {
            pair.sellOrders.saveOrder(newOrder.price, newOrder.quantity, newOrder.orderId, pair.baseToken, newOrder.quantity);
        }

        OrderBookLib.Order storage _newOrder = pair.orders[newOrder.orderId];
        _newOrder.orderId = newOrder.orderId;
        _newOrder.traderAddress = msg.sender;
        _newOrder.isBuy = newOrder.isBuy;
        _newOrder.price = newOrder.price;
        _newOrder.quantity = newOrder.quantity;
        _newOrder.availableQuantity = newOrder.quantity;
        _newOrder.status = 1;
        _newOrder.expiresAt = newOrder.expiresAt;
        _newOrder.createdAt = newOrder.createdAt;
        //Emite el evento de orden creada
        emit OrderCreated(_newOrder.orderId, pair.baseToken, pair.quoteToken, msg.sender);
    }

    function fillOrder(
        Pair storage pair,
        OrderBookLib.Order storage matchedOrder,
        IERC20 buyToken,
        IERC20 sellToken,
        uint256 buyTokenAmount,
        uint256 sellTokenAmount
    ) private {
        //SI
        //Transfiero la cantidad de tokens de OE al vendedor
        pair.lastTradePrice = matchedOrder.price;
        sellToken.safeTransferFrom(msg.sender, matchedOrder.traderAddress, sellTokenAmount); //Multiplico la cantidad de tokens de venta por el precio de venta
        //Transfiero la cantidad de tokens de OV al comprador
        buyToken.safeTransfer(msg.sender, buyTokenAmount); //Transfiero la cantidad que tiene la venta
        //Elimino la orden
        if (matchedOrder.isBuy) {
            pair.buyOrders.remove(matchedOrder);
        } else {
            pair.sellOrders.remove(matchedOrder);
        }
    }

    function partialFillOrder(
        Pair storage pair,
        OrderBookLib.Order storage matchedOrder,
        IERC20 buyToken,
        IERC20 sellToken,
        uint256 buyTokenAmount,
        uint256 sellTokenAmount
    ) private {
        //NO
        //Transfiero la cantidad de tokens de OE al comprador
        pair.lastTradePrice = matchedOrder.price;
        sellToken.safeTransferFrom(msg.sender, matchedOrder.traderAddress, sellTokenAmount); //Multiplico la cantidad de tokens de venta por el precio de compra
        //Transfiero la cantidad de tokens de OC al vendedor
        buyToken.safeTransfer( msg.sender, buyTokenAmount);
    }

    //Match orden de compra
    function matchOrder(Pair storage pair, uint256 orderCount, IERC20 buyToken, IERC20 sellToken, OrderBookLib.Order memory newOrder)
        private
        returns (uint256 _remainingQuantity, uint256 _orderCount)
    {
        uint256 matchingPrice = 0;
        bytes32 matchingOrderId = bytes32(uint256(0));

        if (newOrder.isBuy) {
            matchingPrice = pair.sellOrders.getLowestPrice();
            matchingOrderId = pair.sellOrders.getNextOrderId(matchingPrice);
        } else {
            matchingPrice = pair.buyOrders.getHighestPrice();
            matchingOrderId = pair.buyOrders.getNextOrderId(matchingPrice);
        }

        do {
            OrderBookLib.Order storage matchingOrder = getOrderDetail(pair, matchingOrderId);

            uint256 matchingOrderQty = matchingOrder.availableQuantity;

            if (newOrder.quantity >= matchingOrderQty) {
                uint256 buyTokenAmount = newOrder.isBuy? matchingOrderQty : matchingOrderQty * matchingOrder.price / (10 ** 18);
                uint256 sellTokenAmount = newOrder.isBuy? matchingOrderQty * matchingOrder.price / (10 ** 18) : matchingOrderQty;
                fillOrder(
                    pair, matchingOrder, buyToken, sellToken, buyTokenAmount, sellTokenAmount
                );
                //Actualizo la orden de compra disminuyendo la cantidad que ya tengo
                newOrder.quantity -= matchingOrderQty;
                //La cola tiene mas ordenes ?
                matchingOrderId = pair.sellOrders.getNextOrderId(matchingPrice);
                removeFromTraderOrders(pair, matchingOrder.orderId, matchingOrder.traderAddress);

                // Emito ejecucion de orden completada
                emit OrderExecuted(matchingOrder.orderId, pair.baseToken, pair.quoteToken, matchingOrder.traderAddress);
            } else {

                uint256 buyTokenAmount = newOrder.isBuy? newOrder.quantity : newOrder.quantity * matchingOrder.price / (10 ** 18);
                uint256 sellTokenAmount = newOrder.isBuy? newOrder.quantity * matchingOrder.price / (10 ** 18) : newOrder.quantity;

                partialFillOrder(
                    pair, matchingOrder, buyToken, sellToken, buyTokenAmount, sellTokenAmount
                );

                //Actualizar la OC restando la cantidad de la OE
                matchingOrder.availableQuantity = matchingOrderQty - newOrder.quantity;
                matchingOrder.status = 2; // Partial Fille TODO Pasar a constante
                newOrder.quantity = 0;

                if (matchingOrder.isBuy) {
                    pair.buyOrders.update(matchingOrder);
                } else {
                    pair.sellOrders.update(matchingOrder);
                }

                //Emite el evento de orden entrante ejecutada
                emit OrderExecuted(newOrder.orderId, pair.baseToken, pair.quoteToken, msg.sender);

                //Emite el evento de orden de venta ejecutada parcialmente
                emit OrderPartialExecuted(
                    matchingOrder.orderId, pair.baseToken, pair.quoteToken, matchingOrder.traderAddress
                );
                return (newOrder.quantity, orderCount);
            }
            ++orderCount;
        } while (matchingOrderId != 0 && orderCount < 150);
        return (newOrder.quantity, orderCount);
    }

    //Agregar orden de compra
    function addBuyOrder(Pair storage pair, uint256 _price, uint256 _quantity, uint256 nonce, uint256 _expired)
        internal
    {
        //Obtengo los tokens
        IERC20 buyToken = IERC20(pair.baseToken);
        IERC20 sellToken = IERC20(pair.quoteToken);

        //¿Arbol de ventas tiene nodos?
        uint256 currentNode = pair.sellOrders.getLowestPrice();
        bytes32 _orderId = keccak256(abi.encodePacked(msg.sender, "buy", _price, nonce));

        OrderBookLib.Order memory newOrder = OrderBookLib.Order({
            orderId: _orderId,
            price: _price,
            quantity: _quantity,
            availableQuantity: _quantity,
            expiresAt: _expired,
            isBuy: true,
            createdAt: nonce,
            traderAddress: msg.sender,
            status: 1
        });

        uint256 orderCount = 0;
        do {
            console.log("CurrentNode: %d orderCount: %d", currentNode, orderCount);
        if (currentNode == 0 || orderCount >= 1500) {
                //NO
                saveOrder(pair, newOrder);
                return;
            } else {
                //SI
                //Precio de compra >= precio del nodo obtenido
                if (_price >= currentNode) {
                    //SI
                    //Aplico el match de ordenes de compra
                    (_quantity, orderCount) = matchOrder(pair, orderCount, buyToken, sellToken, newOrder);
                    newOrder.quantity = _quantity;
                    currentNode = pair.sellOrders.getLowestPrice();
                } else {
                    //NO
                    saveOrder(pair, newOrder);
                    return;
                }
            }
        } while (_quantity > 0);
    }

    //Agregar orden de venta
    function addSellOrder(Pair storage pair, uint256 _price, uint256 _quantity, uint256 nonce, uint256 _expired)
        internal
    {
        //Obtengo los tokens
        IERC20 buyToken = IERC20(pair.quoteToken);
        IERC20 sellToken = IERC20(pair.baseToken);


        //¿Arbol de compras tiene nodos?
        uint256 currentNode = pair.buyOrders.getHighestPrice();
        bytes32 _orderId = keccak256(abi.encodePacked(msg.sender, "sell", _price, nonce));
        uint256 orderCount = 0;

        OrderBookLib.Order memory newOrder = OrderBookLib.Order({
            orderId: _orderId,
            price: _price,
            quantity: _quantity,
            availableQuantity: _quantity,
            expiresAt: _expired,
            isBuy: false,
            createdAt: nonce,
            traderAddress: msg.sender,
            status: 1
        });

    do {
            if (currentNode == 0 || orderCount >= 1500) {
                //NO
                saveOrder(pair, newOrder);
                return;
            } else {
                //SI
                //Precio de compra <= precio del nodo obtenido
                if (_price <= currentNode) {
                    //SI
                    //Aplico el match de ordenes de compra
                    (_quantity, orderCount) = matchOrder(pair, orderCount, buyToken, sellToken, newOrder);
                    newOrder.quantity = _quantity;
                    currentNode = pair.buyOrders.getHighestPrice();
                } else {
                    //NO
                    saveOrder(pair, newOrder);
                    return;
                }
            }
        } while (_quantity > 0);
    }

    function cancelOrder(Pair storage pair, bytes32 _orderId) internal {
        if (!keyExists(pair, _orderId)) revert PairLib__KeyDoesNotExist();
        if (pair.orders[_orderId].traderAddress != msg.sender) revert PairLib__TraderDoesNotCorrespond();
        OrderBookLib.Order memory removedOrder = pair.orders[_orderId];

        if (removedOrder.isBuy) {
            pair.buyOrders.remove(removedOrder);
        } else {
            pair.sellOrders.remove(removedOrder);
        }
        delete pair.orders[_orderId];

        removeFromTraderOrders(pair, _orderId, msg.sender);

    }

    function removeFromTraderOrders(Pair storage pair, bytes32 _orderId, address traderAddress) internal {
        // Reemplazar el elemento a eliminar con el último elemento del array
        console.logBytes32(_orderId);
        TraderOrders storage to = pair.traderOrders[traderAddress];
        console.logAddress(traderAddress);

        uint256 deleteIndex = to.index[_orderId];
        console.log("DEL", deleteIndex);
        uint256 lastIndex = to.orderIds.length - 1;
        console.log("LAST", lastIndex);


    if (deleteIndex != lastIndex){
            to.orderIds[deleteIndex] = to.orderIds[lastIndex];
        }

        // actualizar el index de la orden movida
        to.index[to.orderIds[lastIndex]] = deleteIndex;

        // Remover el último elemento
        to.orderIds.pop();
        delete to.index[_orderId];
    }

    function getTraderOrders(Pair storage pair, address _trader) internal view returns (bytes32[] memory) {
        return pair.traderOrders[_trader].orderIds;
    }

    function getOrderDetail(Pair storage pair, bytes32 orderId) public view returns (OrderBookLib.Order storage) {
        if (!keyExists(pair, orderId)) revert PairLib__KeyDoesNotExist();
        return pair.orders[orderId];
    }

    function keyExists(Pair storage pair, bytes32 key) internal view returns (bool) {
        return pair.orders[key].orderId != bytes32(0);
    }

    function getLowestBuyPrice(Pair storage pair) internal view returns (uint256){
        return pair.buyOrders.getLowestPrice();
    }

    function getLowestSellPrice(Pair storage pair) internal view returns (uint256){
        return pair.sellOrders.getLowestPrice();
    }

    function getHighestBuyPrice(Pair storage pair) internal view returns (uint256){
        return pair.buyOrders.getHighestPrice();
    }

    function getHighestSellPrice(Pair storage pair) internal view returns (uint256){
        return pair.sellOrders.getHighestPrice();
    }

    function getNextBuyOrderId(Pair storage pair, uint256 price) internal view returns (bytes32){
        return pair.buyOrders.getNextOrderId(price);
    }

    function getNextSellOrderId(Pair storage pair, uint256 price) internal view returns (bytes32){
        return pair.sellOrders.getNextOrderId(price);
    }

    function getTop3BuyPrices(Pair storage pair) internal view returns (uint256[3] memory){
        return pair.buyOrders.getTop3BuyPrices();
    }

    function getTop3SellPrices(Pair storage pair) internal view returns (uint256[3] memory){
        return pair.sellOrders.getTop3BuyPrices();
    }

    function getPrice(Pair storage p, uint256 price, bool isBuy) internal view returns (OrderBookLib.Price storage){
        if (isBuy){
            return p.buyOrders.getPrice(price);
        }else {
            return p.sellOrders.getPrice(price);
        }
    }
}
