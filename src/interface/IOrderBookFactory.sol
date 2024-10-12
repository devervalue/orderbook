// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IOrderBookFactory {
    function addOrderBook(address _tokenA, address _tokenB, uint256 fee, address feeAddress) external;
}