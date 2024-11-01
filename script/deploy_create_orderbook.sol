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
    address factoryAddress = 0xE682Fff7B829A85fc25F8A4CE064dD3A5df4cAc4;

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
            tokenA: 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f, // WBTC
            tokenB: 0x45D9831d8751B2325f3DBf48db748723726e1C8c, // EVA
            fee: 0,
            feeAddress: 0x83B6B0F85ba9E5aE56b7A5d73C0fDD12F857087a
        });

        // Agregar el nuevo OrderBook al array
        orderBooks.push(newOrderBook);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        for (uint256 i = 0; i < orderBooks.length; i++) {
            orderBookFactory.addPair(
                orderBooks[i].tokenA, orderBooks[i].tokenB, orderBooks[i].fee, orderBooks[i].feeAddress
            );
        }

        vm.stopBroadcast();
    }
}
