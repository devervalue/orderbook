// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./OrderBookLib.sol";
import "./RedBlackTreeLib.sol";
import {PairLib} from "./PairLib.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title Contrato Principal para la Gestión de Libros de Órdenes
 * @author Diego Leal
 * @notice This contract is for creating a sample rafle
 * @dev Este contrato administra la información de los libros de ordenes.
 */
contract OrderBookFactory is ReentrancyGuard, Pausable {
    using PairLib for PairLib.Pair;
    using OrderBookLib for OrderBookLib.Order;
    using OrderBookLib for OrderBookLib.PricePoint;

    error OBF__InvalidTokenAddress();
    error OBF__InvalidOwnerAddress();
    error OBF__InvalidFeeAddress();
    error OBF__TokensMustBeDifferent();
    error OBF__InvalidOwnerAddressZero();
    error OBF__PairDoesNotExist();
    error OBF__InvalidQuantityValueZero();
    error OBF__OrderBookNotEnabled();
    error OBF__PairAlreadyExists();
    /// @notice Thrown when the fee exceeds the maximum allowed
    /// @param fee The proposed fee
    /// @param maxFee The maximum allowed fee
    error OBF__FeeExceedsMaximum(uint256 fee, uint256 maxFee);

    /**
     *  @notice Dirección del propietario autorizado del contrato.
     */
    address public owner;

    bytes32[] public pairIds;

    mapping(bytes32 => PairLib.Pair) pairs;

    /// @dev Maximum fee in basis points (2%)
    uint256 private constant MAX_FEE = 200;

    /**
     *  @notice Evento que se emite cuando se crea un nuevo libro de órdenes.
     */
    event OrderBookCreated(bytes32 indexed id, address indexed baseToken, address indexed quoteToken, address owner);

    /**
     *  @notice Evento que se emite cuando se activa o desactiva un libro de órdenes.
     */
    event PairStatusChanged(bytes32 indexed id, bool enabled);

    /**
     *  @notice Evento que se emite cuando se cambia la tarifa de un libro de órdenes.
     */
    event PairFeeChanged(bytes32 indexed id, uint256 newFee);

    /**
     *  @notice Evento que se emite cuando se cambia la dirección de la tarifa de un libro de órdenes.
     */
    event PairFeeAddressChanged(bytes32 indexed id, address newFeeAddress);

    event ContractPauseStatusChanged(bool isPaused);

    /**
     *  @dev Modificador para restringir funciones solo al propietario autorizado.
     */
    modifier onlyOwner() {
        if (msg.sender != owner) revert OBF__InvalidOwnerAddress();
        _;
    }

    /**
     *  @dev Modificador para restringir las ordenes si el libro no esta habilitado.
     */
    modifier onlyEnabledPair(bytes32 _pairId) {
        if (!pairs[_pairId].enabled) revert OBF__OrderBookNotEnabled();
        _;
    }

    constructor() {
        owner = msg.sender; // Set the contract deployer as the owner
    }

    /**
     *  @notice Agrega un nuevo libro de órdenes al mapping.
     *  @param _tokenA La dirección del token base en el par de trading.
     *  @param _tokenB La dirección del token de cotización en el par de trading.
     *  @param initialFee El porcentaje de la tarifa aplicada a las operaciones en el libro de órdenes.
     *  @param feeAddress La dirección a la que se envían las tarifas recolectadas.
     */
    function addPair(address _tokenA, address _tokenB, uint256 initialFee, address feeAddress)
        external
        onlyOwner
        whenNotPaused
    {
        if (_tokenA == address(0) || _tokenB == address(0)) revert OBF__InvalidTokenAddress();
        if (owner == address(0)) revert OBF__InvalidOwnerAddress();
        if (feeAddress == address(0)) revert OBF__InvalidFeeAddress();
        if (_tokenA == _tokenB) revert OBF__TokensMustBeDifferent();
        if (initialFee > MAX_FEE) revert OBF__FeeExceedsMaximum(initialFee, MAX_FEE);

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

        if (pairExists(identifier)) revert OBF__PairAlreadyExists();
        //Add order keys
        pairIds.push(identifier);

        PairLib.Pair storage newPair = pairs[identifier];
        newPair.baseToken = baseToken;
        newPair.quoteToken = quoteToken;
        newPair.lastTradePrice = 0;
        newPair.enabled = true;
        newPair.fee = initialFee;
        newPair.feeAddress = feeAddress;

        emit OrderBookCreated(identifier, baseToken, quoteToken, owner);
    }

    //Existe el libro
    function pairExists(bytes32 _pairId) private view returns (bool) {
        return pairs[_pairId].baseToken != address(0x0);
    }

    function getPairIds() external view returns (bytes32[] memory) {
        return pairIds;
    }

    function getPairById(bytes32 _pairId)
        public
        view
        returns (
            address baseToken,
            address quoteToken,
            bool status,
            uint256 lastTradePrice,
            uint256 fee,
            address feeAddress
        )
    {
        if (!pairExists(_pairId)) revert OBF__PairDoesNotExist();
        return (
            pairs[_pairId].baseToken,
            pairs[_pairId].quoteToken,
            pairs[_pairId].enabled,
            pairs[_pairId].lastTradePrice,
            pairs[_pairId].fee,
            pairs[_pairId].feeAddress
        );
    }

    /**
     *  @notice Cambia la dirección del propietario autorizado.
     *  @param newOwner La nueva dirección del propietario.
     */
    function setOwner(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert OBF__InvalidOwnerAddressZero();
        owner = newOwner;
    }

    function setPairStatus(bytes32 _pairId, bool _enabled) external onlyOwner {
        if (!pairExists(_pairId)) revert OBF__PairDoesNotExist();
        pairs[_pairId].enabled = _enabled;

        emit PairStatusChanged(_pairId, _enabled);
    }

    function setPairFee(bytes32 _pairId, uint256 newFee) external onlyOwner {
        if (!pairExists(_pairId)) revert OBF__PairDoesNotExist();
        if (newFee > MAX_FEE) revert OBF__FeeExceedsMaximum(newFee, MAX_FEE);
        pairs[_pairId].changePairFee(newFee);

        emit PairFeeChanged(_pairId, newFee);
    }

    /**
     *  @notice Establece una nueva dirección de tarifa para un libro de órdenes específico.
     */
    function setPairFeeAddress(bytes32 _pairId, address newFeeAddress) external onlyOwner {
        if (!pairExists(_pairId)) revert OBF__PairDoesNotExist();
        if (newFeeAddress == address(0)) revert OBF__InvalidFeeAddress();
        pairs[_pairId].feeAddress = newFeeAddress;

        emit PairFeeAddressChanged(_pairId, newFeeAddress);
    }

    /**
     *  @notice Devuelve la dirección del propietario autorizado.
     *  @return La dirección del propietario actual.
     */
    function getOwner() external view returns (address) {
        return owner;
    }

    function addNewOrder(bytes32 _pairId, uint256 _quantity, uint256 _price, bool _isBuy, uint256 _timestamp)
        public
        onlyEnabledPair(_pairId)
        nonReentrant
        whenNotPaused
    {
        if (!pairExists(_pairId)) revert OBF__PairDoesNotExist();
        if (_quantity == 0) revert OBF__InvalidQuantityValueZero();

        PairLib.Pair storage pair = pairs[_pairId];
        if (_isBuy) {
            pair.addBuyOrder(_price, _quantity, _timestamp);
        } else {
            pair.addSellOrder(_price, _quantity, _timestamp);
        }
    }

    function cancelOrder(bytes32 _pairId, bytes32 _orderId) public nonReentrant {
        if (!pairExists(_pairId)) revert OBF__PairDoesNotExist();
        PairLib.Pair storage pair = pairs[_pairId];
        pair.cancelOrder(_orderId);
    }

    /**
     * @notice Pauses the contract
     * @dev Only the owner can call this function
     */
    function pause() external onlyOwner {
        _pause();
        emit ContractPauseStatusChanged(true);
    }

    /**
     * @notice Unpauses the contract
     * @dev Only the owner can call this function
     */
    function unpause() external onlyOwner {
        _unpause();
        emit ContractPauseStatusChanged(false);
    }

    function getPairFee(bytes32 _pairId) public view returns (uint256) {
        if (!pairExists(_pairId)) revert OBF__PairDoesNotExist();
        return pairs[_pairId].fee;
    }

    function getTraderOrdersForPair(bytes32 _pairId, address _trader) public view returns (bytes32[] memory) {
        if (!pairExists(_pairId)) revert OBF__PairDoesNotExist();

        PairLib.Pair storage pair = pairs[_pairId];
        return pair.getTraderOrders(_trader);
    }

    function getOrderDetailForPair(bytes32 _pairId, bytes32 _orderId) public view returns (OrderBookLib.Order memory) {
        if (!pairExists(_pairId)) revert OBF__PairDoesNotExist();

        PairLib.Pair storage pair = pairs[_pairId];
        return pair.getOrderDetail(_orderId);
    }

    function getTop3BuyPricesForPair(bytes32 pairId) public view returns (uint256[3] memory) {
        PairLib.Pair storage pair = pairs[pairId];
        return pair.getTop3BuyPrices();
    }

    function getTop3SellPricesForPair(bytes32 pairId) public view returns (uint256[3] memory) {
        PairLib.Pair storage pair = pairs[pairId];
        return pair.getTop3SellPrices();
    }

    function getPricePointDataForPair(bytes32 _pairId, uint256 price, bool isBuy)
        public
        view
        returns (uint256, uint256)
    {
        PairLib.Pair storage pair = pairs[_pairId];
        OrderBookLib.PricePoint storage p = pair.getPrice(price, isBuy);
        return (p.orderCount, p.orderValue);
    }
}
