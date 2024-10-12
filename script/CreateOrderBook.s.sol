// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/OrderBookFactory.sol"; // Cambia el path según la ubicación de tu contrato
import "../src/interface/IOrderBookFactory.sol"; // Asegúrate de que la ruta sea correcta

contract CreateOrderBooks is Script {
    IOrderBookFactory orderBookFactory;
    OrderBookFactory factory;

    // Definir un array de structs en memoria
    OrderBook[] public orderBooks;

    // Dirección del contrato OrderBookFactory ya desplegado
    address factoryAddress = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;

    struct OrderBook {
        address tokenA;
        address tokenB;
        uint256 fee;
        address feeAddress;
    }

    function setUp() public {
        orderBookFactory = IOrderBookFactory(factoryAddress);
    }

    function run() public {
        // Crear una nueva instancia de OrderBook y agregarla al array
        OrderBook memory newOrderBook = OrderBook({
            tokenA: 0x8464135c8F25Da09e49BC8782676a84730C318bC,
            tokenB: 0x663F3ad617193148711d28f5334eE4Ed07016602,
            fee: 125,
            feeAddress: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        });

        // Agregar el nuevo OrderBook al array
        orderBooks.push(newOrderBook);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        for (uint i = 0; i < orderBooks.length; i++) {
            orderBookFactory.addOrderBook(
                orderBooks[i].tokenA,
                orderBooks[i].tokenB,
                orderBooks[i].fee,
                orderBooks[i].feeAddress
            );
        }

        vm.stopBroadcast();
    }
}
