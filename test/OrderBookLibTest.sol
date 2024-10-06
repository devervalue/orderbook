//// SPDX-License-Identifier: MIT
//pragma solidity ^0.8.26;
//
//import "forge-std/Test.sol";
//import "../src/OrderQueue.sol";
//import "../src/RedBlackTree.sol";
//import "../src/OrderBookLib.sol";
//import "forge-std/console.sol";
//import "../src/MyTokenA.sol";
//import "../src/MyTokenB.sol";
//
//import "./OrderBookImpl.sol";
//
//contract OrderBookLibTest is Test {
//    // using OrderBookLib for OrderBookLib.OrderBook;
//    // using RedBlackTree for RedBlackTree.Tree;
//
//    //OrderBookLib.OrderBook private book;
//
//    OrderBookImpl private orderBookImpl;
//
//    //TOKENS
//    MyTokenA tokenA;
//    MyTokenB tokenB;
//
//    //ADDRESS
//    address addressContract;
//    address trader1 = makeAddr("trader1");
//    address trader2 = makeAddr("trader2");
//    address trader3 = makeAddr("trader3");
//
//    //GLOBAL DATA
//    uint256 price;
//    uint256 quantity;
//    uint256 nonce;
//    uint256 expired;
//
//    function setUp() public {
//        //addressContract = deployCode("OrderBookLib.sol");
//
//        //Creando token como suministro inicial
//        tokenA = new MyTokenA(1000 * 10 ** 18); //Crear un nuevo token con suministro inicial
//        tokenB = new MyTokenB(1000 * 10 ** 18); //Crear un nuevo token con suministro inicial
//
//        orderBookImpl = new OrderBookImpl(address(tokenA), address(tokenB));
//        console.log("addressContract", address(orderBookImpl));
//        console.log("address this", address(this));
//        //Enviando fondos a los traders
//        //token.approve(msg.sender, 1000 * 10 ** 18);
//        //tokenA.transfer(trader1,200 * 10 ** 18); //Doy fondos a trader 1
//        //tokenA.transfer(trader2,200 * 10 ** 18); //Doy fondos a trader 2
//        tokenA.transfer(trader1, 1500);
//        //tokenA.transfer(address(this),1); //Doy fondos a trader 2
//
//        //tokenB.transfer(trader1,200 * 10 ** 18); //Doy fondos a trader 1
//        tokenB.transfer(trader2, 1500);
//
//        //tokenB.transfer(address(this),1); //Doy fondos a trader 2
//        //tokenB.transfer(trader2,200 * 10 ** 18); //Doy fondos a trader 2
//
//        //token.approve(trader1, 1000 * 10 ** 18);
//
//        //Creando orderBook
//        price = 100;
//        quantity = 10;
//        nonce = 1;
//        expired = block.timestamp + 1 days;
//
//        //Aprobar el contrato para que pueda gastar tokens
//        vm.startPrank(trader1); // Cambiar el contexto a trader1
//        tokenA.approve(address(orderBookImpl), 1000 * 10 ** 18); // Aprobar 1000 tokens
//        vm.stopPrank();
//
//        vm.startPrank(trader2); // Cambiar el contexto a trader1
//        tokenB.approve(address(orderBookImpl), 1000 * 10 ** 18); // Aprobar 1000 tokens
//        vm.stopPrank();
//
//        vm.startPrank(address(orderBookImpl)); // Cambiar el contexto a trader1
//        tokenB.approve(address(orderBookImpl), 1000 * 10 ** 18); // Aprobar 1000 tokens
//        tokenA.approve(address(orderBookImpl), 1000 * 10 ** 18); // Aprobar 1000 tokens
//        vm.stopPrank();
//    }
//
//    //-------------------- ADD BUY ORDER ------------------------------
//    //Valida que si no hay órdenes de venta, la orden de compra se almacena en el libro.
//    function testAddBuyOrderWithoutSellOrders() public {
//        // Caso 1: Orden de compra sin órdenes de venta
//        uint256 balanceContractInitial = tokenA.balanceOf(address(orderBookImpl));
//
//        vm.startPrank(trader1);
//        orderBookImpl.addBuyBaseToken(price, quantity, trader1, nonce, expired);
//        vm.stopPrank();
//
//        uint256 balanceContract = tokenA.balanceOf(address(orderBookImpl));
//        assertEq(balanceContract - balanceContractInitial, 10); // Verificar que el balance restante es correcto
//        assertEq(orderBookImpl.getFirstBuyOrders(), 100, "La orden de compra debe estar almacenada");
//    }
//
//    //Verifica que una orden de compra se ejecute completamente si encuentra una orden de venta con el mismo precio.
//    function testAddBuyOrderWithMatchingSellOrder() public {
//        // Caso 2: Orden de compra con precio igual a una orden de venta
//
//        vm.startPrank(trader2);
//        orderBookImpl.addSellBaseToken(price, quantity, trader2, nonce, expired);
//        vm.stopPrank();
//
//        vm.prank(trader1);
//        orderBookImpl.addBuyBaseToken(price, quantity, trader1, nonce, expired);
//
//        // Verificar que la orden de compra se haya emparejado y eliminado
//        assertEq(orderBookImpl.getFirstSellOrders(), 0, "La orden de venta debe haberse emparejado completamente");
//        assertEq(orderBookImpl.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
//        assertEq(tokenB.balanceOf(trader1), 10); // Verificar que el balance restante es correcto
//        assertEq(tokenA.balanceOf(trader2), 1000); // Verificar que el balance restante es correcto
//    }
//
//    function testAddBuyOrderWithMatchingDifferentSellOrder() public {
//        // Caso 2: Orden de compra con precio igual varias ordenes de compra
//
//        vm.startPrank(trader2);
//        orderBookImpl.addSellBaseToken(price, 5, trader2, nonce, expired);
//        vm.stopPrank();
//
//        vm.startPrank(trader2);
//        orderBookImpl.addSellBaseToken(price, 5, trader2, nonce + 1, expired);
//        vm.stopPrank();
//
//        vm.startPrank(trader2);
//        orderBookImpl.addSellBaseToken(price, 5, trader2, nonce + 2, expired);
//        vm.stopPrank();
//
//        //vm.prank(trader1);
//        vm.startPrank(trader1);
//        orderBookImpl.addBuyBaseToken(price, 15, trader1, nonce, expired);
//        vm.stopPrank();
//
//        assertEq(orderBookImpl.getFirstSellOrders(), 0, "La orden de venta debe haberse emparejado completamente");
//        assertEq(orderBookImpl.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
//        assertEq(tokenB.balanceOf(trader1), 15); // Verificar que el balance restante es correcto
//        assertEq(tokenA.balanceOf(trader2), 1500); // Verificar que el balance restante es correcto
//    }
//
//    //Prueba que una orden de compra con un precio mayor empareje y ejecute una orden de venta.
//    function testAddBuyOrderWithHigherPriceThanSellOrder() public {
//        // Caso 3: Orden de compra con precio mayor a una orden de venta
//        console.log("Balance T2_A INICIAL", tokenA.balanceOf(trader2));
//        console.log("Balance T2_B INICIAL", tokenB.balanceOf(trader2));
//
//        console.log("Balance Contract TA INICIAL", tokenA.balanceOf(address(orderBookImpl)));
//        console.log("Balance Contract TB INICIAL", tokenB.balanceOf(address(orderBookImpl)));
//
//        vm.prank(trader2);
//        orderBookImpl.addSellBaseToken(90, quantity, trader2, nonce, expired); //Vende tokenB por TokenA 10 tokens a 90
//
//        console.log("Balance T2_A ADD SELL", tokenA.balanceOf(trader2));
//        console.log("Balance T2_B ADD SELL", tokenB.balanceOf(trader2));
//
//        console.log("Balance Contract TA", tokenA.balanceOf(address(orderBookImpl)));
//        console.log("Balance Contract TB", tokenB.balanceOf(address(orderBookImpl)));
//
//        price = 100;
//        vm.prank(trader1);
//        orderBookImpl.addBuyBaseToken(price, quantity, trader1, nonce, expired); //Compra tokenB por tokenA 10 tokens a 100
//
//        console.log("Balance T2_A FIN", tokenA.balanceOf(trader2));
//        console.log("Balance T2_B FIN", tokenB.balanceOf(trader2));
//
//        console.log("Balance T1_A FIN", tokenA.balanceOf(trader1));
//        console.log("Balance T1_B FIN", tokenB.balanceOf(trader1));
//
//        assertEq(orderBookImpl.lastTradePrice(), 90, "El ultimo precio deberia ser 90");
//        assertEq(orderBookImpl.getFirstSellOrders(), 0, "La orden de venta debe haberse emparejado completamente");
//        assertEq(orderBookImpl.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
//        assertEq(tokenB.balanceOf(trader1), 10); // Verificar que el balance restante es correcto
//        assertEq(tokenA.balanceOf(trader2), 900); // Verificar que el balance restante es correcto
//    }
//
//    //Confirma que una orden de compra con un precio más bajo se almacena sin ejecutarse si no encuentra un match.
//    function testAddBuyOrderWithLowerPriceThanSellOrder() public {
//        // Caso 4: Orden de compra con precio menor que la orden de venta
//        vm.prank(trader2);
//        orderBookImpl.addSellBaseToken(110, quantity, trader2, nonce, expired);
//
//        console.log("Balance T2_A FIN", tokenA.balanceOf(trader2));
//        console.log("Balance T2_B FIN", tokenB.balanceOf(trader2));
//
//        console.log("Balance T1_A FIN", tokenA.balanceOf(trader1));
//        console.log("Balance T1_B FIN", tokenB.balanceOf(trader1));
//
//        vm.prank(trader1);
//        orderBookImpl.addBuyBaseToken(price, quantity, trader1, nonce, expired);
//
//        // Verificar que la orden de compra no se empareja y se almacena
//        assertEq(orderBookImpl.getFirstSellOrders(), 110, "La orden de venta no debe haberse emparejado");
//        assertEq(orderBookImpl.getFirstBuyOrders(), 100, "La orden de compra debe haberse almacenado");
//    }
//
//    //Asegura que una orden de compra parcial se almacene correctamente si la orden de venta tiene menor cantidad.
//    function testAddBuyOrderWithPartialQuantity() public {
//        // Caso 5: Orden de compra con cantidad parcial
//        vm.prank(trader2);
//        orderBookImpl.addSellBaseToken(price, 5, trader2, nonce, expired);
//        vm.prank(trader1);
//        orderBookImpl.addBuyBaseToken(price, quantity, trader1, nonce, expired);
//
//        // Verificar que la orden de compra se empareje parcialmente
//        assertEq(orderBookImpl.getFirstSellOrders(), 0, "La orden de venta debe haberse emparejado");
//        assertEq(
//            orderBookImpl.getFirstBuyOrders(), 100, "La cantidad restante de la orden de compra debe estar almacenada"
//        );
//        assertEq(tokenB.balanceOf(trader1), 5); // Verificar que el balance restante es correcto
//        assertEq(tokenA.balanceOf(trader2), 500); // Verificar que el balance restante es correcto
//    }
//
//    //Verifica que una orden de compra con exceso de cantidad se ejecute correctamente y que el remanente de la venta quede en el libro.
//    function testAddBuyOrderWithExcessQuantity() public {
//        // Caso 6: Orden de compra con exceso de cantidad
//        vm.prank(trader2);
//        orderBookImpl.addSellBaseToken(price, 15, trader2, nonce, expired); // Orden de venta con más cantidad
//
//        console.log("Balance T2_A FIN", tokenA.balanceOf(trader2));
//        console.log("Balance T2_B FIN", tokenB.balanceOf(trader2));
//
//        console.log("Balance T1_A FIN", tokenA.balanceOf(trader1));
//        console.log("Balance T1_B FIN", tokenB.balanceOf(trader1));
//
//        //vm.prank(trader1);
//        vm.startPrank(trader1);
//        orderBookImpl.addBuyBaseToken(price, quantity, trader1, nonce, expired);
//        vm.stopPrank();
//
//        // Verificar que la orden de venta se ejecute parcialmente
//        assertEq(orderBookImpl.getFirstSellOrders(), 100, "La orden de venta debe tener una cantidad restante");
//        assertEq(orderBookImpl.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
//        //assertEq(book.buyOrders[price].length, 0, "La orden de compra debe haberse ejecutado completamente");
//    }
//
//    //Asegura que una orden de compra se empareje con múltiples órdenes de venta a diferentes precios.
//    function testAddBuyOrderWithMultipleSellOrders() public {
//        // Caso 7: Orden de compra con varios matches de órdenes de venta
//        vm.startPrank(trader2);
//        orderBookImpl.addSellBaseToken(90, 5, trader2, nonce, expired); // Orden de venta con menor precio
//        orderBookImpl.addSellBaseToken(price, 5, trader2, nonce, expired); // Otra orden de venta con precio igual
//        vm.stopPrank();
//
//        vm.prank(trader1);
//        orderBookImpl.addBuyBaseToken(price, quantity, trader1, nonce, expired);
//
//        // Verificar que todas las órdenes de venta se hayan emparejado
//        assertEq(orderBookImpl.getFirstSellOrders(), 0, unicode"Todas las órdenes de venta deben haberse emparejado");
//        assertEq(orderBookImpl.getFirstBuyOrders(), 0, unicode"La orden de compra debe haberse ejecutado completamente");
//    }
//
//    /*//Valida que una orden expirada no se almacene y emita un error.
//    function testAddBuyOrderWithExpiredOrder() public {
//        // Caso 8: Orden de compra expirada
//        expired = block.timestamp - 1 days; // Orden expirada
//        vm.expectRevert("Order expired");
//        book.addBuyOrder(price, quantity, trader1, nonce, expired);
//    }
//
//    //Confirma que una orden con expiración cero no se almacena si no puede ejecutarse completamente.
//    function testAddBuyOrderWithFillOrKill() public {
//        // Caso 9: Orden de compra con expiración cero (Fill or Kill)
//        expired = 0; // Expiración cero significa fill or kill
//        book.addSellOrder(100, 5, trader2, nonce, expired);// Orden de venta con menor precio
//        book.addBuyOrder(price, quantity, trader1, nonce, expired);
//
//        // Verificar que la orden de compra no se almacene si no se puede ejecutar completamente
//        assertEq(book.buyOrders[price].length, 0, "La orden de compra no debe almacenarse si no se puede llenar completamente");
//    }*/
//
//    //-------------------- ADD SELL ORDER ------------------------------
//    //Árbol de órdenes de compra vacío: Prueba la inserción directa de una orden de venta cuando no hay órdenes de compra.
//    function testAddSellOrderWithoutBuyOrders() public {
//        // Inicialmente no hay órdenes de compra
//        assertEq(orderBookImpl.getLastBuyOrders(), 0, unicode"El árbol de órdenes de compra debe estar vacío");
//
//        // Agregar una orden de venta
//        uint256 price = 100;
//        uint256 quantity = 10;
//        console.log("Balance T2_A FIN", tokenA.balanceOf(trader2));
//        console.log("Balance T2_B FIN", tokenB.balanceOf(trader2));
//
//        console.log("Balance T1_A FIN", tokenA.balanceOf(trader1));
//        console.log("Balance T1_B FIN", tokenB.balanceOf(trader1));
//        vm.prank(trader2);
//        orderBookImpl.addSellBaseToken(price, quantity, trader2, nonce, expired);
//
//        // Verificar que la orden de venta se haya agregado al libro de órdenes de venta
//        assertEq(orderBookImpl.getFirstSellOrders(), 100, "La orden de venta debe haberse agregado correctamente");
//    }
//
//    function testAddSellOrderWithMatchingSellOrder() public {
//        // Caso 2: Orden de venta con precio igual a una orden de compra
//
//        vm.prank(trader1);
//        orderBookImpl.addBuyBaseToken(price, quantity, trader1, nonce, expired);
//
//        vm.startPrank(trader2);
//        orderBookImpl.addSellBaseToken(price, quantity, trader2, nonce, expired);
//        vm.stopPrank();
//
//        // Verificar que la orden de compra se haya emparejado y eliminado
//        assertEq(orderBookImpl.getFirstSellOrders(), 0, "La orden de venta debe haberse emparejado completamente");
//        assertEq(orderBookImpl.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
//        assertEq(tokenB.balanceOf(trader1), 1000); // Verificar que el balance restante es correcto
//        assertEq(tokenA.balanceOf(trader2), 10); // Verificar que el balance restante es correcto
//    }
//
//    function testAddSellOrderWithMatchingDifferentSellOrder() public {
//        // Caso 2: Orden de compra con precio igual varias ordenes de venta
//
//        vm.startPrank(trader1);
//        orderBookImpl.addBuyBaseToken(price, 5, trader1, nonce, expired);
//        orderBookImpl.addBuyBaseToken(price, 5, trader1, nonce + 1, expired);
//        orderBookImpl.addBuyBaseToken(price, 5, trader1, nonce + 2, expired);
//        vm.stopPrank();
//
//        vm.startPrank(trader2);
//        orderBookImpl.addSellBaseToken(price, 15, trader2, nonce, expired);
//        vm.stopPrank();
//
//        //vm.prank(trader1);
//
//        assertEq(orderBookImpl.getFirstSellOrders(), 0, "La orden de venta debe haberse emparejado completamente");
//        assertEq(orderBookImpl.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
//        assertEq(tokenB.balanceOf(trader1), 1500); // Verificar que el balance restante es correcto
//        assertEq(tokenA.balanceOf(trader2), 15); // Verificar que el balance restante es correcto
//    }
//
//    //Matching con precio de venta más bajo: Prueba la coincidencia de órdenes cuando el precio de venta es menor o igual al de compra.
//    function testAddSellOrderWithLowerPriceMatchingBuyOrder() public {
//        // Insertar una orden de compra con un precio más alto
//        vm.prank(trader1);
//        orderBookImpl.addBuyBaseToken(110, quantity, trader1, nonce, expired); // Orden de compra con un precio de 110
//
//        // Agregar una orden de venta con un precio más bajo (match)
//        uint256 price = 100;
//        uint256 quantity = 10;
//
//        vm.prank(trader2);
//        orderBookImpl.addSellBaseToken(price, quantity, trader2, nonce, expired);
//
//        // Verificar que la orden de compra se haya emparejado completamente
//        assertEq(orderBookImpl.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
//
//        // Verificar que no haya órdenes de venta pendientes a este precio
//        assertEq(
//            orderBookImpl.getFirstSellOrders(), 0, unicode"No debe haber órdenes de venta pendientes si se emparejaron"
//        );
//    }
//
//    //Sin matching con precio de venta más alto: Verifica que no se realice matching si el precio de venta es mayor al de compra.
//    function testAddSellOrderWithHigherPriceNoMatching() public {
//        // Insertar una orden de compra con un precio más bajo
//        vm.prank(trader1);
//        orderBookImpl.addBuyBaseToken(90, quantity, trader1, nonce, expired); // Orden de compra con precio de 90
//
//        // Agregar una orden de venta con un precio más alto (no match)
//        uint256 price = 100;
//        uint256 quantity = 10;
//        vm.prank(trader2);
//        orderBookImpl.addSellBaseToken(price, quantity, trader2, nonce, expired);
//
//        // Verificar que la orden de compra se haya emparejado completamente
//        assertEq(orderBookImpl.getFirstBuyOrders(), 90, "La orden de venta debe haberse agregado correctamente");
//
//        // Verificar que no haya órdenes de venta pendientes a este precio
//        assertEq(orderBookImpl.getFirstSellOrders(), 100, "La orden de compra no debe haberse ejecutado");
//    }
//
//    //Matching parcial: Prueba que las órdenes de venta se emparejen parcialmente y dejen una cantidad restante.
//    function testAddSellOrderWithPartialMatching() public {
//        // Insertar una orden de compra con un precio igual pero una cantidad menor
//
//        console.log("Balance T2_A INICIO 1", tokenA.balanceOf(trader2));
//        console.log("Balance T2_B INICIO 1", tokenB.balanceOf(trader2));
//
//        console.log("Balance T1_A INICIO 1", tokenA.balanceOf(trader1));
//        console.log("Balance T1_B INICIO 1", tokenB.balanceOf(trader1));
//
//        console.log("Balance Contract TA INICIAL 1", tokenA.balanceOf(address(orderBookImpl)));
//        console.log("Balance Contract TB INICIAL 1", tokenB.balanceOf(address(orderBookImpl)));
//
//        vm.prank(trader1);
//        orderBookImpl.addBuyBaseToken(price, 5, trader1, nonce, expired); // Orden de compra con precio 100 y cantidad 5
//
//        console.log("Balance T2_A INICIO", tokenA.balanceOf(trader2));
//        console.log("Balance T2_B INICIO", tokenB.balanceOf(trader2));
//
//        console.log("Balance T1_A INICIO", tokenA.balanceOf(trader1));
//        console.log("Balance T1_B INICIO", tokenB.balanceOf(trader1));
//
//        console.log("Balance Contract TA INICIAL", tokenA.balanceOf(address(orderBookImpl)));
//        console.log("Balance Contract TB INICIAL", tokenB.balanceOf(address(orderBookImpl)));
//
//        // Agregar una orden de venta con una cantidad mayor
//        //uint256 quantity = 10; // Orden de venta de cantidad 10
//
//        vm.prank(trader2);
//        orderBookImpl.addSellBaseToken(price, 10, trader2, nonce, expired);
//
//        // Verificar que la orden de compra se haya ejecutado completamente
//        assertEq(orderBookImpl.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
//
//        console.log("Balance T2_A FIN", tokenA.balanceOf(trader2));
//        console.log("Balance T2_B FIN", tokenB.balanceOf(trader2));
//
//        console.log("Balance T1_A FIN", tokenA.balanceOf(trader1));
//        console.log("Balance T1_B FIN", tokenB.balanceOf(trader1));
//
//        console.log("Balance Contract TA FIN", tokenA.balanceOf(address(orderBookImpl)));
//        console.log("Balance Contract TB FIN", tokenB.balanceOf(address(orderBookImpl)));
//
//        assertEq(orderBookImpl.getFirstSellOrders(), 100, "La orden de venta debe haberse emparejado completamente");
//        assertEq(orderBookImpl.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
//        assertEq(tokenB.balanceOf(trader1), 500); // Verificar que el balance restante es correcto
//        assertEq(tokenA.balanceOf(trader2), 5); // Verificar que el balance restante es correcto
//        assertEq(tokenB.balanceOf(address(orderBookImpl)), 500); // Verificar que el balance restante es correcto
//    }
//
//    //Límite de órdenes alcanzado: Prueba que el contrato maneje correctamente el límite de órdenes a procesar.
//    /*function testAddSellOrderOrderCountLimitReached() public {
//        // Insertar varias órdenes de compra para simular un gran número de coincidencias
//        for (uint256 i = 0; i < 150; i++) {
//            vm.prank(trader1);
//            book.buyOrders.insert(100 + i, 1); // Órdenes de compra con precios incrementales
//        }
//
//        // Agregar una orden de venta
//        uint256 price = 100;
//        uint256 quantity = 10;
//        book.addSellOrder(price, quantity, trader1, nonce, expired);
//
//        // Verificar que la orden de venta se haya guardado, ya que no se puede emparejar más de 150 órdenes
//        assertEq(book.sellOrders[price].length, 1, "La orden de venta debe haberse agregado correctamente después de alcanzar el límite");
//    }*/
//
//    //-------------------- CANCEL ORDER ------------------------------
//
//    //Cancelación exitosa de una orden de compra: Se verifica que la orden de compra es eliminada correctamente.
//    function testCancelBuyOrder() public {
//        // Insertar una orden de compra
//        vm.prank(trader1);
//        orderBookImpl.addBuyBaseToken(price, 5, trader1, nonce, expired); // Orden de compra con precio 100 y cantidad 5
//
//        bytes32 _orderId = keccak256(abi.encodePacked(trader1, "buy", price, nonce));
//
//        // Cancelar la orden de compra
//        vm.prank(trader1);
//        orderBookImpl.getCancelOrder(_orderId);
//
//        // Verificar que la orden haya sido eliminada del árbol de órdenes de compra
//        assertEq(orderBookImpl.getFirstBuyOrders(), 0, "La orden de compra debe haber sido eliminada");
//    }
//
//    //Cancelación exitosa de una orden de venta: Similar al caso anterior pero con órdenes de venta.
//    function testCancelSellOrder() public {
//        // Insertar una orden de venta
//        vm.prank(trader2);
//        orderBookImpl.addSellBaseToken(price, 10, trader2, nonce, expired);
//
//        bytes32 _orderId = keccak256(abi.encodePacked(trader2, "sell", price, nonce));
//
//        // Cancelar la orden de venta
//        vm.prank(trader2);
//        orderBookImpl.getCancelOrder(_orderId);
//
//        // Verificar que la orden haya sido eliminada del árbol de órdenes de venta
//        //assertEq(book.sellOrders[100].length, 0, "La orden de venta debe haber sido eliminada");
//        assertEq(orderBookImpl.getFirstSellOrders(), 0, "La orden de venta debe haber sido eliminada");
//    }
//
//    //Intento de cancelación de una orden inexistente: Asegura que no ocurre ninguna acción cuando se intenta cancelar una orden inexistente.
//    function testCancelNonExistentOrder() public {
//        // Intentar cancelar una orden que no existe
//        bytes32 _orderId = keccak256(abi.encodePacked(trader1, "buy", price, nonce));
//
//        // Intentar cancelar la orden inexistente
//        vm.expectRevert(RedBlackTree.RedBlackTree__ValueCannotBeZero.selector);
//        orderBookImpl.getCancelOrder(_orderId);
//    }
//
//    //Cancelación de una orden entre múltiples órdenes: Verifica que el array de órdenes del trader se reordene correctamente.
//    function testCancelOrderAmongMultipleOrders() public {
//        // Insertar varias órdenes de compra
//        vm.startPrank(trader1);
//        orderBookImpl.addBuyBaseToken(price, 10, trader1, nonce, expired); // Orden de compra con precio 100 y cantidad 5
//        orderBookImpl.addBuyBaseToken(price, 5, trader1, nonce + 1, expired); // Orden de compra con precio 100 y cantidad 5
//        vm.stopPrank();
//
//        bytes32 _orderId1 = keccak256(abi.encodePacked(trader1, "buy", price, nonce));
//        bytes32 _orderId2 = keccak256(abi.encodePacked(trader1, "buy", price, nonce + 1));
//
//        // Cancelar la primera orden
//        //console.logBytes32(orderBookImpl.getFirstOrderBuyById(price));
//        assertEq(orderBookImpl.getFirstOrderBuyById(price), _orderId1, "La primera orden debe ser orderId1");
//
//        vm.prank(trader1);
//        orderBookImpl.getCancelOrder(_orderId1);
//
//        //console.logBytes32(_orderId2);
//        //console.logBytes32(orderBookImpl.getFirstOrderBuyById(price));
//
//        // Verificar que la segunda orden se haya movido a la primera posición
//        assertEq(
//            orderBookImpl.getFirstOrderBuyById(price),
//            _orderId2,
//            unicode"La segunda orden debe haberse movido a la primera posición"
//        );
//    }
//
//    //Cancelación de una orden que no pertenece al msg.sender: Asegura que un usuario no puede cancelar una orden que no le pertenece.
//    function testCancelOrderNotOwner() public {
//        // Insertar una orden de compra para trader1
//        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", price, nonce));
//
//        vm.startPrank(trader1);
//        orderBookImpl.addBuyBaseToken(price, 10, trader1, nonce, expired); // Orden de compra con precio 100 y cantidad 5
//        vm.stopPrank();
//
//        // Intentar cancelar la orden desde otro trader
//        //vm.expectRevert("Order not found");
//        vm.prank(trader2);
//        vm.expectRevert(RedBlackTree.RedBlackTree__ValueCannotBeZero.selector);
//        orderBookImpl.getCancelOrder(orderId);
//
//        // Verificar que la orden no fue cancelada
//        //assertEq(book.buyOrders[100].length, 1, "La orden de compra no debe haber sido eliminada");
//    }
//
//    //-------------------- GET TRADER ORDER ------------------------------
//    //Obtener órdenes de un trader con varias órdenes: Verifica que todas las órdenes del trader se devuelven correctamente.
//    function testGetTraderOrdersWithMultipleOrders() public {
//        // Insertar varias órdenes para trader1
//        bytes32 orderId1 = keccak256(abi.encodePacked(trader1, "buy", price, nonce));
//        bytes32 orderId2 = keccak256(abi.encodePacked(trader1, "buy", price, nonce + 1));
//
//        vm.startPrank(trader1);
//        orderBookImpl.addBuyBaseToken(price, 100, trader1, nonce, expired); // Orden de compra con precio 100 y cantidad 5
//        orderBookImpl.addBuyBaseToken(price, 200, trader1, nonce + 1, expired); // Orden de compra con precio 100 y cantidad 5
//        vm.stopPrank();
//
//        // Obtener las órdenes
//        bytes32[] memory orders = orderBookImpl.getTraderOrders(trader1);
//
//        // Verificar que se devuelven las órdenes correctas
//        assertEq(orders.length, 2, unicode"Debe devolver dos órdenes");
//        assertEq(orders[0], orderId1, "La primera orden debe coincidir");
//        assertEq(orders[1], orderId2, "La segunda orden debe coincidir");
//    }
//
//    //Obtener órdenes de un trader sin órdenes: Asegura que se devuelva un array vacío si el trader no tiene órdenes.
//    function testGetTraderOrdersWithNoOrders() public {
//        // Verificar que trader2 no tiene órdenes
//        bytes32[] memory orders = orderBookImpl.getTraderOrders(trader2);
//
//        // Verificar que se devuelva un array vacío
//        assertEq(orders.length, 0, unicode"Debe devolver un array vacío si el trader no tiene órdenes");
//    }
//
//    //Obtener órdenes de un trader con solo una orden: Prueba que, si solo hay una orden, esta se devuelva correctamente.
//    function testGetTraderOrdersWithSingleOrder() public {
//        // Insertar una única orden para trader1
//        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", price, nonce));
//        vm.startPrank(trader1);
//        orderBookImpl.addBuyBaseToken(price, 100, trader1, nonce, expired); // Orden de compra con precio 100 y cantidad 5
//        vm.stopPrank();
//
//        // Obtener las órdenes
//        bytes32[] memory orders = orderBookImpl.getTraderOrders(trader1);
//
//        // Verificar que se devuelve una sola orden
//        assertEq(orders.length, 1, unicode"Debe devolver una única orden");
//        assertEq(orders[0], orderId, "La orden devuelta debe coincidir");
//    }
//
//    //Obtener órdenes de un trader inexistente: Confirma que un trader que nunca ha tenido órdenes devuelve un array vacío.
//    function testGetTraderOrdersForNonExistentTrader() public {
//        // Obtener las órdenes para un trader inexistente (que nunca ha tenido órdenes)
//        bytes32[] memory orders = orderBookImpl.getTraderOrders(address(0x1234));
//
//        // Verificar que se devuelva un array vacío
//        assertEq(orders.length, 0, unicode"Debe devolver un array vacío si el trader no existe");
//    }
//
//    //Verificar la inmutabilidad del array devuelto: Asegura que el array devuelto es una copia y no puede ser modificado directamente.
//    function testImmutabilityOfReturnedArray() public {
//        // Insertar una orden para trader1
//        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", price, nonce));
//        vm.startPrank(trader1);
//        orderBookImpl.addBuyBaseToken(price, 100, trader1, nonce, expired); // Orden de compra con precio 100 y cantidad 5
//        vm.stopPrank();
//        // Obtener las órdenes
//        bytes32[] memory orders = orderBookImpl.getTraderOrders(trader1);
//
//        // Intentar modificar el array devuelto
//        orders[0] = keccak256(abi.encodePacked(trader1, "sell", price + 100, nonce + 1));
//
//        // Volver a obtener las órdenes del storage
//        bytes32[] memory ordersAfterModification = orderBookImpl.getTraderOrders(trader1);
//
//        // Verificar que la modificación no afectó el almacenamiento original
//        assertEq(ordersAfterModification[0], orderId, unicode"El array devuelto no debe modificar el estado original");
//    }
//
//    //-------------------- GET ORDER BY ID ------------------------------
//
//    //Recuperar una orden de compra existente: Verifica que la función devuelve los detalles correctos de una orden de compra.
//    function testGetBuyOrderById() public {
//        // Crear una orden de compra para trader1
//        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", price, nonce));
//
//        vm.startPrank(trader1);
//        orderBookImpl.addBuyBaseToken(price, quantity, trader1, nonce, expired); // Orden de compra con precio 100 y cantidad 5
//        vm.stopPrank();
//
//        // Obtener la orden por su ID
//        OrderQueue.OrderBookNode memory result = orderBookImpl.getOrderById(trader1, orderId);
//
//        // Verificar los detalles de la orden devuelta
//        assertEq(result.price, price, "El precio de la orden debe ser 100");
//        assertEq(result.quantity, quantity, "La cantidad de la orden debe ser 10");
//    }
//
//    //Recuperar una orden de venta existente: Asegura que la función devuelve los detalles correctos de una orden de venta.
//    function testGetSellOrderById() public {
//        // Crear una orden de venta para trader1
//        bytes32 orderId = keccak256(abi.encodePacked(trader2, "sell", price, nonce));
//
//        // Insertar una orden de venta
//        vm.prank(trader2);
//        orderBookImpl.addSellBaseToken(price, 10, trader2, nonce, expired);
//
//        // Obtener la orden por su ID
//        OrderQueue.OrderBookNode memory result = orderBookImpl.getOrderById(trader2, orderId);
//
//        // Verificar los detalles de la orden devuelta
//        assertEq(result.price, price, "El precio de la orden debe ser 100");
//        assertEq(result.quantity, 10, "La cantidad de la orden debe ser 10");
//    }
//
//    //Intentar recuperar una orden inexistente: Confirma que la función maneja correctamente órdenes inexistentes (usualmente con revert).
//    function testGetNonExistentOrderById() public {
//        // Crear un ID de orden que no exista
//        bytes32 orderId = keccak256(abi.encodePacked(trader1, "buy", price, nonce));
//
//        // Intentar obtener la orden inexistente
//        vm.expectRevert(RedBlackTree.RedBlackTree__ValuesDoesNotExist.selector);
//        orderBookImpl.getOrderById(trader1, orderId);
//    }
//
//    //Recuperar una orden con un orderId inválido: Asegura que la función no devuelve detalles de órdenes con IDs inválidos.
//    function testGetOrderWithInvalidId() public {
//        // Usar un `orderId` inválido (que no existe)
//        bytes32 invalidOrderId = keccak256(abi.encodePacked(trader1, "invalid", price, nonce));
//
//        vm.startPrank(trader1);
//        orderBookImpl.addBuyBaseToken(price, quantity, trader1, nonce, expired); // Orden de compra con precio 100 y cantidad 5
//        vm.stopPrank();
//
//        // Intentar obtener la orden inválida
//        vm.expectRevert(); // Espera que la operación falle
//        orderBookImpl.getOrderById(trader1, invalidOrderId);
//    }
//
//    //Recuperar una orden de un trader sin órdenes: Verifica que la función maneje correctamente cuando un trader no tiene órdenes.
//    function testGetOrderForTraderWithoutOrders() public {
//        // Intentar obtener una orden para un trader que no tiene órdenes
//        bytes32 orderId = keccak256(abi.encodePacked(trader2, "buy", price, quantity));
//
//        vm.startPrank(trader1);
//        orderBookImpl.addBuyBaseToken(price, quantity, trader1, nonce, expired); // Orden de compra con precio 100 y cantidad 5
//        vm.stopPrank();
//
//        // Verificar que se revertirá la transacción ya que trader2 no tiene órdenes
//        vm.expectRevert(); // Espera que la operación falle
//        orderBookImpl.getOrderById(trader2, orderId);
//    }
//}
