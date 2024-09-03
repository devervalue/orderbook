// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title Contrato Principal para la Gestión de Libros de Órdenes
 * @author Diego Leal
 * @notice This contract is for creating a sample rafle
 * @dev Este contrato administra la información de los libros de ordenes.
 */
contract FactoryOrderBook {
    /* Errors */
    error MainOrderBook__InvalidTokenAddress();
    error MainOrderBook__InvalidOwnerAddress();
    error MainOrderBook__InvalidFeeAddress();
    error MainOrderBook__OrderBookIdOutOfRange();
    error MainOrderBook__ContractDisabled();
    error MainOrderBook__InvalidOwnerAddressZero();
    error MainOrderBook__BookNotActive();
    error MainOrderBook__InvalidFeeAmount();

    /**
     *  @notice Dirección del propietario autorizado del contrato.
     */
    address private owner;

    /**
     *  @notice Indica si el contrato está habilitado.
     */
    bool public isEnabled;

    /**
     *  @notice Estructura que define un libro de órdenes.
     */
    struct OrderBook {
        address baseToken;
        address quoteToken;
        int256 lastTradePrice;
        bool status;
        address owner;
        uint256 fee;
        address feeAddress;
    }

    /**
     *  @notice Mapeo que asocia un identificador único con un libro de órdenes.
     */
    mapping(uint256 => OrderBook) public orderBooks;

    /**
     *  @notice Contador para generar identificadores únicos para cada libro de órdenes.
     */
    uint256 public orderBookCount;

    /**
     *  @notice Evento que se emite cuando se crea un nuevo libro de órdenes.
     */
    event OrderBookCreated(uint256 indexed id, address indexed baseToken, address indexed quoteToken, address owner);

    /**
     *  @notice Evento que se emite cuando se elimina un libro de órdenes.
     */
    event OrderBookRemoved(uint256 indexed id);

    /**
     *  @notice Evento que se emite cuando se cambia el estado del contrato.
     */
    event ContractEnabled(bool enabled);

    /**
     *  @notice Evento que se emite cuando se activa o desactiva un libro de órdenes.
     */
    event OrderBookStatusChanged(uint256 indexed id, bool status);

    /**
     *  @notice Evento que se emite cuando se cambia la tarifa de un libro de órdenes.
     */
    event OrderBookFeeChanged(uint256 indexed id, uint256 fee);

    /**
     *  @notice Evento que se emite cuando se cambia la dirección de la tarifa de un libro de órdenes.
     */
    event OrderBookFeeAddressChanged(uint256 indexed id, address feeAddress);

    /**
     *  @dev Modificador para restringir funciones solo al propietario autorizado.
     */
    modifier onlyOwner() {
        if (msg.sender != owner) revert MainOrderBook__InvalidOwnerAddress();
        _;
    }

    /**
     *  @dev Modificador para restringir funciones cuando el contrato esté habilitado.
     */
    modifier onlyEnabled() {
        if (!isEnabled) revert MainOrderBook__ContractDisabled();
        _;
    }

    /**
     *  @notice Constructor que establece al remitente como el propietario inicial del contrato y habilita el contrato.
     */
    constructor() {
        owner = msg.sender;
        isEnabled = true;
    }

    /**
     *  @notice Agrega un nuevo libro de órdenes al mapping.
     *  @param baseToken La dirección del token base en el par de trading.
     *  @param quoteToken La dirección del token de cotización en el par de trading.
     *  @param fee El porcentaje de la tarifa aplicada a las operaciones en el libro de órdenes.
     *  @param feeAddress La dirección a la que se envían las tarifas recolectadas.
     */
    function addOrderBook(address baseToken, address quoteToken, uint256 fee, address feeAddress)
        external
        onlyOwner
        onlyEnabled
    {
        if (baseToken == address(0) || quoteToken == address(0)) revert MainOrderBook__InvalidTokenAddress();
        if (owner == address(0)) revert MainOrderBook__InvalidOwnerAddress();
        if (feeAddress == address(0)) revert MainOrderBook__InvalidFeeAddress();

        orderBooks[orderBookCount] = OrderBook({
            baseToken: baseToken,
            quoteToken: quoteToken,
            lastTradePrice: 0,
            status: true,
            owner: owner,
            fee: fee,
            feeAddress: feeAddress
        });

        emit OrderBookCreated(orderBookCount, baseToken, quoteToken, owner);

        orderBookCount += 1;
    }

    /**
     *  @notice Elimina un libro de órdenes del mapping.
     *  @param id El identificador del libro de órdenes a eliminar.
     */
    function removeOrderBook(uint256 id) external onlyOwner onlyEnabled {
        if (id >= orderBookCount) revert MainOrderBook__OrderBookIdOutOfRange();
        delete orderBooks[id];

        emit OrderBookRemoved(id);
    }

    /**
     *  @notice Devuelve la lista completa de libros de órdenes.
     *  @return Un array con todos los libros de órdenes.
     */
    function getOrderBooks() external view returns (OrderBook[] memory) {
        OrderBook[] memory books = new OrderBook[](orderBookCount);
        for (uint256 i = 0; i < orderBookCount; i++) {
            books[i] = orderBooks[i];
        }
        return books;
    }

    /**
     *  @notice Cambia la dirección del propietario autorizado.
     *  @param newOwner La nueva dirección del propietario.
     */
    function setOwner(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert MainOrderBook__InvalidOwnerAddressZero();
        owner = newOwner;
    }

    /**
     *  @notice Cambia el estado del contrato a habilitado o deshabilitado.
     *  @param enabled El nuevo estado del contrato.
     */
    function setEnabled(bool enabled) external onlyOwner {
        isEnabled = enabled;
        emit ContractEnabled(enabled);
    }

    /**
     *  @notice Activa o desactiva un libro de órdenes específico.
     *  @param id El identificador del libro de órdenes a modificar.
     *  @param status El nuevo estado del libro (activo o inactivo).
     */
    function setOrderBookStatus(uint256 id, bool status) external onlyOwner onlyEnabled {
        if (id >= orderBookCount) revert MainOrderBook__OrderBookIdOutOfRange();
        orderBooks[id].status = status;

        emit OrderBookStatusChanged(id, status);
    }

    /**
     *  @notice Establece una nueva tarifa para un libro de órdenes específico.
     *  @param id El identificador del libro de órdenes.
     *  @param fee El nuevo porcentaje de la tarifa.
     */
    function setOrderBookFee(uint256 id, uint256 fee) external onlyOwner onlyEnabled {
        if (id >= orderBookCount) revert MainOrderBook__OrderBookIdOutOfRange();
        if (fee > 100) revert MainOrderBook__InvalidFeeAmount(); // Asumiendo un límite del 100% para la tarifa
        orderBooks[id].fee = fee;

        emit OrderBookFeeChanged(id, fee);
    }

    /**
     *  @notice Establece una nueva dirección de tarifa para un libro de órdenes específico.
     *  @param id El identificador del libro de órdenes.
     *  @param feeAddress La nueva dirección a la que se enviarán las tarifas.
     */
    function setOrderBookFeeAddress(uint256 id, address feeAddress) external onlyOwner onlyEnabled {
        if (id >= orderBookCount) revert MainOrderBook__OrderBookIdOutOfRange();
        if (feeAddress == address(0)) revert MainOrderBook__InvalidFeeAddress();
        orderBooks[id].feeAddress = feeAddress;

        emit OrderBookFeeAddressChanged(id, feeAddress);
    }

    /**
     *  @notice Devuelve la dirección del propietario autorizado.
     *  @return La dirección del propietario actual.
     */
    function getOwner() external view returns (address) {
        return owner;
    }
}
