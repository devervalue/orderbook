// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
pragma experimental ABIEncoderV2;

import "./OrderQueue.sol";
import "./RedBlackTree.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

library OrderBookLib {
    using RedBlackTree for RedBlackTree.Tree;
    using OrderQueue for OrderQueue.Queue;
    using OrderQueue for OrderQueue.OrderBookNode;
    using SafeERC20 for IERC20;

    error OrderBookLib__TraderDoesNotCorrespond();


    struct Order {
        address traderAddress; // Trader Address
        bytes32 orderId; //Define Order Id (Hash keccak256(traderAddress,orderType,price,createdAt)
        uint256 price;
        bool isBuy;
        uint256 index;
    }

    struct TraderOrders {
        bytes32[] orderIds;
        mapping(bytes32 => Order) orders;
    }

    struct OrderBook {
        address baseToken;
        address quoteToken;
        RedBlackTree.Tree buyOrders;
        RedBlackTree.Tree sellOrders;
        uint256 lastTradePrice;
        bool status;
        address owner;
        uint256 fee;
        address feeAddress;
        mapping(address => TraderOrders) traderOrders;
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

    /*
     - Agregar compra / venta a un libro (Según el token base y quote, se decide si es compra o es
     venta en relación al libro, en el front y se envia unicamente si es compra o venta, con enum o
      booleano): Al crear una nueva orden se debe validar si existe una orden contraria que se
      pueda emparejar para ejecución inmediata, luego con el balance restante se agrega la orden
      al árbol correspondiente
    Buscar compras / ventas : Buscar para las compras, ventas que tengan un precio menor o igual. Para las ventas, buscar compras con un precio mayor o igual.
    Ejecutar orden y eliminar la orden completada de la lista de órdenes
    Cancelar orden
    Obtener lista de órdenes

    */

    /*function matchBuyOrder(OrderBook storage book, uint _price, uint _quantity) internal {
        uint256 firstSell = book.sellOrders.first();
        if(_price < firstSell) return;
        RedBlackTree.Node node = book.sellOrders.getNode(firstSell); //Get node
        node.orders.orders[node.orders.first];

    }*/

    //Agregar orden de compra
    function addBuyOrder(
        OrderBook storage book,
        uint256 _price,
        uint256 _quantity,
        address _trader,
        uint256 nonce,
        uint256 _expired
    ) internal {
        //¿Arbol de ventas tiene nodos?
        uint256 currentNode = book.sellOrders.first();
        console.log("currentNode", currentNode);
        console.log("addresss this", address(this));

        bytes32 _orderId = keccak256(abi.encodePacked(_trader, "buy", _price, nonce));
        console.logBytes32(_orderId);
        uint256 orderCount = 0;
        do {
            if (currentNode == 0 || orderCount >= 150) {
                //NO
                saveBuyOrder(book, _price, _quantity, _trader, nonce, _expired, _orderId);
                return;
            } else {
                //SI
                //Precio de compra >= precio del nodo obtenido
                if (_price >= currentNode) {
                    //SI
                    //Aplico el match de ordenes de compra
                    (_quantity, orderCount) =
                        matchOrderBuy(currentNode, book, _price, _quantity, _trader, _orderId, orderCount);
                    currentNode = book.sellOrders.first();
                } else {
                    //NO
                    saveBuyOrder(book, _price, _quantity, _trader, nonce, _expired, _orderId);
                    return;
                }
            }
        } while (_quantity > 0);
    }

    //Agregar orden de venta
    function addSellOrder(
        OrderBook storage book,
        uint256 _price,
        uint256 _quantity,
        address _trader,
        uint256 nonce,
        uint256 _expired
    ) internal {
        //¿Arbol de compras tiene nodos?
        uint256 currentNode = book.buyOrders.last();
        bytes32 _orderId = keccak256(abi.encodePacked(_trader, "sell", _price, nonce));
        uint256 orderCount = 0;

        do {
            if (currentNode == 0 || orderCount >= 150) {
                //NO
                saveSellOrder(book, _price, _quantity, _trader, nonce, _expired, _orderId);
                return;
            } else {
                //SI
                //Precio de venta <= precio del nodo obtenido
                if (_price <= currentNode) {
                    //SI
                    //Aplico el match de ordenes de compra
                    (_quantity, orderCount) = matchOrderSell(book, _price, _quantity, _trader, _orderId, orderCount);
                    currentNode = book.sellOrders.last();
                } else {
                    //NO
                    saveSellOrder(book, _price, _quantity, _trader, nonce, _expired, _orderId);
                    return;
                }
            }
        } while (_quantity > 0);
    }

    //Guardar orden de compra
    function saveBuyOrder(
        OrderBook storage book,
        uint256 _price,
        uint256 _quantity,
        address _trader,
        uint256 nonce,
        uint256 _expired,
        bytes32 _orderId
    ) private {
        //Transfiero los tokens al contrato
        console.log("baseToken", book.baseToken);
        IERC20 baseTokenContract = IERC20(book.baseToken);
        baseTokenContract.safeTransferFrom(_trader, address(this), _quantity); //Transfiero la cantidad que tiene la compra
        console.log("prueba");

        Order memory order = Order({
            orderId: _orderId,
            traderAddress: _trader,
            price: _price,
            isBuy: true,
            index: book.traderOrders[_trader].orderIds.length
        });

        book.traderOrders[_trader].orderIds.push(_orderId);
        book.traderOrders[_trader].orders[_orderId] = order;

        //Agregar al arbol
        book.buyOrders.insert(_orderId, _price, _trader, _quantity, nonce, _expired);
        //Emite el evento de orden creada
        emit OrderCreated(_orderId, book.baseToken, book.quoteToken, _trader);
    }

    //Guardar orden de venta
    function saveSellOrder(
        OrderBook storage book,
        uint256 _price,
        uint256 _quantity,
        address _trader,
        uint256 nonce,
        uint256 _expired,
        bytes32 _orderId
    ) private {
        //Transfiero los tokens al contrato
        console.log("quoteToken", book.quoteToken);
        IERC20 quoteTokenContract = IERC20(book.quoteToken);
        quoteTokenContract.safeTransferFrom(_trader, address(this), _quantity * _price); //Transfiero la cantidad que tiene la venta
        console.log("prueba");

        Order memory order = Order({
            orderId: _orderId,
            traderAddress: _trader,
            price: _price,
            isBuy: false,
            index: book.traderOrders[_trader].orderIds.length
        });

        book.traderOrders[_trader].orderIds.push(_orderId);
        book.traderOrders[_trader].orders[_orderId] = order;

        //Agregar al arbol
        book.sellOrders.insert(_orderId, _price, _trader, _quantity, nonce, _expired);
        //Emite el evento de orden creada
        emit OrderCreated(_orderId, book.baseToken, book.quoteToken, _trader);
    }

    //Match orden de compra
    function matchOrderBuy(
        uint256 firstOrder,
        OrderBook storage book,
        uint256 _price,
        uint256 quantityBuy,
        address traderBuy,
        bytes32 orderIdBuy,
        uint256 orderCount
    ) private returns (uint256 _remainingQuantity, uint256 _orderCount) {
        //Obtento la cola de ordenes del nodo
        //RedBlackTree.Node storage node = getNode(book,firstOrder); //Get node //Todo revisar si retornamos el Nodo completo
        RedBlackTree.Node storage node = book.sellOrders.getNode(firstOrder); //Get node
        //Obtengo la primera orden
        //OrderQueue.OrderBookNode storage orderBookNode = node.orders.orders[node.orders.first];
        bytes32 currentOrder = node.orders.first;
        //Obtengo los tokens
        IERC20 baseTokenContract = IERC20(book.baseToken);
        IERC20 quoteTokenContract = IERC20(book.quoteToken);
        do {
            OrderQueue.OrderBookNode storage orderBookNode = node.orders.orders[currentOrder];
            //OE >= Cantidad de OV
            uint256 quantitySell = orderBookNode.availableQuantity;
            if (quantityBuy >= quantitySell) {
                //SI
                //Transfiero la cantidad de tokens de OE al vendedor
                baseTokenContract.safeTransferFrom(
                    traderBuy, orderBookNode.traderAddress, quantitySell * orderBookNode.price
                ); //Multiplico la cantidad de tokens de venta por el precio de venta
                //Transfiero la cantidad de tokens de OV al comprador
                quoteTokenContract.transferFrom(address(this), traderBuy, quantitySell); //Transfiero la cantidad que tiene la venta
                //Actualizo la orden de compra disminuyendo la cantidad que ya tengo
                quantityBuy -= quantitySell;
                //La cola tiene mas ordenes ?
                currentOrder = orderBookNode.next;
                //Elimino la orden de venta
                book.sellOrders.popOrder(orderBookNode.price);
            } else {
                //NO
                quantityBuy = executePartial(
                    baseTokenContract, quoteTokenContract, traderBuy, quantityBuy, quantitySell, orderBookNode
                );
                //Emite el evento de orden entrante ejecutada
                emit OrderExecuted(orderIdBuy, book.baseToken, book.quoteToken, traderBuy);

                //Emite el evento de orden de venta ejecutada parcialmente
                emit OrderPartialExecuted(
                    orderBookNode.orderId, book.baseToken, book.quoteToken, orderBookNode.traderAddress
                );
                return (quantityBuy, orderCount);
            }
            ++orderCount;
            console.logBytes32(currentOrder);
            console.log("orderCount Order:", orderCount);
        } while (currentOrder != 0 && orderCount < 150);
        return (quantityBuy, orderCount);
    }

    function executePartial(
        IERC20 baseTokenContract,
        IERC20 quoteTokenContract,
        address traderBuy,
        uint256 quantityBuy,
        uint256 quantitySell,
        OrderQueue.OrderBookNode memory orderBookNode
    ) private returns (uint256) {
        //Transfiero la cantidad de tokens de OE al vendedor
        uint256 pValue = quantityBuy * orderBookNode.price;
        baseTokenContract.safeTransferFrom(traderBuy, orderBookNode.traderAddress, pValue); //Multiplico la cantidad de tokens de compra por el precio de venta
        //Transfiero la cantidad de tokens de OV al comprador
        quoteTokenContract.safeTransferFrom(address(this), traderBuy, quantityBuy);
        //Actualizar la OV restando la cantidad de la OE
        orderBookNode.availableQuantity = quantitySell - quantityBuy;
        quantityBuy = 0;
        //Emite el evento de orden entrante ejecutada
        //emit OrderExecuted(orderIdBuy, bookBaseToken, bookQuoteToken, traderBuy);

        //Emite el evento de orden de venta ejecutada parcialmente
        //emit OrderPartialExecuted(orderBookNode.orderId, bookBaseToken, bookQuoteToken, orderBookNode.traderAddress);
        return quantityBuy;
    }

    //Match orden de compra
    function matchOrderSell(
        OrderBook storage book,
        uint256 _price,
        uint256 quantitySell,
        address traderSell,
        bytes32 orderIdSell,
        uint256 orderCount
    ) private returns (uint256 _remainingQuantity, uint256 _orderCount) {
        //Obtento la cola de ordenes del nodo
        //RedBlackTree.Node storage node = getNode(book,firstOrder); //Get node //Todo revisar si retornamos el Nodo completo
        RedBlackTree.Node storage node = book.buyOrders.getNode(book.buyOrders.last()); //Get node
        //Obtengo la primera orden
        //OrderQueue.OrderBookNode storage orderBookNode = node.orders.orders[node.orders.first];
        bytes32 currentOrder = node.orders.first;
        //Obtengo los tokens
        IERC20 baseTokenContract = IERC20(book.baseToken);
        IERC20 quoteTokenContract = IERC20(book.quoteToken);
        do {
            OrderQueue.OrderBookNode storage orderBookNode = node.orders.orders[currentOrder];
            //OE >= Cantidad de OV
            uint256 quantityBuy = orderBookNode.availableQuantity;
            if (quantitySell >= quantityBuy) {
                //SI
                //Transfiero la cantidad de tokens de OE al comprador
                quoteTokenContract.safeTransferFrom(
                    traderSell, orderBookNode.traderAddress, quantityBuy * orderBookNode.price
                ); //Multiplico la cantidad de tokens de compra por el precio de compra
                //Transfiero la cantidad de tokens de OC al comprador
                baseTokenContract.safeTransferFrom(address(this), traderSell, quantityBuy); //Transfiero la cantidad que tiene la compra
                //Actualizo la orden de venta disminuyendo la cantidad que ya tengo
                quantitySell -= quantityBuy;
                //La cola tiene mas ordenes ?
                currentOrder = orderBookNode.next;
                //Elimino la orden de compra
                book.buyOrders.popOrder(orderBookNode.price);
            } else {
                //NO
                //Transfiero la cantidad de tokens de OE al comprador
                quoteTokenContract.safeTransferFrom(
                    traderSell, orderBookNode.traderAddress, quantitySell * orderBookNode.price
                ); //Multiplico la cantidad de tokens de venta por el precio de compra
                //Transfiero la cantidad de tokens de OC al vendedor
                baseTokenContract.safeTransferFrom(address(this), traderSell, quantitySell);
                //Actualizar la OC restando la cantidad de la OE
                orderBookNode.availableQuantity = quantityBuy - quantitySell;
                quantitySell = 0;
                //Emite el evento de orden entrante ejecutada
                emit OrderExecuted(orderIdSell, book.baseToken, book.quoteToken, traderSell);

                //Emite el evento de orden de venta ejecutada parcialmente
                emit OrderPartialExecuted(
                    orderBookNode.orderId, book.baseToken, book.quoteToken, orderBookNode.traderAddress
                );
                return (quantitySell, orderCount);
            }
            ++orderCount;
        } while (currentOrder != 0 && orderCount < 150);
        return (quantitySell, orderCount);
    }

    function cancelOrder(OrderBook storage book, bytes32 _orderId) internal {
        console.log(msg.sender);
        console.logBytes32(book.traderOrders[msg.sender].orderIds[0]);
        bytes32 pp = book.traderOrders[msg.sender].orderIds[0];
        console.logBytes32(book.traderOrders[msg.sender].orders[pp].orderId);
        Order memory _order = book.traderOrders[msg.sender].orders[_orderId];
        console.logBytes32(_orderId);
        console.log(_order.price);
        if (_order.isBuy) {
            book.buyOrders.remove(_orderId, _order.price);
        } else {
            book.sellOrders.remove(_orderId, _order.price);
        }
        delete book.traderOrders[msg.sender].orders[_orderId];
        // Reemplazar el elemento a eliminar con el último elemento del array
        book.traderOrders[msg.sender].orderIds[_order.index] =
            book.traderOrders[msg.sender].orderIds[book.traderOrders[msg.sender].orderIds.length - 1];
        // Remover el último elemento
        book.traderOrders[msg.sender].orderIds.pop();
    }

    function getTraderOrders(OrderBook storage book, address _trader) public view returns (bytes32[] memory) {
        return book.traderOrders[_trader].orderIds;
    }

    function getOrderById(OrderBook storage book, address _trader, bytes32 _orderId)
        public
        returns (OrderQueue.OrderBookNode memory)
    {
        Order memory _order = book.traderOrders[_trader].orders[_orderId];
        if (_order.isBuy) {
            return book.buyOrders.getOrderDetail(_orderId, _order.price);
        } else {
            return book.sellOrders.getOrderDetail(_orderId, _order.price);
        }
    }
}
