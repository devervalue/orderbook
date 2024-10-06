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
        address traderAddress;
        bool isBuy;
        uint256 price;
        uint256 quantity;
        uint256 availableQuantity;
        uint8 status; //created 1 / partially filled 2 / filled 3 / cancelada 4
        uint256 expiresAt;
        uint256 createdAt;
    }

    struct Pair {
        address baseToken;
        address quoteToken;
        BuyOrderBook buyOrders;
        SellOrderBook sellOrders;
        uint256 lastTradePrice;
        bool status;
        address owner;
        uint256 fee;
        address feeAddress;
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


    function saveBuyOrder(
        Pair storage pair,
        uint256 _price,
        uint256 _quantity,
        address _trader,
        uint256 nonce,
        uint256 _expired,
        bytes32 _orderId
    ) private {

        if (keyExists(pair, _orderId)) revert PairLib__KeyAlreadyExists();

        pair.traderOrders[_trader].orderIds.push(_orderId);
        pair.traderOrders[_trader].index[_orderId] = pair.traderOrders[_trader].orderIds.length;

        //Agregar al arbol
        pair.buyOrders.saveOrder(_price, _quantity, _trader, nonce, _expired, _orderId, pair.baseToken);

        Order storage newOrder = pair.orders[_orderId];
        newOrder.orderId = _orderId;
        newOrder.traderAddress = _trader;
        newOrder.isBuy = false;
        newOrder.price = _price;
        newOrder.quantity = _quantity;
        newOrder.availableQuantity = _quantity;
        newOrder.status = 1;
        newOrder.expiresAt = _expired;
        newOrder.createdAt = nonce;

        //Emite el evento de orden creada
        emit OrderCreated(_orderId, pair.baseToken, pair.quoteToken, _trader);
    }

    //Guardar orden de venta
    function saveSellOrder(
        Pair storage pair,
        uint256 _price,
        uint256 _quantity,
        address _trader,
        uint256 nonce,
        uint256 _expired,
        bytes32 _orderId
    ) private {

        if (keyExists(pair, _orderId)) revert PairLib__KeyAlreadyExists();

        pair.traderOrders[_trader].orderIds.push(_orderId);
        pair.traderOrders[_trader].index[_orderId] = pair.traderOrders[_trader].orderIds.length;

        //Agregar al arbol
        pair.sellOrders.saveOrder(_price, _quantity, _trader, nonce, _expired, _orderId, pair.baseToken);

        Order storage newOrder = pair.orders[_orderId];
        newOrder.orderId = _orderId;
        newOrder.traderAddress = _trader;
        newOrder.isBuy = false;
        newOrder.price = _price;
        newOrder.quantity = _quantity;
        newOrder.availableQuantity = _quantity;
        newOrder.status = 1;
        newOrder.expiresAt = _expired;
        newOrder.createdAt = nonce;
        //Emite el evento de orden creada
        emit OrderCreated(_orderId, pair.baseToken, pair.quoteToken, _trader);
    }

    //Match orden de compra
    function matchOrderBuy(
        Pair storage pair,
        uint256 _price,
        uint256 quantityBuy,
        address traderBuy,
        bytes32 orderIdBuy,
        uint256 orderCount
    ) private returns (uint256 _remainingQuantity, uint256 _orderCount) {
        uint256 lowestSellPrice = pair.sellOrders.getNextPrice();
        bytes32 currentOrderId = pair.sellOrders.getNextOrderId(lowestSellPrice);

        //Obtengo los tokens
        IERC20 baseTokenContract = IERC20(pair.baseToken);
        IERC20 quoteTokenContract = IERC20(pair.quoteToken);

        do {
            Order memory currentOrder = getOrderDetail(pair, currentOrderId);

            uint256 quantitySell = currentOrder.availableQuantity;

            if (quantityBuy >= quantitySell) {
                //SI
                //Transfiero la cantidad de tokens de OE al vendedor
                pair.lastTradePrice = currentOrder.price;
                baseTokenContract.safeTransferFrom(
                    traderBuy, currentOrder.traderAddress, quantitySell * currentOrder.price
                ); //Multiplico la cantidad de tokens de venta por el precio de venta
                //Transfiero la cantidad de tokens de OV al comprador
                quoteTokenContract.transferFrom(address(this), traderBuy, quantitySell); //Transfiero la cantidad que tiene la venta
                //Actualizo la orden de compra disminuyendo la cantidad que ya tengo
                quantityBuy -= quantitySell;
                //La cola tiene mas ordenes ?
                currentOrderId = pair.sellOrders.getNextOrderId(lowestSellPrice);
                //Elimino la orden de venta
                pair.sellOrders.remove(currentOrder);
            } else {
                //NO
                quantityBuy = executePartial(
                    baseTokenContract, quoteTokenContract, traderBuy, quantityBuy, quantitySell, currentOrder
                );
                pair.lastTradePrice = currentOrder.price;

                //Emite el evento de orden entrante ejecutada
                emit OrderExecuted(orderIdBuy, pair.baseToken, pair.quoteToken, traderBuy);

                //Emite el evento de orden de venta ejecutada parcialmente
                emit OrderPartialExecuted(
                    currentOrder.orderId, pair.baseToken, pair.quoteToken, currentOrder.traderAddress
                );
                return (quantityBuy, orderCount);
            }
            ++orderCount;
            console.log("orderCount Order:", orderCount);

        } while (currentOrderId != 0 && orderCount < 150);
        return (quantityBuy, orderCount);

    }

    //Match orden de compra
    function matchOrderSell(
        Pair storage pair,
        uint256 _price,
        uint256 quantitySell,
        address traderSell,
        bytes32 orderIdSell,
        uint256 orderCount
    ) private returns (uint256 _remainingQuantity, uint256 _orderCount) {
        uint256 highestBuyPrice = pair.buyOrders.getNextPrice();
        bytes32 currentOrderId = pair.sellOrders.getNextOrderId(highestBuyPrice);

        //Obtengo los tokens
        IERC20 baseTokenContract = IERC20(pair.baseToken);
        IERC20 quoteTokenContract = IERC20(pair.quoteToken);

        do {
            Order memory currentOrder = getOrderDetail(pair, currentOrderId);

            uint256 quantityBuy = currentOrder.availableQuantity;

            if (quantitySell >= quantityBuy) {
                //SI
                //Transfiero la cantidad de tokens de OE al vendedor
                pair.lastTradePrice = currentOrder.price;
                quoteTokenContract.safeTransferFrom(
                    traderSell, currentOrder.traderAddress, quantityBuy * currentOrder.price
                ); //Multiplico la cantidad de tokens de venta por el precio de venta
                //Transfiero la cantidad de tokens de OV al comprador
                baseTokenContract.transferFrom(address(this), traderSell, quantityBuy); //Transfiero la cantidad que tiene la venta
                //Actualizo la orden de compra disminuyendo la cantidad que ya tengo
                quantitySell -= quantityBuy;
                //La cola tiene mas ordenes ?
                currentOrderId = pair.buyOrders.getNextOrderId(highestBuyPrice);
                //Elimino la orden de venta
                pair.buyOrders.remove(currentOrder);
            } else {
                //NO
                //Transfiero la cantidad de tokens de OE al comprador
                pair.lastTradePrice = currentOrder.price;
                quoteTokenContract.safeTransferFrom(
                    traderSell, currentOrder.traderAddress, quantitySell * currentOrder.price
                ); //Multiplico la cantidad de tokens de venta por el precio de compra
                //Transfiero la cantidad de tokens de OC al vendedor
                baseTokenContract.safeTransferFrom(address(this), traderSell, quantitySell);
                //Actualizar la OC restando la cantidad de la OE
                currentOrder.availableQuantity = quantityBuy - quantitySell;
                currentOrder.status = 2; // Partial Fille TODO Pasar a constante
                quantitySell = 0;
                //Emite el evento de orden entrante ejecutada
                emit OrderExecuted(orderIdSell, pair.baseToken, pair.quoteToken, traderSell);

                //Emite el evento de orden de venta ejecutada parcialmente
                emit OrderPartialExecuted(
                    currentOrder.orderId, pair.baseToken, pair.quoteToken, currentOrder.traderAddress
                );
                return (quantitySell, orderCount);
            }
            ++orderCount;
            console.log("orderCount Order:", orderCount);

        } while (currentOrderId != 0 && orderCount < 150);
        return (quantitySell, orderCount);

    }

    function executePartial(
        IERC20 baseTokenContract,
        IERC20 quoteTokenContract,
        address traderBuy,
        uint256 quantityBuy,
        uint256 quantitySell,
        Order memory order
    ) private returns (uint256) {
        //Transfiero la cantidad de tokens de OE al vendedor
        uint256 pValue = quantityBuy * order.price;
        baseTokenContract.safeTransferFrom(traderBuy, order.traderAddress, pValue); //Multiplico la cantidad de tokens de compra por el precio de venta
        //Transfiero la cantidad de tokens de OV al comprador
        quoteTokenContract.safeTransferFrom(address(this), traderBuy, quantityBuy);
        //Actualizar la OV restando la cantidad de la OE
        order.availableQuantity = quantitySell - quantityBuy;
        order.status = 2; // Partial filled TODO Pasar a constantes
        quantityBuy = 0;
        //Emite el evento de orden entrante ejecutada
        //emit OrderExecuted(orderIdBuy, bookBaseToken, bookQuoteToken, traderBuy);

        //Emite el evento de orden de venta ejecutada parcialmente
        //emit OrderPartialExecuted(orderBookNode.orderId, bookBaseToken, bookQuoteToken, orderBookNode.traderAddress);
        return quantityBuy;
    }

    //Agregar orden de compra
    function addBuyOrder(
        Pair storage pair,
        uint256 _price,
        uint256 _quantity,
        address _trader,
        uint256 nonce,
        uint256 _expired
    ) internal {
        //¿Arbol de ventas tiene nodos?
        uint256 currentNode = pair.sellOrders.getNextPrice();
        console.log("currentNode", currentNode);
        console.log("addresss this", address(this));

        bytes32 _orderId = keccak256(abi.encodePacked(_trader, "buy", _price, nonce));
        console.logBytes32(_orderId);
        uint256 orderCount = 0;
        do {
            if (currentNode == 0 || orderCount >= 150) {
                //NO
                saveBuyOrder(pair, _price, _quantity, _trader, nonce, _expired, _orderId);
                return;
            } else {
                //SI
                //Precio de compra >= precio del nodo obtenido
                if (_price >= currentNode) {
                    //SI
                    //Aplico el match de ordenes de compra
                    (_quantity, orderCount) =
                    matchOrderBuy(pair, _price, _quantity, _trader, _orderId, orderCount);
                    currentNode = pair.sellOrders.getNextPrice();
                } else {
                    //NO
                    saveBuyOrder(pair, _price, _quantity, _trader, nonce, _expired, _orderId);
                    return;
                }
            }
        } while (_quantity > 0);
    }

    //Agregar orden de venta
    function addSellOrder(
        Pair storage pair,
        uint256 _price,
        uint256 _quantity,
        address _trader,
        uint256 nonce,
        uint256 _expired
    ) internal {
        //¿Arbol de compras tiene nodos?
        uint256 currentNode = pair.buyOrders.getNextPrice();
        bytes32 _orderId = keccak256(abi.encodePacked(_trader, "sell", _price, nonce));
        uint256 orderCount = 0;

        do {
            if (currentNode == 0 || orderCount >= 150) {
                //NO
                saveSellOrder(pair, _price, _quantity, _trader, nonce, _expired, _orderId);
                return;
            } else {
                //SI
                //Precio de venta <= precio del nodo obtenido
                if (_price <= currentNode) {
                    //SI
                    //Aplico el match de ordenes de compra
                    (_quantity, orderCount) = matchOrderSell(pair, _price, _quantity, _trader, _orderId, orderCount);
                    currentNode = pair.buyOrders.getNextPrice();
                } else {
                    //NO
                    saveSellOrder(pair, _price, _quantity, _trader, nonce, _expired, _orderId);
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

//    function getOrderById(Pair storage pair, address _trader, bytes32 _orderId)
//    public
//    returns (Order memory)
//    {
//        TraderOrder memory _order = pair.traderOrders[_trader].orders[_orderId];
//        if (_order.isBuy) {
//            return pair.buyOrders.getOrderDetail(_orderId);
//        } else {
//            return pair.sellOrders.getOrderDetail(_orderId);
//        }
//    }


    function getOrderDetail(Pair storage pair, bytes32 orderId) public view returns (Order memory) {
        if (keyExists(pair, orderId)) revert PairLib__KeyDoesNotExist();
        return pair.orders[orderId];
    }

    function keyExists(Pair storage pair, bytes32 key) internal view returns (bool _exists) {
        return pair.orders[key].orderId == 0;
    }


}
