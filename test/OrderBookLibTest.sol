// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/OrderQueue.sol";
import "../src/RedBlackTree.sol";
import "../src/OrderBookLib.sol";
import "forge-std/console.sol";
import "../src/MyTokenA.sol";
import "../src/MyTokenB.sol";

import "./OrderBookImpl.sol";

contract OrderBookLibTest is Test {
    // using OrderBookLib for OrderBookLib.OrderBook;
    // using RedBlackTree for RedBlackTree.Tree;

    //OrderBookLib.OrderBook private book;

    OrderBookImpl private orderBookImpl;

    //TOKENS
    MyTokenA tokenA;
    MyTokenB tokenB;

    //ADDRESS
    address addressContract;
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

        orderBookImpl = new OrderBookImpl(address(tokenA), address(tokenB));
        console.log("addressContract", address(orderBookImpl));
        console.log("address this", address(this));
        //Enviando fondos a los traders
        //token.approve(msg.sender, 1000 * 10 ** 18);
        //tokenA.transfer(trader1,200 * 10 ** 18); //Doy fondos a trader 1
        //tokenA.transfer(trader2,200 * 10 ** 18); //Doy fondos a trader 2
        tokenA.transfer(trader1, 1500);
        //tokenA.transfer(address(this),1); //Doy fondos a trader 2

        //tokenB.transfer(trader1,200 * 10 ** 18); //Doy fondos a trader 1
        tokenB.transfer(trader2, 15);
        //tokenB.transfer(address(this),1); //Doy fondos a trader 2
        //tokenB.transfer(trader2,200 * 10 ** 18); //Doy fondos a trader 2

        //token.approve(trader1, 1000 * 10 ** 18);

        //Creando orderBook
        price = 100;
        quantity = 10;
        nonce = 1;
        expired = block.timestamp + 1 days;

        //Aprobar el contrato para que pueda gastar tokens
        vm.startPrank(trader1); // Cambiar el contexto a trader1
        tokenA.approve(address(orderBookImpl), 1000 * 10 ** 18); // Aprobar 1000 tokens
        vm.stopPrank();

        vm.startPrank(trader2); // Cambiar el contexto a trader1
        tokenB.approve(address(orderBookImpl), 1000 * 10 ** 18); // Aprobar 1000 tokens
        vm.stopPrank();

        vm.startPrank(address(orderBookImpl)); // Cambiar el contexto a trader1
        tokenB.approve(address(orderBookImpl), 1000 * 10 ** 18); // Aprobar 1000 tokens
        tokenA.approve(address(orderBookImpl), 1000 * 10 ** 18); // Aprobar 1000 tokens
        vm.stopPrank();
    }

    //-------------------- ADD BUY ORDER ------------------------------
    //Valida que si no hay órdenes de venta, la orden de compra se almacena en el libro.
    function testAddBuyOrderWithoutSellOrders() public {
        // Caso 1: Orden de compra sin órdenes de venta
        uint256 balanceContractInitial = tokenA.balanceOf(address(orderBookImpl));

        vm.startPrank(trader1);
        orderBookImpl.addBuyOrder(price, quantity, trader1, nonce, expired);
        vm.stopPrank();

        uint256 balanceContract = tokenA.balanceOf(address(orderBookImpl));
        assertEq(balanceContract - balanceContractInitial, 10); // Verificar que el balance restante es correcto
        assertEq(orderBookImpl.getFirstBuyOrders(), 100, "La orden de compra debe estar almacenada");
    }

    //Verifica que una orden de compra se ejecute completamente si encuentra una orden de venta con el mismo precio.
    function testAddBuyOrderWithMatchingSellOrder() public {
        // Caso 2: Orden de compra con precio igual a una orden de venta

        vm.startPrank(trader2);
        orderBookImpl.addSellOrder(price, quantity, trader2, nonce, expired);
        vm.stopPrank();

        vm.prank(trader1);
        orderBookImpl.addBuyOrder(price, quantity, trader1, nonce, expired);

        // Verificar que la orden de compra se haya emparejado y eliminado
        assertEq(orderBookImpl.getFirstSellOrders(), 0, "La orden de venta debe haberse emparejado completamente");
        assertEq(orderBookImpl.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
        assertEq(tokenB.balanceOf(trader1), 10); // Verificar que el balance restante es correcto
        assertEq(tokenA.balanceOf(trader2), 1000); // Verificar que el balance restante es correcto

    }

    function testAddBuyOrderWithMatchingDifferentSellOrder() public {
        // Caso 2: Orden de compra con precio igual varias ordenes de compra

        vm.startPrank(trader2);
        orderBookImpl.addSellOrder(price, 5, trader2, nonce, expired);
        vm.stopPrank();

        vm.startPrank(trader2);
        orderBookImpl.addSellOrder(price, 5, trader2, nonce + 1, expired);
        vm.stopPrank();

        vm.startPrank(trader2);
        orderBookImpl.addSellOrder(price, 5, trader2, nonce + 2, expired);
        vm.stopPrank();

        //vm.prank(trader1);
        vm.startPrank(trader1);
        orderBookImpl.addBuyOrder(price, 15, trader1, nonce, expired);
        vm.stopPrank();

        assertEq(orderBookImpl.getFirstSellOrders(), 0, "La orden de venta debe haberse emparejado completamente");
        assertEq(orderBookImpl.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
        assertEq(tokenB.balanceOf(trader1), 15); // Verificar que el balance restante es correcto
        assertEq(tokenA.balanceOf(trader2), 1500); // Verificar que el balance restante es correcto
    }

    //Prueba que una orden de compra con un precio mayor empareje y ejecute una orden de venta.
    function testAddBuyOrderWithHigherPriceThanSellOrder() public {
        // Caso 3: Orden de compra con precio mayor a una orden de venta
        console.log("Balance T2_A INICIAL",tokenA.balanceOf(trader2));
        console.log("Balance T2_B INICIAL",tokenB.balanceOf(trader2));

        console.log("Balance Contract TA INICIAL",tokenA.balanceOf(address(this)));
        console.log("Balance Contract TB INICIAL",tokenB.balanceOf(address(this)));

        vm.prank(trader2);
        orderBookImpl.addSellOrder(90, quantity, trader2, nonce, expired); //Vende tokenB por TokenA 100 tokens a 90

        console.log("Balance T2_A ADD SELL",tokenA.balanceOf(trader2));
        console.log("Balance T2_B ADD SELL",tokenB.balanceOf(trader2));

        console.log("Balance Contract TA",tokenA.balanceOf(address(this)));
        console.log("Balance Contract TB",tokenB.balanceOf(address(this)));

        price = 100;
        vm.prank(trader1);
        orderBookImpl.addBuyOrder(price, quantity, trader1, nonce, expired); //Compra tokenB por tokenA 100 tokens a 100

        console.log("Balance T2_A FIN", tokenA.balanceOf(trader2));
        console.log("Balance T2_B FIN", tokenB.balanceOf(trader2));

        console.log("Balance T1_A FIN", tokenA.balanceOf(trader1));
        console.log("Balance T1_B FIN", tokenB.balanceOf(trader1));

        assertEq(orderBookImpl.getFirstSellOrders(), 0, "La orden de venta debe haberse emparejado completamente");
        assertEq(orderBookImpl.getFirstBuyOrders(), 0, "La orden de compra debe haberse ejecutado completamente");
        assertEq(tokenB.balanceOf(trader1), 10); // Verificar que el balance restante es correcto
        assertEq(tokenA.balanceOf(trader2), 900); // Verificar que el balance restante es correcto
    }

    //Confirma que una orden de compra con un precio más bajo se almacena sin ejecutarse si no encuentra un match.
    /*function testAddBuyOrderWithLowerPriceThanSellOrder() public {
        // Caso 4: Orden de compra con precio menor que la orden de venta
        vm.prank(trader2);
        orderBookImpl.addSellOrder(110, quantity, trader2, nonce, expired);
        vm.prank(trader1);
        orderBookImpl.addBuyOrder(price, quantity, trader1, nonce, expired);

        // Verificar que la orden de compra no se empareja y se almacena
        assertEq(book.sellOrders.first(), 110, "La orden de venta no debe haberse emparejado");
        assertEq(book.buyOrders.first(), 100, "La orden de compra debe haberse almacenado");
    }*/

    /*//Asegura que una orden de compra parcial se almacene correctamente si la orden de venta tiene menor cantidad.
    function testAddBuyOrderWithPartialQuantity() public {
        // Caso 5: Orden de compra con cantidad parcial
        book.addSellOrder(price, 5, trader2, nonce, expired);
        book.addBuyOrder(price, quantity, trader1, nonce, expired);

        // Verificar que la orden de compra se empareje parcialmente
        assertEq(book.sellOrders.first(), 0, "La orden de venta debe haberse emparejado");
        assertEq(book.buyOrders.first(), 100, "La cantidad restante de la orden de compra debe estar almacenada");

    }

    //Verifica que una orden de compra con exceso de cantidad se ejecute correctamente y que el remanente de la venta quede en el libro.
    function testAddBuyOrderWithExcessQuantity() public {
        // Caso 6: Orden de compra con exceso de cantidad
        book.addSellOrder(price, 15, trader2, nonce, expired); // Orden de venta con más cantidad
        book.addBuyOrder(price, quantity, trader1, nonce, expired);

        // Verificar que la orden de venta se ejecute parcialmente
        assertEq(book.sellOrders.first(), 100, "La orden de venta debe tener una cantidad restante");
        assertEq(book.buyOrders[price].length, 0, "La orden de compra debe haberse ejecutado completamente");
    }

    //Asegura que una orden de compra se empareje con múltiples órdenes de venta a diferentes precios.
    function testAddBuyOrderWithMultipleSellOrders() public {
        // Caso 7: Orden de compra con varios matches de órdenes de venta
        book.addSellOrder(90, 5, trader2, nonce, expired); // Orden de venta con menor precio
        book.addSellOrder(price, 5, trader2, nonce, expired); // Otra orden de venta con precio igual

        book.addBuyOrder(price, quantity, trader1, nonce, expired);

        // Verificar que todas las órdenes de venta se hayan emparejado
        assertEq(book.sellOrders.first(), 0, unicode"Todas las órdenes de venta deben haberse emparejado");
        assertEq(book.buyOrders[price].length, 0, unicode"La orden de compra debe haberse ejecutado completamente");
    }

    //Valida que una orden expirada no se almacene y emita un error.
    function testAddBuyOrderWithExpiredOrder() public {
        // Caso 8: Orden de compra expirada
        expired = block.timestamp - 1 days; // Orden expirada
        vm.expectRevert("Order expired");
        book.addBuyOrder(price, quantity, trader1, nonce, expired);
    }

    //Confirma que una orden con expiración cero no se almacena si no puede ejecutarse completamente.
    function testAddBuyOrderWithFillOrKill() public {
        // Caso 9: Orden de compra con expiración cero (Fill or Kill)
        expired = 0; // Expiración cero significa fill or kill
        book.addSellOrder(100, 5, trader2, nonce, expired);// Orden de venta con menor precio
        book.addBuyOrder(price, quantity, trader1, nonce, expired);

        // Verificar que la orden de compra no se almacene si no se puede ejecutar completamente
        assertEq(book.buyOrders[price].length, 0, "La orden de compra no debe almacenarse si no se puede llenar completamente");
    }*/
}
