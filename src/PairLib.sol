// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";
import "./OrderBook.sol";

library PairLib {
    using SafeERC20 for IERC20;

    error PairLib__TraderDoesNotCorrespond();
    error PairLib__KeyDoesNotExist();
    error PairLib__KeyAlreadyExists();

    struct TraderOrders {
        bytes32[] orderIds;
        mapping(bytes32 => uint256) index;
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

    struct Pair {
        address baseToken;
        address quoteToken;
        address owner;
        address feeAddress;
        uint256 lastTradePrice;
        uint256 fee;
        bool status;
        BuyOrderBook buyOrders;
        SellOrderBook sellOrders;
        mapping(address => TraderOrders) traderOrders;
        mapping(bytes32 => Order) orders;
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

    function saveOrder(Pair storage pair, Order memory newOrder) private {
        if (keyExists(pair, newOrder.orderId)) revert PairLib__KeyAlreadyExists();

        pair.traderOrders[msg.sender].orderIds.push(newOrder.orderId);
        pair.traderOrders[msg.sender].index[newOrder.orderId] = pair.traderOrders[msg.sender].orderIds.length;

        //Agregar al arbol
        if (newOrder.isBuy) {
            pair.buyOrders.saveOrder(newOrder.price, newOrder.quantity, newOrder.orderId, pair.baseToken);
        } else {
            pair.sellOrders.saveOrder(newOrder.price, newOrder.quantity, newOrder.orderId, pair.quoteToken);
        }

        Order storage _newOrder = pair.orders[newOrder.orderId];
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
        Order storage matchedOrder,
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
        buyToken.transferFrom(address(this), msg.sender, buyTokenAmount); //Transfiero la cantidad que tiene la venta
        //Elimino la orden
        if (matchedOrder.isBuy) {
            pair.buyOrders.remove(matchedOrder);
        } else {
            pair.sellOrders.remove(matchedOrder);
        }
    }

    function partialFillOrder(
        Pair storage pair,
        Order storage matchedOrder,
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
        buyToken.safeTransferFrom(address(this), msg.sender, buyTokenAmount);
    }

    //Match orden de compra
    function matchOrder(Pair storage pair, uint256 orderCount, IERC20 buyToken, IERC20 sellToken, Order memory newOrder)
        private
        returns (uint256 _remainingQuantity, uint256 _orderCount)
    {
        uint256 matchingPrice = 0;
        bytes32 matchingOrderId = bytes32(uint256(0));

        if (newOrder.isBuy) {
            matchingPrice = pair.sellOrders.getNextPrice();
            matchingOrderId = pair.sellOrders.getNextOrderId(matchingPrice);
        } else {
            matchingPrice = pair.buyOrders.getNextPrice();
            matchingOrderId = pair.buyOrders.getNextOrderId(matchingPrice);
        }

        do {
            Order storage matchingOrder = getOrderDetail(pair, matchingOrderId);

            uint256 matchingOrderQty = matchingOrder.availableQuantity;

            if (newOrder.quantity >= matchingOrderQty) {
                fillOrder(
                    pair, matchingOrder, buyToken, sellToken, matchingOrderQty, matchingOrderQty * matchingOrder.price
                );
                //Actualizo la orden de compra disminuyendo la cantidad que ya tengo
                newOrder.quantity -= matchingOrderQty;
                //La cola tiene mas ordenes ?
                matchingOrderId = pair.sellOrders.getNextOrderId(matchingPrice);
                // Emito ejecucion de orden completada
                emit OrderExecuted(matchingOrder.orderId, pair.baseToken, pair.quoteToken, matchingOrder.traderAddress);
            } else {
                partialFillOrder(
                    pair, matchingOrder, buyToken, sellToken, newOrder.quantity, newOrder.quantity * matchingOrder.price
                );

                //Actualizar la OC restando la cantidad de la OE
                matchingOrder.availableQuantity = matchingOrderQty - newOrder.quantity;
                matchingOrder.status = 2; // Partial Fille TODO Pasar a constante
                newOrder.quantity = 0;

                //Emite el evento de orden entrante ejecutada
                emit OrderExecuted(newOrder.orderId, pair.baseToken, pair.quoteToken, msg.sender);

                //Emite el evento de orden de venta ejecutada parcialmente
                emit OrderPartialExecuted(
                    matchingOrder.orderId, pair.baseToken, pair.quoteToken, matchingOrder.traderAddress
                );
                return (newOrder.quantity, orderCount);
            }
            ++orderCount;
            console.log("orderCount Order:", orderCount);
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
        uint256 currentNode = pair.sellOrders.getNextPrice();
        console.log("currentNode", currentNode);
        console.log("addresss this", address(this));

        bytes32 _orderId = keccak256(abi.encodePacked(msg.sender, "buy", _price, nonce));

        Order memory newOrder = Order({
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

        console.logBytes32(_orderId);
        uint256 orderCount = 0;
        do {
            if (currentNode == 0 || orderCount >= 150) {
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
                    currentNode = pair.sellOrders.getNextPrice();
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
        uint256 currentNode = pair.buyOrders.getNextPrice();
        bytes32 _orderId = keccak256(abi.encodePacked(msg.sender, "sell", _price, nonce));
        uint256 orderCount = 0;

        Order memory newOrder = Order({
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

        do {
            if (currentNode == 0 || orderCount >= 150) {
                //NO
                saveOrder(pair, newOrder);
                return;
            } else {
                //SI
                //Precio de venta <= precio del nodo obtenido
                if (_price <= currentNode) {
                    //SI
                    //Aplico el match de ordenes de compra
                    (_quantity, orderCount) = matchOrder(pair, orderCount, buyToken, sellToken, newOrder);
                    newOrder.quantity = _quantity;
                    currentNode = pair.buyOrders.getNextPrice();
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
        Order memory removedOrder = pair.orders[_orderId];

        console.log(msg.sender);

        if (removedOrder.isBuy) {
            pair.buyOrders.remove(removedOrder);
        } else {
            pair.sellOrders.remove(removedOrder);
        }
        delete pair.orders[_orderId];

        // Reemplazar el elemento a eliminar con el último elemento del array
        pair.traderOrders[msg.sender].orderIds[pair.traderOrders[msg.sender].index[_orderId]] =
            pair.traderOrders[msg.sender].orderIds[pair.traderOrders[msg.sender].orderIds.length - 1];
        // Remover el último elemento
        pair.traderOrders[msg.sender].orderIds.pop();

        delete pair.traderOrders[msg.sender].index[_orderId];
    }

    function getTraderOrders(Pair storage pair, address _trader) public view returns (bytes32[] memory) {
        return pair.traderOrders[_trader].orderIds;
    }

    function getOrderDetail(Pair storage pair, bytes32 orderId) public view returns (Order storage) {
        if (keyExists(pair, orderId)) revert PairLib__KeyDoesNotExist();
        return pair.orders[orderId];
    }

    function keyExists(Pair storage pair, bytes32 key) internal view returns (bool _exists) {
        return pair.orders[key].orderId == 0;
    }
}
