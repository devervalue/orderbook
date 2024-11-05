// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/QueueLib.sol";
import "../src/RedBlackTreeLib.sol";
import "forge-std/console.sol";
import "./MyTokenA.sol";
import "./MyTokenB.sol";

import "./PairLibImpl.sol";

contract PairLibTest is Test {
    // using OrderBookLib for OrderBookLib.OrderBook;
    // using RedBlackTree for RedBlackTree.Tree;

    //OrderBookLib.OrderBook private book;

    PairLibImpl private pair;

    //TOKENS
    ERC20 tokenA;
    ERC20 tokenB;

    //ADDRESS
    address contractAddress;
    address trader1 = makeAddr("trader1");
    address trader2 = makeAddr("trader2");
    address trader3 = makeAddr("trader3");

    //GLOBAL DATA
    uint256 price;
    uint256 quantity;
    uint256 nonce;
    uint256 expired;

    function setUp() public {
        //addressContract = deployCode("OrderBookLib.sol");

        //Creando token como suministro inicial
        tokenA = new MyTokenA(1000 * 10 ** 18); //Crear un nuevo token con suministro inicial
        tokenB = new MyTokenB(1000 * 10 ** 18); //Crear un nuevo token con suministro inicial

        pair = new PairLibImpl(address(tokenA), address(tokenB));
        console.log("addressContract", address(pair));
        console.log("address this", address(this));
        //Enviando fondos a los traders
        //token.approve(msg.sender, 1000 * 10 ** 18);
        //tokenA.transfer(trader1,200 * 10 ** 18); //Doy fondos a trader 1
        //tokenA.transfer(trader2,200 * 10 ** 18); //Doy fondos a trader 2
        tokenA.transfer(trader1, 1500);
        //tokenA.transfer(address(this),1); //Doy fondos a trader 2

        //tokenB.transfer(trader1,200 * 10 ** 18); //Doy fondos a trader 1
        tokenB.transfer(trader2, 1500);

        //tokenB.transfer(address(this),1); //Doy fondos a trader 2
        //tokenB.transfer(trader2,200 * 10 ** 18); //Doy fondos a trader 2

        //token.approve(trader1, 1000 * 10 ** 18);

        //Creando orderBook
        price = 100 * 10 ** 18;
        quantity = 10;
        nonce = 1;
        expired = block.timestamp + 1 days;

        //Aprobar el contrato para que pueda gastar tokens
        vm.startPrank(trader1); // Cambiar el contexto a trader1
        tokenA.approve(address(pair), 1000 * 10 ** 18); // Aprobar 1000 tokens
        vm.stopPrank();

        vm.startPrank(trader2); // Cambiar el contexto a trader1
        tokenB.approve(address(pair), 1000 * 10 ** 18); // Aprobar 1000 tokens
        vm.stopPrank();

        //        vm.startPrank(address(orderBookImpl)); // Cambiar el contexto a trader1
        //        tokenB.approve(address(orderBookImpl), 1000 * 10 ** 18); // Aprobar 1000 tokens
        //        tokenA.approve(address(orderBookImpl), 1000 * 10 ** 18); // Aprobar 1000 tokens
        //        vm.stopPrank();
    }

    // Helper function to assert equality of uint256[3] arrays
    function assertEqualArrays(uint256[3] memory actual, uint256[3] memory expected) internal {
        for (uint i = 0; i < 3; i++) {
            assertEq(actual[i], expected[i], string(abi.encodePacked("Failed at index ", i)));
        }
    }

    //-------------------- ADD BUY ORDER ------------------------------
    //Valida que si no hay órdenes de venta, la orden de compra se almacena en el libro.
    function testAddBuyOrderWithoutSellOrders() public {
        // Caso 1: Orden de compra sin órdenes de venta
        uint256 balanceContractInitial = tokenB.balanceOf(address(pair));

        vm.startPrank(trader2);
        pair.addBuyBaseToken(price, quantity, trader1, nonce);
        vm.stopPrank();

        uint256 balanceContract = tokenB.balanceOf(address(pair));
        assertEq(balanceContract - balanceContractInitial, 1000); // Verificar que el balance restante es correcto
        assertEq(pair.getFirstBuyOrders(), 100 * 10 ** 18, "La orden de compra debe estar almacenada");
    }

    //Verifica que una orden de compra se ejecute completamente si encuentra una orden de venta con el mismo precio.
    function testAddBuyOrderWithMatchingSellOrder() public {
        // Caso 2: Orden de compra con precio igual a una orden de venta

        vm.startPrank(trader1);
        pair.addSellBaseToken(price, quantity, trader2, nonce);
        vm.stopPrank();

        vm.prank(trader2);
        pair.addBuyBaseToken(price, quantity, trader1, nonce);

        // Verificar que la orden de compra se haya emparejado y eliminado
        assertEq(pair.getFirstSellOrders(), 0, "La orden de venta debe haberse emparejado completamente");
        assertEq(pair.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
        assertEq(tokenB.balanceOf(trader1), 1000); // Verificar que el balance restante es correcto
        assertEq(tokenA.balanceOf(trader2), 10); // Verificar que el balance restante es correcto
    }

    function testAddBuyOrderWithMatchingDifferentSellOrder() public {
        // Caso 2: Orden de compra con precio igual varias ordenes de compra

        vm.startPrank(trader1);
        pair.addSellBaseToken(price, 5, trader2, nonce);
        vm.stopPrank();

        vm.startPrank(trader1);
        pair.addSellBaseToken(price, 5, trader2, nonce + 1);
        vm.stopPrank();

        vm.startPrank(trader1);
        pair.addSellBaseToken(price, 5, trader2, nonce + 2);
        vm.stopPrank();

        //vm.prank(trader1);
        vm.startPrank(trader2);
        pair.addBuyBaseToken(price, 15, trader1, nonce);
        vm.stopPrank();

        assertEq(pair.getFirstSellOrders(), 0, "La orden de venta debe haberse emparejado completamente");
        assertEq(pair.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
        assertEq(tokenB.balanceOf(trader1), 1500); // Verificar que el balance restante es correcto
        assertEq(tokenA.balanceOf(trader2), 15); // Verificar que el balance restante es correcto
    }

    //Prueba que una orden de compra con un precio mayor empareje y ejecute una orden de venta.
    function testAddBuyOrderWithHigherPriceThanSellOrder() public {
        // Caso 3: Orden de compra con precio mayor a una orden de venta
        console.log("Balance T2_A INICIAL", tokenA.balanceOf(trader2));
        console.log("Balance T2_B INICIAL", tokenB.balanceOf(trader2));

        console.log("Balance Contract TA INICIAL", tokenA.balanceOf(address(pair)));
        console.log("Balance Contract TB INICIAL", tokenB.balanceOf(address(pair)));

        vm.prank(trader1);
        pair.addSellBaseToken(90 * 10 ** 18, quantity, trader2, nonce); //Vende tokenB por TokenA 10 tokens a 90

        console.log("Balance T2_A ADD SELL", tokenA.balanceOf(trader2));
        console.log("Balance T2_B ADD SELL", tokenB.balanceOf(trader2));

        console.log("Balance Contract TA", tokenA.balanceOf(address(pair)));
        console.log("Balance Contract TB", tokenB.balanceOf(address(pair)));

        vm.prank(trader2);
        pair.addBuyBaseToken(price, quantity, trader1, nonce); //Compra tokenB por tokenA 10 tokens a 100

        console.log("Balance T2_A FIN", tokenA.balanceOf(trader2));
        console.log("Balance T2_B FIN", tokenB.balanceOf(trader2));

        console.log("Balance T1_A FIN", tokenA.balanceOf(trader1));
        console.log("Balance T1_B FIN", tokenB.balanceOf(trader1));

        assertEq(pair.lastTradePrice(), 90 * 10 ** 18, "El ultimo precio deberia ser 90");
        assertEq(pair.getFirstSellOrders(), 0, "La orden de venta debe haberse emparejado completamente");
        assertEq(pair.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
        assertEq(tokenB.balanceOf(trader1), 900); // Verificar que el balance restante es correcto
        assertEq(tokenA.balanceOf(trader2), 10); // Verificar que el balance restante es correcto
    }

    //Confirma que una orden de compra con un precio más bajo se almacena sin ejecutarse si no encuentra un match.
    function testAddBuyOrderWithLowerPriceThanSellOrder() public {
        // Caso 4: Orden de compra con precio menor que la orden de venta
        vm.prank(trader1);
        pair.addSellBaseToken(110 * 10 ** 18, quantity, trader2, nonce);

        console.log("Balance T2_A FIN", tokenA.balanceOf(trader2));
        console.log("Balance T2_B FIN", tokenB.balanceOf(trader2));

        console.log("Balance T1_A FIN", tokenA.balanceOf(trader1));
        console.log("Balance T1_B FIN", tokenB.balanceOf(trader1));

        vm.prank(trader2);
        pair.addBuyBaseToken(price, quantity, trader1, nonce);

        // Verificar que la orden de compra no se empareja y se almacena
        assertEq(pair.getFirstSellOrders(), 110 * 10 ** 18, "La orden de venta no debe haberse emparejado");
        assertEq(pair.getFirstBuyOrders(), 100 * 10 ** 18, "La orden de compra debe haberse almacenado");
    }

    //Asegura que una orden de compra parcial se almacene correctamente si la orden de venta tiene menor cantidad.
    function testAddBuyOrderWithPartialQuantity() public {
        // Caso 5: Orden de compra con cantidad parcial
        vm.prank(trader1);
        pair.addSellBaseToken(price, 5, trader2, nonce);
        vm.prank(trader2);
        pair.addBuyBaseToken(price, quantity, trader1, nonce);

        // Verificar que la orden de compra se empareje parcialmente
        assertEq(pair.getFirstSellOrders(), 0, "La orden de venta debe haberse emparejado");
        assertEq(
            pair.getFirstBuyOrders(),
            100 * 10 ** 18,
            "La cantidad restante de la orden de compra debe estar almacenada"
        );
        assertEq(tokenB.balanceOf(trader1), 500); // Verificar que el balance restante es correcto
        assertEq(tokenA.balanceOf(trader2), 5); // Verificar que el balance restante es correcto
    }

    //Verifica que una orden de compra con exceso de cantidad se ejecute correctamente y que el remanente de la venta quede en el libro.
    function testAddBuyOrderWithExcessQuantity() public {
        // Caso 6: Orden de compra con exceso de cantidad
        console.log("Balance T2_A FIN", tokenA.balanceOf(trader2));
        console.log("Balance T2_B FIN", tokenB.balanceOf(trader2));

        console.log("Balance T1_A FIN", tokenA.balanceOf(trader1));
        console.log("Balance T1_B FIN", tokenB.balanceOf(trader1));
        console.log("ENTRANDO");
        vm.startPrank(trader1);
        pair.addSellBaseToken(price, 15, trader2, nonce); // Orden de venta con más cantidad
        vm.stopPrank();
        console.log("Balance T2_A FIN", tokenA.balanceOf(trader2));
        console.log("Balance T2_B FIN", tokenB.balanceOf(trader2));

        console.log("Balance T1_A FIN", tokenA.balanceOf(trader1));
        console.log("Balance T1_B FIN", tokenB.balanceOf(trader1));

        //vm.prank(trader1);
        vm.startPrank(trader2);
        pair.addBuyBaseToken(price, quantity, trader1, nonce);
        vm.stopPrank();

        // Verificar que la orden de venta se ejecute parcialmente
        assertEq(pair.getFirstSellOrders(), price, "La orden de venta debe tener una cantidad restante");
        assertEq(pair.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
        //assertEq(book.buyOrders[price].length, 0, "La orden de compra debe haberse ejecutado completamente");
    }

    //Asegura que una orden de compra se empareje con múltiples órdenes de venta a diferentes precios.
    function testAddBuyOrderWithMultipleSellOrders() public {
        // Caso 7: Orden de compra con varios matches de órdenes de venta
        vm.startPrank(trader1);
        pair.addSellBaseToken(90, 5, trader2, nonce); // Orden de venta con menor precio
        pair.addSellBaseToken(price, 5, trader2, nonce); // Otra orden de venta con precio igual
        vm.stopPrank();

        vm.prank(trader2);
        pair.addBuyBaseToken(price, quantity, trader1, nonce);

        // Verificar que todas las órdenes de venta se hayan emparejado
        assertEq(pair.getFirstSellOrders(), 0, unicode"Todas las órdenes de venta deben haberse emparejado");
        assertEq(pair.getFirstBuyOrders(), 0, unicode"La orden de compra debe haberse ejecutado completamente");
    }

    /*//Valida que una orden expirada no se almacene y emita un error.
    function testAddBuyOrderWithExpiredOrder() public {
        // Caso 8: Orden de compra expirada
        expired = block.timestamp - 1 days; // Orden expirada
        vm.expectRevert("Order expired");
        book.addBuyOrder(price, quantity, trader1, nonce);
    }

    //Confirma que una orden con expiración cero no se almacena si no puede ejecutarse completamente.
    function testAddBuyOrderWithFillOrKill() public {
        // Caso 9: Orden de compra con expiración cero (Fill or Kill)
        expired = 0; // Expiración cero significa fill or kill
        book.addSellOrder(100, 5, trader2, nonce);// Orden de venta con menor precio
        book.addBuyOrder(price, quantity, trader1, nonce);

        // Verificar que la orden de compra no se almacene si no se puede ejecutar completamente
        assertEq(book.buyOrders[price].length, 0, "La orden de compra no debe almacenarse si no se puede llenar completamente");
    }*/

    //-------------------- ADD SELL ORDER ------------------------------
    //Árbol de órdenes de compra vacío: Prueba la inserción directa de una orden de venta cuando no hay órdenes de compra.
    function testAddSellOrderWithoutBuyOrders() public {
        // Inicialmente no hay órdenes de compra
        assertEq(pair.getLastBuyOrders(), 0, unicode"El árbol de órdenes de compra debe estar vacío");

        // Agregar una orden de venta
        uint256 price = 100;
        uint256 quantity = 10;
        console.log("Balance T2_A FIN", tokenA.balanceOf(trader2));
        console.log("Balance T2_B FIN", tokenB.balanceOf(trader2));

        console.log("Balance T1_A FIN", tokenA.balanceOf(trader1));
        console.log("Balance T1_B FIN", tokenB.balanceOf(trader1));
        vm.prank(trader1);
        pair.addSellBaseToken(price, quantity, trader2, nonce);

        // Verificar que la orden de venta se haya agregado al libro de órdenes de venta
        assertEq(pair.getFirstSellOrders(), 100, "La orden de venta debe haberse agregado correctamente");
    }

    function testAddSellOrderWithMatchingSellOrder() public {
        // Caso 2: Orden de venta con precio igual a una orden de compra

        vm.prank(trader2);
        pair.addBuyBaseToken(price, quantity, trader1, nonce);

        vm.startPrank(trader1);
        pair.addSellBaseToken(price, quantity, trader2, nonce);
        vm.stopPrank();

        // Verificar que la orden de compra se haya emparejado y eliminado
        assertEq(pair.getFirstSellOrders(), 0, "La orden de venta debe haberse emparejado completamente");
        assertEq(pair.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
        assertEq(tokenB.balanceOf(trader1), 1000); // Verificar que el balance restante es correcto
        assertEq(tokenA.balanceOf(trader2), 10); // Verificar que el balance restante es correcto
    }

    function testAddSellOrderWithMatchingDifferentSellOrder() public {
        // Caso 2: Orden de compra con precio igual varias ordenes de venta

        vm.startPrank(trader2);
        pair.addBuyBaseToken(price, 5, trader1, nonce);
        pair.addBuyBaseToken(price, 5, trader1, nonce + 1);
        pair.addBuyBaseToken(price, 5, trader1, nonce + 2);
        vm.stopPrank();

        vm.startPrank(trader1);
        pair.addSellBaseToken(price, 15, trader2, nonce);
        vm.stopPrank();

        //vm.prank(trader1);

        assertEq(pair.getFirstSellOrders(), 0, "La orden de venta debe haberse emparejado completamente");
        assertEq(pair.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
        assertEq(tokenB.balanceOf(trader1), 1500); // Verificar que el balance restante es correcto
        assertEq(tokenA.balanceOf(trader2), 15); // Verificar que el balance restante es correcto
    }

    //Matching con precio de venta más bajo: Prueba la coincidencia de órdenes cuando el precio de venta es menor o igual al de compra.
    function testAddSellOrderWithLowerPriceMatchingBuyOrder() public {
        // Insertar una orden de compra con un precio más alto
        vm.prank(trader2);
        pair.addBuyBaseToken(110, quantity, trader1, nonce); // Orden de compra con un precio de 110

        // Agregar una orden de venta con un precio más bajo (match)
        uint256 price = 100;
        uint256 quantity = 10;

        vm.prank(trader1);
        pair.addSellBaseToken(price, quantity, trader2, nonce);

        // Verificar que la orden de compra se haya emparejado completamente
        assertEq(pair.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");

        // Verificar que no haya órdenes de venta pendientes a este precio
        assertEq(
            pair.getFirstSellOrders(), 0, unicode"No debe haber órdenes de venta pendientes si se emparejaron"
        );
    }

    //Sin matching con precio de venta más alto: Verifica que no se realice matching si el precio de venta es mayor al de compra.
    function testAddSellOrderWithHigherPriceNoMatching() public {
        // Insertar una orden de compra con un precio más bajo
        vm.prank(trader2);
        pair.addBuyBaseToken(90, quantity, trader1, nonce); // Orden de compra con precio de 90

        // Agregar una orden de venta con un precio más alto (no match)
        uint256 price = 100;
        uint256 quantity = 10;
        vm.prank(trader1);
        pair.addSellBaseToken(price, quantity, trader2, nonce);

        // Verificar que la orden de compra se haya emparejado completamente
        assertEq(pair.getFirstBuyOrders(), 90, "La orden de venta debe haberse agregado correctamente");

        // Verificar que no haya órdenes de venta pendientes a este precio
        assertEq(pair.getFirstSellOrders(), 100, "La orden de compra no debe haberse ejecutado");
    }

    //Matching parcial: Prueba que las órdenes de venta se emparejen parcialmente y dejen una cantidad restante.
    function testAddSellOrderWithPartialMatching() public {
        // Insertar una orden de compra con un precio igual pero una cantidad menor

        console.log("Balance T2_A INICIO 1", tokenA.balanceOf(trader2));
        console.log("Balance T2_B INICIO 1", tokenB.balanceOf(trader2));

        console.log("Balance T1_A INICIO 1", tokenA.balanceOf(trader1));
        console.log("Balance T1_B INICIO 1", tokenB.balanceOf(trader1));

        console.log("Balance Contract TA INICIAL 1", tokenA.balanceOf(address(pair)));
        console.log("Balance Contract TB INICIAL 1", tokenB.balanceOf(address(pair)));

        vm.prank(trader2);
        pair.addBuyBaseToken(price, 5, trader1, nonce); // Orden de compra con precio 100 y cantidad 5

        console.log("Balance T2_A INICIO", tokenA.balanceOf(trader2));
        console.log("Balance T2_B INICIO", tokenB.balanceOf(trader2));

        console.log("Balance T1_A INICIO", tokenA.balanceOf(trader1));
        console.log("Balance T1_B INICIO", tokenB.balanceOf(trader1));

        console.log("Balance Contract TA INICIAL", tokenA.balanceOf(address(pair)));
        console.log("Balance Contract TB INICIAL", tokenB.balanceOf(address(pair)));

        // Agregar una orden de venta con una cantidad mayor
        //uint256 quantity = 10; // Orden de venta de cantidad 10

        vm.prank(trader1);
        pair.addSellBaseToken(price, 10, trader2, nonce);

        // Verificar que la orden de compra se haya ejecutado completamente
        assertEq(pair.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");

        console.log("Balance T2_A FIN", tokenA.balanceOf(trader2));
        console.log("Balance T2_B FIN", tokenB.balanceOf(trader2));

        console.log("Balance T1_A FIN", tokenA.balanceOf(trader1));
        console.log("Balance T1_B FIN", tokenB.balanceOf(trader1));

        console.log("Balance Contract TA FIN", tokenA.balanceOf(address(pair)));
        console.log("Balance Contract TB FIN", tokenB.balanceOf(address(pair)));

        assertEq(
            pair.getFirstSellOrders(),
            100 * 10 ** 18,
            "La orden de venta debe haberse emparejado completamente"
        );
        assertEq(pair.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
        assertEq(tokenB.balanceOf(trader1), 500); // Verificar que el balance restante es correcto
        assertEq(tokenA.balanceOf(trader2), 5); // Verificar que el balance restante es correcto
        assertEq(tokenA.balanceOf(address(pair)), 5); // Verificar que el balance restante es correcto
    }

    //Límite de órdenes alcanzado: Prueba que el contrato maneje correctamente el límite de órdenes a procesar.
    /*function testAddSellOrderOrderCountLimitReached() public {
        // Insertar varias órdenes de compra para simular un gran número de coincidencias
        for (uint256 i = 0; i < 150; i++) {
            vm.prank(trader1);
            book.buyOrders.insert(100 + i, 1); // Órdenes de compra con precios incrementales
        }

        // Agregar una orden de venta
        uint256 price = 100;
        uint256 quantity = 10;
        book.addSellOrder(price, quantity, trader1, nonce);

        // Verificar que la orden de venta se haya guardado, ya que no se puede emparejar más de 150 órdenes
        assertEq(book.sellOrders[price].length, 1, "La orden de venta debe haberse agregado correctamente después de alcanzar el límite");
    }*/

    //-------------------- CANCEL ORDER ------------------------------

    //Cancelación exitosa de una orden de compra: Se verifica que la orden de compra es eliminada correctamente.
    function testCancelBuyOrder() public {
        // Insertar una orden de compra
        uint256 initial_balance = tokenB.balanceOf(trader2);
        vm.prank(trader2);
        pair.addBuyBaseToken(price, 5, trader2, nonce); // Orden de compra con precio 100 y cantidad 5

        bytes32 _orderId = keccak256(abi.encodePacked(trader2, "buy", price, nonce));

        // Cancelar la orden de compra
        vm.prank(trader2);
        pair.getCancelOrder(_orderId);
        uint256 final_balance = tokenB.balanceOf(trader2);

        // Verificar que la orden haya sido eliminada del árbol de órdenes de compra
        assertEq(pair.getFirstBuyOrders(), 0, "La orden de compra debe haber sido eliminada");
        assertEq(final_balance, initial_balance, "El balance inicial y final deberia ser igual");
    }

    //Cancelación exitosa de una orden de venta: Similar al caso anterior pero con órdenes de venta.
    function testCancelSellOrder() public {
        // Insertar una orden de venta
        uint256 initial_balance = tokenA.balanceOf(trader1);
        vm.prank(trader1);
        pair.addSellBaseToken(price, 10, trader1, nonce);

        bytes32 _orderId = keccak256(abi.encodePacked(trader1, "sell", price, nonce));

        // Cancelar la orden de venta
        vm.prank(trader1);
        pair.getCancelOrder(_orderId);
        uint256 final_balance = tokenA.balanceOf(trader1);

        // Verificar que la orden haya sido eliminada del árbol de órdenes de venta
        //assertEq(book.sellOrders[100].length, 0, "La orden de venta debe haber sido eliminada");
        assertEq(pair.getFirstSellOrders(), 0, "La orden de venta debe haber sido eliminada");
        assertEq(final_balance, initial_balance, "El balance inicial y final deberia ser igual");
    }

    //Intento de cancelación de una orden inexistente: Asegura que no ocurre ninguna acción cuando se intenta cancelar una orden inexistente.
    function testCancelNonExistentOrder() public {
        // Intentar cancelar una orden que no existe
        bytes32 _orderId = keccak256(abi.encodePacked(trader1, "buy", price, nonce));

        // Intentar cancelar la orden inexistente
        vm.expectRevert(PairLib.PL__OrderIdDoesNotExist.selector);
        pair.getCancelOrder(_orderId);
    }

    //Cancelación de una orden entre múltiples órdenes: Verifica que el array de órdenes del trader se reordene correctamente.
    function testCancelOrderAmongMultipleOrders() public {
        // Insertar varias órdenes de compra
        vm.startPrank(trader2);
        pair.addBuyBaseToken(price, 10, trader2, nonce); // Orden de compra con precio 100 y cantidad 5
        pair.addBuyBaseToken(price, 5, trader2, nonce + 1); // Orden de compra con precio 100 y cantidad 5
        vm.stopPrank();

        bytes32 _orderId1 = keccak256(abi.encodePacked(trader2, "buy", price, nonce));
        bytes32 _orderId2 = keccak256(abi.encodePacked(trader2, "buy", price, nonce + 1));

        // Cancelar la primera orden
        //console.logBytes32(orderBookImpl.getFirstOrderBuyById(price));
        assertEq(pair.getFirstOrderBuyByPrice(price), _orderId1, "La primera orden debe ser orderId1");

        vm.prank(trader2);
        pair.getCancelOrder(_orderId1);

        //console.logBytes32(_orderId2);
        //console.logBytes32(orderBookImpl.getFirstOrderBuyById(price));

        // Verificar que la segunda orden se haya movido a la primera posición
        assertEq(
            pair.getFirstOrderBuyByPrice(price),
            _orderId2,
            unicode"La segunda orden debe haberse movido a la primera posición"
        );
    }

    //Cancelación de una orden que no pertenece al msg.sender: Asegura que un usuario no puede cancelar una orden que no le pertenece.
    function testCancelOrderNotOwner() public {
        // Insertar una orden de compra para trader1
        bytes32 orderId = keccak256(abi.encodePacked(trader2, "buy", price, nonce));

        vm.startPrank(trader2);
        pair.addBuyBaseToken(price, 10, trader2, nonce); // Orden de compra con precio 100 y cantidad 5
        vm.stopPrank();

        // Intentar cancelar la orden desde otro trader
        //vm.expectRevert("Order not found");
        vm.prank(trader1);
        vm.expectRevert(PairLib.PL__OrderDoesNotBelongToCurrentTrader.selector);
        pair.getCancelOrder(orderId);

        // Verificar que la orden no fue cancelada
        //assertEq(book.buyOrders[100].length, 1, "La orden de compra no debe haber sido eliminada");
    }

    //-------------------- GET TRADER ORDER ------------------------------
    //Obtener órdenes de un trader con varias órdenes: Verifica que todas las órdenes del trader se devuelven correctamente.
    function testGetTraderOrdersWithMultipleOrders() public {
        // Insertar varias órdenes para trader1
        bytes32 orderId1 = keccak256(abi.encodePacked(trader2, "buy", price, nonce));
        bytes32 orderId2 = keccak256(abi.encodePacked(trader2, "buy", price, nonce + 1));

        vm.startPrank(trader2);
        pair.addBuyBaseToken(price, 1, trader2, nonce); // Orden de compra con precio 100 y cantidad 5
        pair.addBuyBaseToken(price, 2, trader2, nonce + 1); // Orden de compra con precio 100 y cantidad 5
        vm.stopPrank();

        // Obtener las órdenes
        bytes32[] memory orders = pair.getTraderOrders(trader2);

        // Verificar que se devuelven las órdenes correctas
        assertEq(orders.length, 2, unicode"Debe devolver dos órdenes");
        assertEq(orders[0], orderId1, "La primera orden debe coincidir");
        assertEq(orders[1], orderId2, "La segunda orden debe coincidir");
    }

    //Obtener órdenes de un trader sin órdenes: Asegura que se devuelva un array vacío si el trader no tiene órdenes.
    function testGetTraderOrdersWithNoOrders() public {
        // Verificar que trader2 no tiene órdenes
        bytes32[] memory orders = pair.getTraderOrders(trader2);

        // Verificar que se devuelva un array vacío
        assertEq(orders.length, 0, unicode"Debe devolver un array vacío si el trader no tiene órdenes");
    }

    //Obtener órdenes de un trader con solo una orden: Prueba que, si solo hay una orden, esta se devuelva correctamente.
    function testGetTraderOrdersWithSingleOrder() public {
        // Insertar una única orden para trader1
        bytes32 orderId = keccak256(abi.encodePacked(trader2, "buy", price, nonce));
        vm.startPrank(trader2);
        pair.addBuyBaseToken(price, 1, trader2, nonce); // Orden de compra con precio 100 y cantidad 5
        vm.stopPrank();

        // Obtener las órdenes
        bytes32[] memory orders = pair.getTraderOrders(trader2);

        // Verificar que se devuelve una sola orden
        assertEq(orders.length, 1, unicode"Debe devolver una única orden");
        assertEq(orders[0], orderId, "La orden devuelta debe coincidir");
    }

    //Obtener órdenes de un trader inexistente: Confirma que un trader que nunca ha tenido órdenes devuelve un array vacío.
    function testGetTraderOrdersForNonExistentTrader() public {
        // Obtener las órdenes para un trader inexistente (que nunca ha tenido órdenes)
        bytes32[] memory orders = pair.getTraderOrders(address(0x1234));

        // Verificar que se devuelva un array vacío
        assertEq(orders.length, 0, unicode"Debe devolver un array vacío si el trader no existe");
    }

    //Verificar la inmutabilidad del array devuelto: Asegura que el array devuelto es una copia y no puede ser modificado directamente.
    function testImmutabilityOfReturnedArray() public {
        // Insertar una orden para trader1
        bytes32 orderId = keccak256(abi.encodePacked(trader2, "buy", price, nonce));
        vm.startPrank(trader2);
        pair.addBuyBaseToken(price, 1, trader2, nonce); // Orden de compra con precio 100 y cantidad 5
        vm.stopPrank();
        // Obtener las órdenes
        bytes32[] memory orders = pair.getTraderOrders(trader2);

        // Intentar modificar el array devuelto
        orders[0] = keccak256(abi.encodePacked(trader2, "sell", price + 100, nonce + 1));

        // Volver a obtener las órdenes del storage
        bytes32[] memory ordersAfterModification = pair.getTraderOrders(trader2);

        // Verificar que la modificación no afectó el almacenamiento original
        assertEq(ordersAfterModification[0], orderId, unicode"El array devuelto no debe modificar el estado original");
    }

    //-------------------- GET ORDER BY ID ------------------------------

    //Recuperar una orden de compra existente: Verifica que la función devuelve los detalles correctos de una orden de compra.
    function testGetBuyOrderById() public {
        // Crear una orden de compra para trader1
        bytes32 orderId = keccak256(abi.encodePacked(trader2, "buy", price, nonce));

        vm.startPrank(trader2);
        pair.addBuyBaseToken(price, quantity, trader2, nonce); // Orden de compra con precio 100 y cantidad 5
        vm.stopPrank();

        // Obtener la orden por su ID
        OrderBookLib.Order memory result = pair.getOrderById( orderId);

        // Verificar los detalles de la orden devuelta
        assertEq(result.price, price, "El precio de la orden debe ser 100");
        assertEq(result.quantity, quantity, "La cantidad de la orden debe ser 10");
    }

    //Recuperar una orden de venta existente: Asegura que la función devuelve los detalles correctos de una orden de venta.
    function testGetSellOrderById() public {
        // Crear una orden de venta para trader1
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "sell", price, nonce));

        // Insertar una orden de venta
        vm.prank(trader1);
        pair.addSellBaseToken(price, 10, trader1, nonce);

        // Obtener la orden por su ID
        OrderBookLib.Order memory result = pair.getOrderById( orderId);

        // Verificar los detalles de la orden devuelta
        assertEq(result.price, price, "El precio de la orden debe ser 100");
        assertEq(result.quantity, 10, "La cantidad de la orden debe ser 10");
    }

    //Intentar recuperar una orden inexistente: Confirma que la función maneja correctamente órdenes inexistentes (usualmente con revert).
    function testGetNonExistentOrderById() public {
        // Crear un ID de orden que no exista
        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", price, nonce));

        // Intentar obtener la orden inexistente
        vm.expectRevert(PairLib.PL__OrderIdDoesNotExist.selector);
        pair.getOrderById( orderId);
    }

    //Recuperar una orden con un orderId inválido: Asegura que la función no devuelve detalles de órdenes con IDs inválidos.
    function testGetOrderWithInvalidId() public {
        // Usar un `orderId` inválido (que no existe)
        bytes32 invalidOrderId = keccak256(abi.encodePacked(trader1, "invalid", price, nonce));

        vm.startPrank(trader2);
        pair.addBuyBaseToken(price, quantity, trader1, nonce); // Orden de compra con precio 100 y cantidad 5
        vm.stopPrank();

        // Intentar obtener la orden inválida
        vm.expectRevert(); // Espera que la operación falle
        pair.getOrderById( invalidOrderId);
    }

    //Recuperar una orden de un trader sin órdenes: Verifica que la función maneje correctamente cuando un trader no tiene órdenes.
    function testGetOrderForTraderWithoutOrders() public {
        // Intentar obtener una orden para un trader que no tiene órdenes
        bytes32 orderId = keccak256(abi.encodePacked(trader2, "buy", price, quantity));

        vm.startPrank(trader2);
        pair.addBuyBaseToken(price, quantity, trader1, nonce); // Orden de compra con precio 100 y cantidad 5
        vm.stopPrank();

        // Verificar que se revertirá la transacción ya que trader2 no tiene órdenes
        vm.expectRevert(); // Espera que la operación falle
        pair.getOrderById( orderId);
    }

    //Verifica que una orden de compra se ejecute completamente si encuentra una orden de venta con el mismo precio.
    function testMatchingOrders1() public {
        // Caso 2: Orden de compra con precio igual a una orden de venta

        vm.startPrank(trader1);
        pair.addSellBaseToken(10 * 10 ** 18, 50, trader1, nonce);
        vm.stopPrank();

        vm.prank(trader2);
        pair.addBuyBaseToken(10 * 10 ** 18, 50, trader2, nonce);

        // Verificar que la orden de compra se haya emparejado y eliminado
        assertEq(pair.getFirstSellOrders(), 0, "La orden de venta debe haberse emparejado completamente");
        assertEq(pair.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
        assertEq(tokenB.balanceOf(trader1), 500); // Verificar que el balance restante es correcto
        assertEq(tokenA.balanceOf(trader2), 50); // Verificar que el balance restante es correcto
    }

    //Verifica que una orden de compra se ejecute completamente si encuentra una orden de venta con el mismo precio.
    function testMatchingOrders2() public {
        // Caso 2: Orden de compra con precio igual a una orden de venta

        vm.prank(trader2);
        pair.addBuyBaseToken(10 * 10 ** 18, 50, trader2, nonce);

        vm.startPrank(trader1);
        pair.addSellBaseToken(10 * 10 ** 18, 50, trader1, nonce);
        vm.stopPrank();

        // Verificar que la orden de compra se haya emparejado y eliminado
        assertEq(pair.getFirstSellOrders(), 0, "La orden de venta debe haberse emparejado completamente");
        assertEq(pair.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
        assertEq(tokenB.balanceOf(trader1), 500); // Verificar que el balance restante es correcto
        assertEq(tokenA.balanceOf(trader2), 50); // Verificar que el balance restante es correcto
    }

    //Verifica que una orden de compra se ejecute completamente si encuentra una orden de venta con el mismo precio.
    function testMatchingOrders3() public {
        // Caso 2: Orden de compra con precio igual a una orden de venta

        vm.startPrank(trader1);
        pair.addSellBaseToken(0.1 * 10 ** 18, 50, trader1, nonce);
        vm.stopPrank();

        vm.prank(trader2);
        pair.addBuyBaseToken(0.1 * 10 ** 18, 50, trader2, nonce);

        // Verificar que la orden de compra se haya emparejado y eliminado
        assertEq(pair.getFirstSellOrders(), 0, "La orden de venta debe haberse emparejado completamente");
        assertEq(pair.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
        assertEq(tokenB.balanceOf(trader1), 5); // Verificar que el balance restante es correcto
        assertEq(tokenA.balanceOf(trader2), 50); // Verificar que el balance restante es correcto
    }

    //Verifica que una orden de compra se ejecute completamente si encuentra una orden de venta con el mismo precio.
    function testMatchingOrders4() public {
        // Caso 2: Orden de compra con precio igual a una orden de venta

        vm.prank(trader2);
        pair.addBuyBaseToken(0.1 * 10 ** 18, 50, trader2, nonce);

        vm.startPrank(trader1);
        pair.addSellBaseToken(0.1 * 10 ** 18, 50, trader1, nonce);
        vm.stopPrank();

        // Verificar que la orden de compra se haya emparejado y eliminado
        assertEq(pair.getFirstSellOrders(), 0, "La orden de venta debe haberse emparejado completamente");
        assertEq(pair.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
        assertEq(tokenB.balanceOf(trader1), 5); // Verificar que el balance restante es correcto
        assertEq(tokenA.balanceOf(trader2), 50); // Verificar que el balance restante es correcto
    }

    function testEmptyOrderBook() public {
        uint256[3] memory topBuyPrices = pair.getTop3BuyPrices();
        uint256[3] memory topSellPrices = pair.getTop3SellPrices();

        assertEqualArrays(topBuyPrices, [uint256(0), 0, 0]);
        assertEqualArrays(topSellPrices, [uint256(0), 0, 0]);
    }

    function testOnePrice() public {
        vm.prank(trader2);
        pair.createOrder(true, 100, 10);
        vm.prank(trader1);
        pair.createOrder(false, 110, 10);

        uint256[3] memory topBuyPrices = pair.getTop3BuyPrices();
        uint256[3] memory topSellPrices = pair.getTop3SellPrices();

        assertEqualArrays(topBuyPrices, [uint256(100), 0, 0]);
        assertEqualArrays(topSellPrices, [uint256(110), 0, 0]);
    }

    function testTwoPrices() public {
        vm.startPrank(trader2);
        pair.createOrder(true, 100, 10);
        pair.createOrder(true, 90, 10);
        vm.stopPrank();
        vm.startPrank(trader1);
        pair.createOrder(false, 110, 10);
        pair.createOrder(false, 120, 10);
        vm.stopPrank();

        uint256[3] memory topBuyPrices = pair.getTop3BuyPrices();
        uint256[3] memory topSellPrices = pair.getTop3SellPrices();

        assertEqualArrays(topBuyPrices, [uint256(100), 90, 0]);
        assertEqualArrays(topSellPrices, [uint256(110), 120, 0]);
    }

    function testThreeOrMorePrices() public {
        vm.startPrank(trader2);
        pair.createOrder(true, 100, 10);
        pair.createOrder(true, 90, 10);
        pair.createOrder(true, 95, 10);
        pair.createOrder(true, 85, 10);
        vm.stopPrank();
        vm.startPrank(trader1);
        pair.createOrder(false, 110, 10);
        pair.createOrder(false, 120, 10);
        pair.createOrder(false, 115, 10);
        pair.createOrder(false, 125, 10);
        vm.stopPrank();

        uint256[3] memory topBuyPrices = pair.getTop3BuyPrices();
        uint256[3] memory topSellPrices = pair.getTop3SellPrices();

        assertEqualArrays(topBuyPrices, [uint256(100), 95, 90]);
        assertEqualArrays(topSellPrices, [uint256(110), 115, 120]);
    }

    function testBuyOrdersDescendingOrder() public {
        vm.startPrank(trader2);
        pair.createOrder(true, 100, 10);
        pair.createOrder(true, 90, 10);
        pair.createOrder(true, 95, 10);
        vm.stopPrank();

        uint256[3] memory topBuyPrices = pair.getTop3BuyPrices();

        assertTrue(topBuyPrices[0] > topBuyPrices[1]);
        assertTrue(topBuyPrices[1] > topBuyPrices[2]);
    }

    function testSellOrdersAscendingOrder() public {
        vm.startPrank(trader1);
        pair.createOrder(false, 110, 10);
        pair.createOrder(false, 120, 10);
        pair.createOrder(false, 115, 10);
        vm.stopPrank();

        uint256[3] memory topSellPrices = pair.getTop3SellPrices();

        assertTrue(topSellPrices[0] < topSellPrices[1]);
        assertTrue(topSellPrices[1] < topSellPrices[2]);
    }

    function testLargeNumberOfOrders() public {
        for (uint i = 1; i <= 100; i++) {
            vm.prank(trader2);
            pair.createOrder(true, i * 10, 10);
            vm.prank(trader1);
            pair.createOrder(false, 1000 + i * 10, 10);
        }

        uint256[3] memory topBuyPrices = pair.getTop3BuyPrices();
        uint256[3] memory topSellPrices = pair.getTop3SellPrices();

        assertEqualArrays(topBuyPrices, [uint256(1000), 990, 980]);
        assertEqualArrays(topSellPrices, [uint256(1010), 1020, 1030]);
    }

    function testEdgeCases() public {
        vm.startPrank(trader2);
        vm.expectRevert(stdError.arithmeticError);
        pair.createOrder(true, type(uint256).max, 10);
        vm.expectRevert(stdError.arithmeticError);
        pair.createOrder(true, type(uint256).max - 1, 10);
        vm.stopPrank();
        vm.startPrank(trader1);
        pair.createOrder(false, 1, 10);
        pair.createOrder(false, 2, 10);
        vm.stopPrank();

        uint256[3] memory topBuyPrices = pair.getTop3BuyPrices();
        uint256[3] memory topSellPrices = pair.getTop3SellPrices();

    }

    function testDuplicatePrices() public {
        vm.startPrank(trader2);
        pair.createOrder(true, 100, 10);
        pair.createOrder(true, 100, 20);
        pair.createOrder(true, 90, 30);
        vm.stopPrank();
        vm.startPrank(trader1);
        pair.createOrder(false, 110, 10);
        pair.createOrder(false, 110, 20);
        pair.createOrder(false, 120, 30);
        vm.stopPrank();

        uint256[3] memory topBuyPrices = pair.getTop3BuyPrices();
        uint256[3] memory topSellPrices = pair.getTop3SellPrices();

        assertEqualArrays(topBuyPrices, [uint256(100), 90, 0]);
        assertEqualArrays(topSellPrices, [uint256(110), 120, 0]);
    }

    function testUpdatedOrderBook() public {
        vm.startPrank(trader2);
        pair.createOrder(true, 100, 10);
        pair.createOrder(true, 90, 10);
        vm.stopPrank();
        vm.startPrank(trader1);
        pair.createOrder(false, 110, 10);
        pair.createOrder(false, 120, 10);
        vm.stopPrank();

        uint256[3] memory topBuyPrices = pair.getTop3BuyPrices();
        uint256[3] memory topSellPrices = pair.getTop3SellPrices();

        assertEqualArrays(topBuyPrices, [uint256(100), 90, 0]);
        assertEqualArrays(topSellPrices, [uint256(110), 120, 0]);

        vm.prank(trader2);
        pair.createOrder(true, 95, 10);
        vm.prank(trader1);
        pair.createOrder(false, 115, 10);

        topBuyPrices = pair.getTop3BuyPrices();
        topSellPrices = pair.getTop3SellPrices();

        assertEqualArrays(topBuyPrices, [uint256(100), 95, 90]);
        assertEqualArrays(topSellPrices, [uint256(110), 115, 120]);
    }


    function testGetPrice() public {
        // 1. Empty order book
        (uint256 emptyValue, uint256 emptyCount) = pair.getPrice(100, true);
        assertEq(emptyValue, 0);
        assertEq(emptyCount, 0);

        // Add some orders to the book
        addMockOrders();

        // 2. Price point exists with orders (buy order)
        (uint256 buyValue, uint256 buyCount) = pair.getPrice(95, true);
        assertEq(buyValue, 100);
        assertEq(buyCount, 1);

        // 3. Price point does not exist
        (uint256 nonExistentValue, uint256 nonExistentCount) = pair.getPrice(99, true);
        assertEq(nonExistentValue, 0);
        assertEq(nonExistentCount, 0);

        // 4. Price point is the first (highest for buy)
        (uint256 highestBuyValue, uint256 highestBuyCount) = pair.getPrice(100, true);
        assertEq(highestBuyValue, 201);
        assertEq(highestBuyCount, 2);

        // 5. Price point is in the middle of the order book
        (uint256 middleSellValue, uint256 middleSellCount) = pair.getPrice(105, false);
        assertEq(middleSellValue, 150);
        assertEq(middleSellCount, 1);

        // 6. Price point is the last (lowest for sell)
        (uint256 lowestSellValue, uint256 lowestSellCount) = pair.getPrice(102, false);
        assertEq(lowestSellValue, 100);
        assertEq(lowestSellCount, 1);

        // 7. Querying for buy orders
        (uint256 buyOrderValue, uint256 buyOrderCount) = pair.getPrice(95, true);
        assertEq(buyOrderValue, 100);
        assertEq(buyOrderCount, 1);

        // 8. Querying for sell orders
        (uint256 sellOrderValue, uint256 sellOrderCount) = pair.getPrice(110, false);
        assertEq(sellOrderValue, 201);
        assertEq(sellOrderCount, 2);
    }

    function addMockOrders() internal {
        // Add buy orders
        vm.startPrank(trader2);
        pair.createOrder(true, 100, 100);
        pair.createOrder(true, 100, 101);
        pair.createOrder(true, 95, 100);
        pair.createOrder(true, 90, 150);
        vm.stopPrank();

        // Add sell orders
        vm.startPrank(trader1);
        pair.createOrder(false, 102, 100);
        pair.createOrder(false, 105, 150);
        pair.createOrder(false, 110, 100);
        pair.createOrder(false, 110, 101);
        vm.stopPrank();
    }

}
