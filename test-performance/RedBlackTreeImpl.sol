// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../src/RedBlackTree.sol";

contract RedBlackTreeImpl {
    using RedBlackTree for RedBlackTree.Tree;

    RedBlackTree.Tree private tree;

    constructor() {}

    //  Get the tree root
    function root() public view returns (uint256 _root) {
        _root = tree.root;
    }

    //  Get the smallest value of the tree
    function first() public view returns (uint256 _value) {
        _value = tree.first();
    }

    //  Get the largest value of the tree
    function last() public view returns (uint256 _value) {
        _value = tree.last();
    }

    // Get the successor of a node
    function next(uint256 _value) public view returns (uint256 _cursor) {
        _cursor = tree.next(_value);
    }

    // Get the predecessor of a node
    function prev(uint256 _value) public view returns (uint256 _cursor) {
        _cursor = tree.prev(_value);
    }

    // Check if a node exists
    function exists(uint256 _value) public view returns (bool _exists) {
        _exists = tree.exists(_value);
    }

    // Checks if a specific key exists in a node identified by its value.
    function keyExists(bytes32 _key, uint256 _value) public view returns (bool _exists) {
        _exists = tree.keyExists(_key, _value);
    }

    // Insert a new node
    function insert(
        bytes32 _key,
        uint256 _value,
        address _traderAddress,
        uint256 _quantity,
        uint256 _nonce,
        uint256 _expired
    ) public {
        tree.insert(_key, _value, _traderAddress, _quantity, _nonce, _expired);
    }

    //  Remove a Node
    function remove(bytes32 _key, uint256 _value) public {
        tree.remove(_key, _value);
    }

    // Pop an order
    function popOrder(uint256 _value) public {
        tree.popOrder(_value);
    }
}
