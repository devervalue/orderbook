// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./RedBlackTree.sol";
import {PairLib} from "./PairLib.sol";

/**
 * @title Contrato Principal para la Gestión de Libros de Órdenes
 * @author Diego Leal
 * @notice This contract is for creating a sample rafle
 * @dev Este contrato administra la información de los libros de ordenes.
 */
contract OrderBookFactory {
    using PairLib for PairLib.Pair;

    error OrderBookFactory__InvalidTokenAddress();
    error OrderBookFactory__InvalidOwnerAddress();
    error OrderBookFactory__InvalidFeeAddress();
    error OrderBookFactory__TokenMustBeDifferent();
    error OrderBookFactory__InvalidOwnerAddressZero();
    error OrderBookFactory__OrderBookIdOutOfRange();
    error OrderBookFactory__InvalidQuantityValueZero();
    error OrderBookFactory__OrderBookNotEnabled();

    /**
     *  @notice Dirección del propietario autorizado del contrato.
     */
    address public owner;

    bytes32[] public orderBooksKeys;

    mapping(bytes32 => PairLib.Pair) ordersBook;

    /**
     *  @notice Evento que se emite cuando se crea un nuevo libro de órdenes.
     */
    event OrderBookCreated(bytes32 indexed id, address indexed baseToken, address indexed quoteToken, address owner);

    /**
     *  @notice Evento que se emite cuando se activa o desactiva un libro de órdenes.
     */
    event OrderBookStatusChanged(bytes32 indexed id, bool status);

    /**
     *  @notice Evento que se emite cuando se cambia la tarifa de un libro de órdenes.
     */
    event OrderBookFeeChanged(bytes32 indexed id, uint256 fee);

    /**
     *  @notice Evento que se emite cuando se cambia la dirección de la tarifa de un libro de órdenes.
     */
    event OrderBookFeeAddressChanged(bytes32 indexed id, address feeAddress);

    /**
     *  @dev Modificador para restringir funciones solo al propietario autorizado.
     */
    modifier onlyOwner() {
        if (msg.sender != owner) revert OrderBookFactory__InvalidOwnerAddress();
        _;
    }

    /**
     *  @dev Modificador para restringir las ordenes si el libro no esta habilitado.
     */
    modifier onlyEnabledBook(bytes32 orderBookId) {
        if (!ordersBook[orderBookId].status) revert OrderBookFactory__OrderBookNotEnabled();
        _;
    }

    constructor() {
        owner = address(this); // Set the contract deployer as the owner
    }

    /**
     *  @notice Agrega un nuevo libro de órdenes al mapping.
     *  @param _tokenA La dirección del token base en el par de trading.
     *  @param _tokenB La dirección del token de cotización en el par de trading.
     *  @param fee El porcentaje de la tarifa aplicada a las operaciones en el libro de órdenes.
     *  @param feeAddress La dirección a la que se envían las tarifas recolectadas.
     */
    function addOrderBook(address _tokenA, address _tokenB, uint256 fee, address feeAddress) external onlyOwner {
        if (_tokenA == address(0) || _tokenB == address(0)) revert OrderBookFactory__InvalidTokenAddress();
        if (owner == address(0)) revert OrderBookFactory__InvalidOwnerAddress();
        if (feeAddress == address(0)) revert OrderBookFactory__InvalidFeeAddress();
        if (_tokenA == _tokenB) revert OrderBookFactory__TokenMustBeDifferent();

        address baseToken;
        address quoteToken;

        /* This ensures that token addresses are order correctly, this way if
         * the same pair is entered but in different order, a new orderbook will
         * NOT be created!
         */
        if (uint160(baseToken) > uint160(quoteToken)) {
            baseToken = _tokenA;
            quoteToken = _tokenB;
        } else {
            baseToken = _tokenB;
            quoteToken = _tokenA;
        }

        // mapping identifier is computed from the hash of the ordered addresses
        bytes32 identifier = keccak256(abi.encodePacked(baseToken, quoteToken));
        //TODO SI EL PARA YA EXISTE COMO LO MANEJAMOS ?
        //Add order keys
        orderBooksKeys.push(identifier);

        //Add data mapping
        PairLib.Pair storage orderBook = ordersBook[identifier];
        orderBook.baseToken = baseToken;
        orderBook.quoteToken = quoteToken;
        orderBook.lastTradePrice = 0;
        orderBook.status = true;
        orderBook.owner = owner;
        orderBook.fee = fee;
        orderBook.feeAddress = feeAddress;

        emit OrderBookCreated(identifier, baseToken, quoteToken, owner);
    }

    //Existe el libro
    function orderBookExists(bytes32 _orderBookId) internal view returns (bool exists) {
        return ordersBook[_orderBookId].baseToken != address(0x0);
    }

    function getKeysOrderBooks() external view returns (bytes32[] memory) {
        return orderBooksKeys;
    }

    function getOrderBookById(bytes32 _orderId)
        public
        view
        returns (address baseToken, address quoteToken, bool status, uint256 lastTradePrice, uint256 fee)
    {
        return (
            ordersBook[_orderId].baseToken,
            ordersBook[_orderId].quoteToken,
            ordersBook[_orderId].status,
            ordersBook[_orderId].lastTradePrice,
            ordersBook[_orderId].fee
        );
    }

    /**
     *  @notice Cambia la dirección del propietario autorizado.
     *  @param newOwner La nueva dirección del propietario.
     */
    function setOwner(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert OrderBookFactory__InvalidOwnerAddressZero();
        owner = newOwner;
    }

    /**
     *  @notice Activa o desactiva un libro de órdenes específico.
     *  @param idOrderBook El identificador del libro de órdenes a modificar.
     *  @param status El nuevo estado del libro (activo o inactivo).
     */
    function setOrderBookStatus(bytes32 idOrderBook, bool status) external onlyOwner {
        if (!orderBookExists(idOrderBook)) revert OrderBookFactory__OrderBookIdOutOfRange();
        ordersBook[idOrderBook].status = status;

        emit OrderBookStatusChanged(idOrderBook, status);
    }

    /**
     *  @notice Establece una nueva tarifa para un libro de órdenes específico.
     *  @param idOrderBook El identificador del libro de órdenes.
     *  @param fee El nuevo porcentaje de la tarifa.
     */
    function setOrderBookFee(bytes32 idOrderBook, uint256 fee) external onlyOwner {
        if (!orderBookExists(idOrderBook)) revert OrderBookFactory__OrderBookIdOutOfRange();
        //if (fee > 100) revert MainOrderBook__InvalidFeeAmount(); // Asumiendo un límite del 100% para la tarifa
        ordersBook[idOrderBook].fee = fee;

        emit OrderBookFeeChanged(idOrderBook, fee);
    }

    /**
     *  @notice Establece una nueva dirección de tarifa para un libro de órdenes específico.
     *  @param idOrderBook El identificador del libro de órdenes.
     *  @param feeAddress La nueva dirección a la que se enviarán las tarifas.
     */
    function setOrderBookFeeAddress(bytes32 idOrderBook, address feeAddress) external onlyOwner {
        if (!orderBookExists(idOrderBook)) revert OrderBookFactory__OrderBookIdOutOfRange();
        if (feeAddress == address(0)) revert OrderBookFactory__InvalidFeeAddress();
        ordersBook[idOrderBook].feeAddress = feeAddress;

        emit OrderBookFeeAddressChanged(idOrderBook, feeAddress);
    }

    /**
     *  @notice Devuelve la dirección del propietario autorizado.
     *  @return La dirección del propietario actual.
     */
    function getOwner() external view returns (address) {
        return owner;
    }

    function addNewOrder(
        bytes32 idOrderBook,
        uint256 quantity,
        uint256 price,
        bool isBuy,
        uint256 nonce,
        uint256 _expired
    ) public onlyEnabledBook(idOrderBook) {
        if (!orderBookExists(idOrderBook)) revert OrderBookFactory__OrderBookIdOutOfRange();
        if (quantity == 0) revert OrderBookFactory__InvalidQuantityValueZero();
        PairLib.Pair storage order = ordersBook[idOrderBook];
        if (isBuy) {
            order.addBuyOrder(price, quantity, nonce, _expired);
        } else {
            order.addSellOrder(price, quantity, nonce, _expired);
        }
    }

    function cancelOrder(bytes32 idOrderBook, bytes32 idOrder) public {
        if (!orderBookExists(idOrderBook)) revert OrderBookFactory__OrderBookIdOutOfRange();
        PairLib.Pair storage order = ordersBook[idOrderBook];
        order.cancelOrder(idOrder);
    }
}
