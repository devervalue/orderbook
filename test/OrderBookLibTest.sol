// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/OrderQueue.sol";
import "../src/RedBlackTree.sol";
import "../src/OrderBookLib.sol";
import "forge-std/console.sol";
import "../src/MyToken.sol";


contract OrderBookLibTest is Test {
    using OrderBookLib for OrderBookLib.OrderBook;
    using RedBlackTree for RedBlackTree.Tree;
    MyToken token;
    OrderBookLib.OrderBook private book;
    address public libraryAddress;
    address trader1 = address(0x1);
    address trader2 = address(0x2);
    address trader3 = address(0x3);

    uint256 price;
    uint256 quantity;
    uint256 nonce;
    uint256 expired;

    function setUp() public {
        libraryAddress = deployCode("OrderBookLib.sol");
        console.log("add",libraryAddress);
        // Configuración básica antes de cada prueba
        token = new MyToken(1000 * 10 ** 18); //Crear un nuevo token con suministro inicial
        //token.approve(msg.sender, 1000 * 10 ** 18);
        token.transfer(trader1,200 * 10 ** 18); //Doy fondos a trader 1
        //token.approve(trader1, 1000 * 10 ** 18);

        price = 100;
        quantity = 10;
        nonce = 1;
        expired = block.timestamp + 1 days;
        book.baseToken = address(token);
        book.quoteToken = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        book.lastTradePrice = 0;
        book.status = true;
        book.owner = address(0x6);
        book.fee = 0x0;
        book.feeAddress = address(0x7);

        // Aprobar el contrato para que pueda gastar tokens de trader1
        vm.prank(trader1); // Cambiar el contexto a trader1
        token.approve(trader1, 1000 * 10 ** 18); // Aprobar 1000 tokens

    }



    //-------------------- ADD BUY ORDER ------------------------------
    //Valida que si no hay órdenes de venta, la orden de compra se almacena en el libro.
    function testAddBuyOrderWithoutSellOrders() public {
        // Caso 1: Orden de compra sin órdenes de venta
        //token.transferFrom(trader1, 100 * 10 ** 18);
        uint256 balanceContractInitial = token.balanceOf(address(this));

        vm.prank(trader1);
        book.addBuyOrder(price, quantity, trader1, nonce, expired);

        uint256 balanceContract = token.balanceOf(address(this));
        assertEq(balanceContract - balanceContractInitial, 10); // Verificar que el balance restante es correcto
            //assertEq(book.sellOrders.first(), 100, "La orden de compra debe estar almacenada");
    }

    /*//Verifica que una orden de compra se ejecute completamente si encuentra una orden de venta con el mismo precio.
    function testAddBuyOrderWithMatchingSellOrder() public {
        // Caso 2: Orden de compra con precio igual a una orden de venta
        book.addSellOrder(price, quantity, trader2, nonce, expired);
        book.addBuyOrder(price, quantity, trader1, nonce, expired);

        // Verificar que la orden de compra se haya emparejado y eliminado
        assertEq(book.sellOrders.first(), 0, "La orden de venta debe haberse emparejado completamente");
        assertEq(book.buyOrders.first(), 0, "La orden de compra debe haberse ejecutado completamente");
    }

    //Prueba que una orden de compra con un precio mayor empareje y ejecute una orden de venta.
    function testAddBuyOrderWithHigherPriceThanSellOrder() public {
        // Caso 3: Orden de compra con precio mayor a una orden de venta
        book.addSellOrder(90, quantity, trader2, nonce, expired);
        price = 100;
        book.addBuyOrder(price, quantity, trader1, nonce, expired);

        // Verificar que la orden de compra se haya ejecutado parcialmente o completamente
        assertEq(book.sellOrders.first(), 0, "La orden de venta debe haberse emparejado");
        assertEq(book.buyOrders.first(), 0, "La orden de compra debe haberse ejecutado completamente");
    }

    //Confirma que una orden de compra con un precio más bajo se almacena sin ejecutarse si no encuentra un match.
    function testAddBuyOrderWithLowerPriceThanSellOrder() public {
        // Caso 4: Orden de compra con precio menor que la orden de venta
        book.addSellOrder(110, quantity, trader2, nonce, expired);
        book.addBuyOrder(price, quantity, trader1, nonce, expired);

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
