// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./OrderBookLib.sol";
import "./RedBlackTreeLib.sol";
import {PairLib} from "./PairLib.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Contrato Principal para la Gestión de Libros de Órdenes
 * @author Diego Leal
 * @notice This contract is for creating a sample rafle
 * @dev Este contrato administra la información de los libros de ordenes.
 */
contract OrderBookFactory is ReentrancyGuard, Pausable, Ownable {
    using PairLib for PairLib.Pair;
    using OrderBookLib for OrderBookLib.Order;
    using OrderBookLib for OrderBookLib.PricePoint;

    error OBF__InvalidTokenAddress();
    error OBF__InvalidFeeAddress();
    error OBF__TokensMustBeDifferent();
    error OBF__PairDoesNotExist();
    error OBF__InvalidQuantityValueZero();
    error OBF__PairNotEnabled();
    error OBF__PairAlreadyExists();
    /// @notice Thrown when the fee exceeds the maximum allowed
    /// @param fee The proposed fee
    /// @param maxFee The maximum allowed fee
    error OBF__FeeExceedsMaximum(uint256 fee, uint256 maxFee);

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
     *  @dev Modificador para restringir las ordenes si el libro no esta habilitado.
     */
    modifier onlyEnabledPair(bytes32 _pairId) {
        if (!pairs[_pairId].enabled) revert OBF__PairNotEnabled();
        _;
    }

    constructor() Ownable(msg.sender) {}

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
        if (feeAddress == address(0)) revert OBF__InvalidFeeAddress();
        if (_tokenA == _tokenB) revert OBF__TokensMustBeDifferent();
        if (initialFee > MAX_FEE) revert OBF__FeeExceedsMaximum(initialFee, MAX_FEE);

        /* This ensures that token addresses are order correctly, this way if
         * the same pair is entered but in different order, a new orderbook will
         * NOT be created!
         */
        (address baseToken, address quoteToken) =
            uint160(_tokenA) > uint160(_tokenB) ? (_tokenA, _tokenB) : (_tokenB, _tokenA);

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

        emit OrderBookCreated(identifier, baseToken, quoteToken, msg.sender);
    }

    //Existe el libro
    function pairExists(bytes32 _pairId) private view returns (bool) {
        return pairs[_pairId].baseToken != address(0x0);
    }

    function getPairIds() external view returns (bytes32[] memory) {
        return pairIds;
    }

    function getPairById(bytes32 _pairId)
        external
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

    function addNewOrder(bytes32 _pairId, uint256 _quantity, uint256 _price, bool _isBuy, uint256 _timestamp)
        external
        onlyEnabledPair(_pairId)
        nonReentrant
        whenNotPaused
    {
        if (!pairExists(_pairId)) revert OBF__PairDoesNotExist();
        if (_quantity == 0) revert OBF__InvalidQuantityValueZero();

        if (_isBuy) {
            pairs[_pairId].addBuyOrder(_price, _quantity, _timestamp);
        } else {
            pairs[_pairId].addSellOrder(_price, _quantity, _timestamp);
        }
    }

    function cancelOrder(bytes32 _pairId, bytes32 _orderId) external nonReentrant {
        if (!pairExists(_pairId)) revert OBF__PairDoesNotExist();
        pairs[_pairId].cancelOrder(_orderId);
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

    function getPairFee(bytes32 _pairId) external view returns (uint256) {
        if (!pairExists(_pairId)) revert OBF__PairDoesNotExist();
        return pairs[_pairId].fee;
    }

    function getTraderOrdersForPair(bytes32 _pairId, address _trader) external view returns (bytes32[] memory) {
        if (!pairExists(_pairId)) revert OBF__PairDoesNotExist();

        return pairs[_pairId].getTraderOrders(_trader);
    }

    function getOrderDetailForPair(bytes32 _pairId, bytes32 _orderId)
        external
        view
        returns (OrderBookLib.Order memory)
    {
        if (!pairExists(_pairId)) revert OBF__PairDoesNotExist();

        return pairs[_pairId].getOrderDetail(_orderId);
    }

    function getTop3BuyPricesForPair(bytes32 pairId) external view returns (uint256[3] memory) {
        return pairs[pairId].getTop3BuyPrices();
    }

    function getTop3SellPricesForPair(bytes32 pairId) external view returns (uint256[3] memory) {
        return pairs[pairId].getTop3SellPrices();
    }

    function getPricePointDataForPair(bytes32 _pairId, uint256 price, bool isBuy)
        external view returns (uint256, uint256)
    {
        OrderBookLib.PricePoint storage p = pairs[_pairId].getPrice(price, isBuy);
        return (p.orderCount, p.orderValue);
    }
}
