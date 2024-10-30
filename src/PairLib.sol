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
    using OrderBookLib for OrderBookLib.PricePoint;

    error PairLib__TraderDoesNotCorrespond();
    error PairLib__KeyDoesNotExist();
    error PairLib__KeyAlreadyExists();

    uint256 constant MAX_FEE = 200; // 2% max fee (in basis points)

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

    function changePairFee(Pair storage pair, uint256 newFee) internal {
        require(newFee <= MAX_FEE, "Fee exceeds maximum allowed");
        pair.fee = newFee;
    }

    function saveOrder(Pair storage pair, OrderBookLib.Order memory newOrder) private {
        if (keyExists(pair, newOrder.id)) revert PairLib__KeyAlreadyExists();

        pair.traderOrders[msg.sender].orderIds.push(newOrder.id);
        pair.traderOrders[msg.sender].index[newOrder.id] = pair.traderOrders[msg.sender].orderIds.length - 1;

        //Agregar al arbol
        if (newOrder.isBuy) {
            //Transfiero los tokens al contrato
            IERC20 token = IERC20(pair.quoteToken);
            token.safeTransferFrom(msg.sender, address(this), newOrder.quantity * newOrder.price / (10 ** 18)); //Transfiero la cantidad indicada

            //Agregar al arbol
            pair.buyOrders.insert(newOrder.id, newOrder.price, newOrder.quantity);
        } else {
            //Transfiero los tokens al contrato
            IERC20 token = IERC20(pair.baseToken);
            token.safeTransferFrom(msg.sender, address(this), newOrder.quantity); //Transfiero la cantidad indicada

            //Agregar al arbol
            pair.sellOrders.insert(newOrder.id, newOrder.price, newOrder.quantity);
        }

        OrderBookLib.Order storage _newOrder = pair.orders[newOrder.id];
        _newOrder.id = newOrder.id;
        _newOrder.traderAddress = msg.sender;
        _newOrder.isBuy = newOrder.isBuy;
        _newOrder.price = newOrder.price;
        _newOrder.quantity = newOrder.quantity;
        _newOrder.availableQuantity = newOrder.quantity;
        _newOrder.status = 1;
        _newOrder.createdAt = newOrder.createdAt;
        //Emite el evento de orden creada
        emit OrderCreated(_newOrder.id, pair.baseToken, pair.quoteToken, msg.sender);
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
        // Calculate fee (on the buy token amount, which is what the taker receives)
        uint256 fee = (buyTokenAmount * pair.fee) / 10000; // fee is in basis points
        uint256 buyTokenAmountAfterFee = buyTokenAmount - fee;
        // Transfer sell tokens from taker to maker (full amount)
        sellToken.safeTransferFrom(msg.sender, matchedOrder.traderAddress, sellTokenAmount);
        // Transfer buy tokens from maker to taker (minus fee)
        buyToken.safeTransfer(msg.sender, buyTokenAmountAfterFee);

        // Transfer fee to fee address if set, otherwise it stays in the contract
        if (pair.feeAddress != address(0)) {
            buyToken.safeTransfer(pair.feeAddress, fee);
        }

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
        // Calculate fee (on the buy token amount, which is what the taker receives)
        uint256 fee = (buyTokenAmount * pair.fee) / 10000; // fee is in basis points
        uint256 buyTokenAmountAfterFee = buyTokenAmount - fee;
        // Transfer sell tokens from taker to maker (full amount)
        sellToken.safeTransferFrom(msg.sender, matchedOrder.traderAddress, sellTokenAmount);

        // Transfer buy tokens from maker to taker (minus fee)
        buyToken.safeTransfer(msg.sender, buyTokenAmountAfterFee);

        // Transfer fee to fee address if set, otherwise it stays in the contract
        if (pair.feeAddress != address(0)) {
            buyToken.safeTransfer(pair.feeAddress, fee);
        }
    }

    //Match orden de compra
    function matchOrder(
        Pair storage pair,
        uint256 orderCount,
        IERC20 buyToken,
        IERC20 sellToken,
        OrderBookLib.Order memory newOrder
    ) private returns (uint256 _remainingQuantity, uint256 _orderCount) {
        uint256 matchingPrice = 0;
        bytes32 matchingOrderId = bytes32(uint256(0));

        if (newOrder.isBuy) {
            matchingPrice = pair.sellOrders.getLowestPrice();
            matchingOrderId = pair.sellOrders.getNextOrderIdAtPrice(matchingPrice);
        } else {
            matchingPrice = pair.buyOrders.getHighestPrice();
            matchingOrderId = pair.buyOrders.getNextOrderIdAtPrice(matchingPrice);
        }

        do {
            OrderBookLib.Order storage matchingOrder = getOrderDetail(pair, matchingOrderId);

            uint256 matchingOrderQty = matchingOrder.availableQuantity;

            if (newOrder.quantity >= matchingOrderQty) {
                uint256 buyTokenAmount =
                    newOrder.isBuy ? matchingOrderQty : matchingOrderQty * matchingOrder.price / (10 ** 18);
                uint256 sellTokenAmount =
                    newOrder.isBuy ? matchingOrderQty * matchingOrder.price / (10 ** 18) : matchingOrderQty;
                fillOrder(pair, matchingOrder, buyToken, sellToken, buyTokenAmount, sellTokenAmount);
                //Actualizo la orden de compra disminuyendo la cantidad que ya tengo
                newOrder.quantity -= matchingOrderQty;
                //La cola tiene mas ordenes ?
                matchingOrderId = pair.sellOrders.getNextOrderIdAtPrice(matchingPrice);
                removeFromTraderOrders(pair, matchingOrder.id, matchingOrder.traderAddress);

                // Emito ejecucion de orden completada
                emit OrderExecuted(matchingOrder.id, pair.baseToken, pair.quoteToken, matchingOrder.traderAddress);
            } else {
                uint256 buyTokenAmount =
                    newOrder.isBuy ? newOrder.quantity : newOrder.quantity * matchingOrder.price / (10 ** 18);
                uint256 sellTokenAmount =
                    newOrder.isBuy ? newOrder.quantity * matchingOrder.price / (10 ** 18) : newOrder.quantity;

                partialFillOrder(pair, matchingOrder, buyToken, sellToken, buyTokenAmount, sellTokenAmount);

                //Actualizar la OC restando la cantidad de la OE
                matchingOrder.availableQuantity = matchingOrderQty - newOrder.quantity;
                matchingOrder.status = 2; // Partial Fille TODO Pasar a constante

                if (matchingOrder.isBuy) {
                    pair.buyOrders.update(matchingOrder.price, newOrder.quantity);
                } else {
                    pair.sellOrders.update(matchingOrder.price, newOrder.quantity);
                }

                newOrder.quantity = 0;

                //Emite el evento de orden entrante ejecutada
                emit OrderExecuted(newOrder.id, pair.baseToken, pair.quoteToken, msg.sender);

                //Emite el evento de orden de venta ejecutada parcialmente
                emit OrderPartialExecuted(
                    matchingOrder.id, pair.baseToken, pair.quoteToken, matchingOrder.traderAddress
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
            id: _orderId,
            price: _price,
            quantity: _quantity,
            availableQuantity: _quantity,
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
            id: _orderId,
            price: _price,
            quantity: _quantity,
            availableQuantity: _quantity,
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
            IERC20 token = IERC20(pair.quoteToken);
            token.safeTransfer(
                removedOrder.traderAddress, removedOrder.availableQuantity * removedOrder.price / (10 ** 18)
            );
        } else {
            pair.sellOrders.remove(removedOrder);
            //Transfiero los del contrato al dueño original
            IERC20 token = IERC20(pair.baseToken);
            token.safeTransfer(removedOrder.traderAddress, removedOrder.availableQuantity); //Transfiero la cantidad indicada
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

        if (deleteIndex != lastIndex) {
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
        return pair.orders[key].id != bytes32(0);
    }

    function getLowestBuyPrice(Pair storage pair) internal view returns (uint256) {
        return pair.buyOrders.getLowestPrice();
    }

    function getLowestSellPrice(Pair storage pair) internal view returns (uint256) {
        return pair.sellOrders.getLowestPrice();
    }

    function getHighestBuyPrice(Pair storage pair) internal view returns (uint256) {
        return pair.buyOrders.getHighestPrice();
    }

    function getHighestSellPrice(Pair storage pair) internal view returns (uint256) {
        return pair.sellOrders.getHighestPrice();
    }

    function getNextBuyOrderId(Pair storage pair, uint256 price) internal view returns (bytes32) {
        return pair.buyOrders.getNextOrderIdAtPrice(price);
    }

    function getNextSellOrderId(Pair storage pair, uint256 price) internal view returns (bytes32) {
        return pair.sellOrders.getNextOrderIdAtPrice(price);
    }

    function getTop3BuyPrices(Pair storage pair) internal view returns (uint256[3] memory) {
        return pair.buyOrders.get3HighestPrices();
    }

    function getTop3SellPrices(Pair storage pair) internal view returns (uint256[3] memory) {
        return pair.sellOrders.get3HighestPrices();
    }

    function getPrice(Pair storage p, uint256 price, bool isBuy)
        internal
        view
        returns (OrderBookLib.PricePoint storage)
    {
        if (isBuy) {
            return p.buyOrders.getPricePointData(price);
        } else {
            return p.sellOrders.getPricePointData(price);
        }
    }
}
