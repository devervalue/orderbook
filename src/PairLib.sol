// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";
import "./OrderBookLib.sol";

library PairLib {
    using SafeERC20 for IERC20;
    using OrderBookLib for OrderBookLib.Order;
    using OrderBookLib for OrderBookLib.Book;
    using OrderBookLib for OrderBookLib.PricePoint;

    error PL__OrderDoesNotBelongToCurrentTrader();
    error PL__OrderIdDoesNotExist();
    error PL__OrderIdAlreadyExists();
    error PL__FeeExceedsMaximum(uint256 fee, uint256 maxFee);
    error PL__InvalidPrice(uint256 price);
    error PL__InvalidQuantity(uint256 quantity);
    error PL__PairDisabled();

    uint256 private constant PRECISION = 1e18;
    uint256 private constant MAX_FEE = 200; // 2% max fee (in basis points)
    uint256 private constant MAX_NUMBER_ORDERS_FILLED = 1500; // A new order can take this orders at max
    /// @dev Constants for order status
    uint256 private constant ORDER_CREATED = 1;
    uint256 private constant ORDER_PARTIALLY_FILLED = 2;

    struct TraderOrderRegistry {
        bytes32[] orderIds;
        mapping(bytes32 => uint256) index;
    }

    struct Pair {
        uint256 lastTradePrice;
        uint256 fee;
        address baseToken;
        address quoteToken;
        address feeAddress;
        bool enabled;
        OrderBookLib.Book buyOrders;
        OrderBookLib.Book sellOrders;
        mapping(address => TraderOrderRegistry) traderOrderRegistry;
        mapping(bytes32 => OrderBookLib.Order) orders;
    }

    /**
     *  @notice Evento que se emite cuando se crea una nueva orden.
     */
    event OrderCreated(bytes32 indexed id, address indexed baseToken, address indexed quoteToken, address trader);

    /**
     *  @notice Evento que se emite cuando se cancela una orden
     */
    event OrderCanceled(bytes32 indexed id, address indexed baseToken, address indexed quoteToken, address trader);

    /**
     *  @notice Evento que se emite cuando se ejecutar una orden complete.
     */
    event OrderFilled(bytes32 indexed id, address indexed baseToken, address indexed quoteToken, address trader);

    /**
     *  @notice Evento que se emite cuando se ejecuta una orden parcial.
     */
    event OrderPartiallyFilled(
        bytes32 indexed id, address indexed baseToken, address indexed quoteToken, address trader
    );

    event PairFeeChanged(address indexed baseToken, address indexed quoteToken, uint256 newFee);

    function changePairFee(Pair storage pair, uint256 newFee) internal {
        if (newFee > MAX_FEE) revert PL__FeeExceedsMaximum(newFee, MAX_FEE);
        pair.fee = newFee;
        emit PairFeeChanged(pair.baseToken, pair.quoteToken, newFee);
    }

    function addBuyOrder(Pair storage pair, uint256 _price, uint256 _quantity, uint256 timestamp) internal {
        if (!pair.enabled) revert PL__PairDisabled();
        createOrder(pair, true, _price, _quantity, timestamp);
    }

    function addSellOrder(Pair storage pair, uint256 _price, uint256 _quantity, uint256 timestamp) internal {
        if (!pair.enabled) revert PL__PairDisabled();
        createOrder(pair, false, _price, _quantity, timestamp);
    }

    function cancelOrder(Pair storage pair, bytes32 _orderId) internal {
        if (!orderExists(pair, _orderId)) revert PL__OrderIdDoesNotExist();
        if (pair.orders[_orderId].traderAddress != msg.sender) revert PL__OrderDoesNotBelongToCurrentTrader();
        OrderBookLib.Order memory removedOrder = pair.orders[_orderId];

        (IERC20 token, uint256 remainingFunds) = removedOrder.isBuy
            ? (IERC20(pair.quoteToken), removedOrder.availableQuantity * removedOrder.price / PRECISION)
            : (IERC20(pair.baseToken), removedOrder.availableQuantity);

        token.safeTransfer(removedOrder.traderAddress, remainingFunds); //Transfiero la cantidad indicada

        removeOrder(pair, removedOrder);

        emit OrderCanceled(_orderId, pair.baseToken, pair.quoteToken, msg.sender);
    }

    function removeFromTraderOrders(Pair storage pair, bytes32 _orderId, address traderAddress) private {
        // Reemplazar el elemento a eliminar con el último elemento del array
        TraderOrderRegistry storage to = pair.traderOrderRegistry[traderAddress];

        uint256 deleteIndex = to.index[_orderId];
        uint256 lastIndex = to.orderIds.length - 1;

        if (deleteIndex != lastIndex) {
            to.orderIds[deleteIndex] = to.orderIds[lastIndex];
        }

        // actualizar el index de la orden movida
        to.index[to.orderIds[lastIndex]] = deleteIndex;

        // Remover el último elemento
        to.orderIds.pop();
        delete to.index[_orderId];
    }

    function addOrder(Pair storage pair, OrderBookLib.Order memory newOrder) private {
        if (orderExists(pair, newOrder.id)) revert PL__OrderIdAlreadyExists();

        TraderOrderRegistry storage registry = pair.traderOrderRegistry[msg.sender];
        registry.orderIds.push(newOrder.id);
        registry.index[newOrder.id] = registry.orderIds.length - 1;

        // Collect funds
        (IERC20 token, uint256 transferAmount, OrderBookLib.Book storage book) = newOrder.isBuy
            ? (IERC20(pair.quoteToken), newOrder.quantity * newOrder.price / PRECISION, pair.buyOrders)
            : (IERC20(pair.baseToken), newOrder.quantity, pair.sellOrders);

        token.safeTransferFrom(msg.sender, address(this), transferAmount);
        book.insert(newOrder.id, newOrder.price, newOrder.quantity);

        pair.orders[newOrder.id] = newOrder;

        //Emite el evento de orden creada
        emit OrderCreated(newOrder.id, pair.baseToken, pair.quoteToken, msg.sender);
    }

    function removeOrder(Pair storage pair, OrderBookLib.Order memory order) private {
        //Elimino la orden del book
        (order.isBuy ? pair.buyOrders : pair.sellOrders).remove(order);
        // Elimino del registro de ordenes del trader
        removeFromTraderOrders(pair, order.id, order.traderAddress);
        // Elimino el detalle
        delete pair.orders[order.id];
    }

    function fillOrder(Pair storage pair, OrderBookLib.Order storage matchedOrder, OrderBookLib.Order memory takerOrder)
        private
    {
        // actualizo el precio del par
        pair.lastTradePrice = matchedOrder.price;

        (IERC20 takerReceiveToken, uint256 takerReceiveAmount, IERC20 takerSendToken, uint256 takerSendAmount) =
        takerOrder.isBuy
            ? (
                IERC20(pair.baseToken),
                matchedOrder.availableQuantity,
                IERC20(pair.quoteToken),
                matchedOrder.availableQuantity * matchedOrder.price / PRECISION
            )
            : (
                IERC20(pair.quoteToken),
                matchedOrder.availableQuantity * matchedOrder.price / PRECISION,
                IERC20(pair.baseToken),
                matchedOrder.availableQuantity
            );

        // Calculate fee (on the buy token amount, which is what the taker receives)
        uint256 fee = (takerReceiveAmount * pair.fee) / 10000; // fee is in basis points
        uint256 takerReceiveAmountAfterFee = takerReceiveAmount - fee;

        // Transfer sell tokens from taker to maker (full amount)
        takerSendToken.safeTransferFrom(msg.sender, matchedOrder.traderAddress, takerSendAmount);
        // Transfer buy tokens from maker to taker (minus fee)
        takerReceiveToken.safeTransfer(msg.sender, takerReceiveAmountAfterFee);

        // Transfer fee to fee address if set, otherwise it stays in the contract
        if (pair.feeAddress != address(0)) {
            takerReceiveToken.safeTransfer(pair.feeAddress, fee);
        }

        //Actualizo la orden de compra disminuyendo la cantidad que ya tengo
        takerOrder.quantity -= matchedOrder.availableQuantity;

        // Emito ejecucion de orden completada para ambas ordenes
        emit OrderFilled(matchedOrder.id, pair.baseToken, pair.quoteToken, matchedOrder.traderAddress);
        emit OrderFilled(takerOrder.id, pair.baseToken, pair.quoteToken, takerOrder.traderAddress);

        // Elimino la orden matcheada del par
        removeOrder(pair, matchedOrder);
    }

    function partiallyFillOrder(
        Pair storage pair,
        OrderBookLib.Order storage matchedOrder,
        OrderBookLib.Order memory takerOrder
    ) private {
        //NO
        //Transfiero la cantidad de tokens de OE al comprador
        pair.lastTradePrice = matchedOrder.price;

        (IERC20 takerReceiveToken, uint256 takerReceiveAmount, IERC20 takerSendToken, uint256 takerSendAmount) =
        takerOrder.isBuy
            ? (
                IERC20(pair.baseToken),
                takerOrder.quantity,
                IERC20(pair.quoteToken),
                takerOrder.quantity * matchedOrder.price / PRECISION
            )
            : (
                IERC20(pair.quoteToken),
                takerOrder.quantity * matchedOrder.price / PRECISION,
                IERC20(pair.baseToken),
                takerOrder.quantity
            );

        // Calculate fee (on the buy token amount, which is what the taker receives)
        uint256 fee = (takerReceiveAmount * pair.fee) / 10000; // fee is in basis points
        uint256 takerReceiveAmountAfterFee = takerReceiveAmount - fee;
        // Transfer sell tokens from taker to maker (full amount)
        takerSendToken.safeTransferFrom(msg.sender, matchedOrder.traderAddress, takerSendAmount);

        // Transfer buy tokens from maker to taker (minus fee)
        takerReceiveToken.safeTransfer(msg.sender, takerReceiveAmountAfterFee);

        // Transfer fee to fee address if set, otherwise it stays in the contract
        if (pair.feeAddress != address(0)) {
            takerReceiveToken.safeTransfer(pair.feeAddress, fee);
        }

        //Actualizar la OC restando la cantidad de la OE
        matchedOrder.availableQuantity = matchedOrder.availableQuantity - takerOrder.quantity;
        matchedOrder.status = ORDER_PARTIALLY_FILLED;

        (matchedOrder.isBuy ? pair.buyOrders : pair.sellOrders).update(matchedOrder.price, takerOrder.quantity);

        takerOrder.quantity = 0;

        //Emite el evento de orden entrante ejecutada
        emit OrderFilled(takerOrder.id, pair.baseToken, pair.quoteToken, msg.sender);

        //Emite el evento de orden de venta ejecutada parcialmente
        emit OrderPartiallyFilled(matchedOrder.id, pair.baseToken, pair.quoteToken, matchedOrder.traderAddress);
    }

    //Match orden de compra
    function matchOrder(Pair storage pair, uint256 orderCount, OrderBookLib.Order memory newOrder)
        private
        returns (uint256, uint256)
    {
        bytes32 matchingOrderId = newOrder.isBuy
            ? pair.sellOrders.getNextOrderIdAtPrice(pair.sellOrders.getLowestPrice())
            : pair.buyOrders.getNextOrderIdAtPrice(pair.buyOrders.getHighestPrice());

        do {
            OrderBookLib.Order storage matchingOrder = pair.orders[matchingOrderId];

            if (newOrder.quantity >= matchingOrder.availableQuantity) {
                fillOrder(pair, matchingOrder, newOrder);
                //La cola tiene mas ordenes al mismo precio ?
                matchingOrderId = pair.sellOrders.getNextOrderIdAtPrice(matchingOrder.price);
            } else {
                partiallyFillOrder(pair, matchingOrder, newOrder);

                return (newOrder.quantity, orderCount);
            }
            ++orderCount;
        } while (matchingOrderId != 0 && orderCount < MAX_NUMBER_ORDERS_FILLED);
        return (newOrder.quantity, orderCount);
    }

    function createOrder(Pair storage pair, bool isBuy, uint256 _price, uint256 _quantity, uint256 timestamp) private {
        if (_price == 0) revert PL__InvalidPrice(_price);
        if (_quantity == 0) revert PL__InvalidQuantity(_quantity);

        uint256 currentPricePoint = isBuy ? pair.sellOrders.getLowestPrice() : pair.buyOrders.getHighestPrice();

        bytes32 _orderId = keccak256(abi.encodePacked(msg.sender, isBuy ? "buy" : "sell", _price, timestamp));

        OrderBookLib.Order memory newOrder = OrderBookLib.Order({
            id: _orderId,
            price: _price,
            quantity: _quantity,
            availableQuantity: _quantity,
            isBuy: isBuy,
            createdAt: timestamp,
            traderAddress: msg.sender,
            status: ORDER_CREATED
        });

        uint256 orderCount;
        while (_quantity > 0 && orderCount < MAX_NUMBER_ORDERS_FILLED) {
            if (currentPricePoint == 0) {
                break;
            }

            bool shouldMatch = isBuy ? newOrder.price >= currentPricePoint : newOrder.price <= currentPricePoint;

            if (shouldMatch) {
                (_quantity, orderCount) = matchOrder(pair, orderCount, newOrder);
                newOrder.quantity = _quantity;
                currentPricePoint = isBuy ? pair.sellOrders.getLowestPrice() : pair.buyOrders.getHighestPrice();
            } else {
                break;
            }
        }

        if (_quantity > 0) {
            addOrder(pair, newOrder);
        }
    }

    function getTraderOrders(Pair storage pair, address _trader) internal view returns (bytes32[] memory) {
        return pair.traderOrderRegistry[_trader].orderIds;
    }

    function getOrderDetail(Pair storage pair, bytes32 orderId) internal view returns (OrderBookLib.Order storage) {
        if (!orderExists(pair, orderId)) revert PL__OrderIdDoesNotExist();
        return pair.orders[orderId];
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
        return pair.buyOrders.get3Prices(true);
    }

    function getTop3SellPrices(Pair storage pair) internal view returns (uint256[3] memory) {
        return pair.sellOrders.get3Prices(false);
    }

    function getPrice(Pair storage pair, uint256 price, bool isBuy)
        internal
        view
        returns (OrderBookLib.PricePoint storage)
    {
        return (isBuy ? pair.buyOrders : pair.sellOrders).getPricePointData(price);
    }

    function orderExists(Pair storage pair, bytes32 _orderId) private view returns (bool) {
        return pair.orders[_orderId].id != bytes32(0);
    }
}
