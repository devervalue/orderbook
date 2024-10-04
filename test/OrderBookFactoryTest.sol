// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/OrderBookFactory.sol";
import "../src/MyTokenB.sol";
import "../src/MyTokenA.sol";
import "forge-std/console.sol";

contract OrderBookFactoryTest is Test {
    OrderBookFactory factory;

    //ADDRESS
    address owner = makeAddr("owner");
    address feeAddress = makeAddr("feeAddress");
    address trader1 = makeAddr("trader1");
    address trader2 = makeAddr("trader2");
    address trader3 = makeAddr("trader3");

    //TOKENS
    MyTokenA tokenA;
    MyTokenB tokenB;

    event OrderBookCreated(bytes32 indexed id, address indexed baseToken, address indexed quoteToken, address owner);

    event OrderBookFeeChanged(bytes32 indexed id, uint256 fee);

    event OrderBookFeeAddressChanged(bytes32 indexed id, address feeAddress);


    function setUp() public {
        factory = new OrderBookFactory();
        console.log(address(factory));
        console.log(msg.sender);
        //factory.owner = msg.sender;
        vm.prank(address(factory));
        factory.setOwner(owner);

        //Creando token como suministro inicial
        tokenA = new MyTokenA(1000 * 10 ** 18); //Crear un nuevo token con suministro inicial
        tokenB = new MyTokenB(1000 * 10 ** 18); //Crear un nuevo token con suministro inicial
//        console.log(address(factory));
//        console.log(msg.sender);
        tokenA.transfer(trader1, 1500);
        tokenB.transfer(trader2, 1500);

        //Aprobar el contrato para que pueda gastar tokens
        vm.startPrank(trader1); // Cambiar el contexto a trader1
        tokenA.approve(address(factory), 1000 * 10 ** 18); // Aprobar 1000 tokens
        vm.stopPrank();

        vm.startPrank(trader2); // Cambiar el contexto a trader1
        tokenB.approve(address(factory), 1000 * 10 ** 18); // Aprobar 1000 tokens
        vm.stopPrank();

        vm.startPrank(address(factory)); // Cambiar el contexto a trader1
        tokenB.approve(address(factory), 1000 * 10 ** 18); // Aprobar 1000 tokens
        tokenA.approve(address(factory), 1000 * 10 ** 18); // Aprobar 1000 tokens
        vm.stopPrank();
    }

    //-------------------- ADD ORDER BOOK ------------------------------

    //Verifica que se pueda añadir correctamente un nuevo libro de órdenes y que emita el evento OrderBookCreated con los parámetros esperados.
    function testAddOrderBookSuccess() public {
         vm.prank(owner);
         bytes32 expectedId = keccak256(abi.encodePacked(address(tokenA), address(tokenB)));

        //vm.expectEmit(true, true, true, true);
        //emit OrderBookCreated(expectedId, address(tokenA), address(tokenB), owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 5, feeAddress);

        bytes32[] memory keys = factory.getKeysOrderBooks();
        assertEq(keys.length, 1);

        (address baseToken, address quoteToken,,,) = factory.getOrderBookById(keys[0]);
        console.log(baseToken);
        console.log(quoteToken);
        assertEq(baseToken, address(tokenB)); //TODO REVISAR PQ LOS INVIERTE
        assertEq(quoteToken, address(tokenA));
    }

    //Verifica que se revierte si el _baseToken es la dirección cero (address(0)).
    function testRevertIfBaseTokenIsZero() public {
        vm.prank(owner);
        vm.expectRevert(OrderBookFactory.OrderBookFactory__InvalidTokenAddress.selector);
        factory.addOrderBook(address(0), address(tokenB), 5, feeAddress);
    }

    //Verifica que se revierte si el _quoteToken es la dirección cero (address(0)).
    function testRevertIfQuoteTokenIsZero() public {
        vm.prank(owner);
        vm.expectRevert(OrderBookFactory.OrderBookFactory__InvalidTokenAddress.selector);
        factory.addOrderBook(address(tokenA),address(0), 5, feeAddress);
    }

    //Prueba que se revierte si el propietario es la dirección cero, simulando un cambio inválido de propietario.
    function testRevertIfOwnerAddressIsZero() public {
        vm.prank(owner);
        vm.expectRevert(OrderBookFactory.OrderBookFactory__InvalidOwnerAddressZero.selector);
        factory.setOwner(address(0));

        //vm.prank(owner);
        //vm.expectRevert(OrderBookFactory.OrderBookFactory__InvalidOwnerAddress.selector);
        //factory.addOrderBook(address(tokenA), address(tokenB), 5, feeAddress);
    }

    //Verifica que se revierte si los tokens base y de cotización son iguales.
    function testRevertIfTokensAreEqual() public {
        vm.prank(owner);
        vm.expectRevert(OrderBookFactory.OrderBookFactory__TokenMustBeDifferent.selector);
        factory.addOrderBook(address(tokenA), address(tokenA), 5, feeAddress);
    }

    //Verifica que se revierte si la dirección de la tarifa es la dirección cero.
    function testRevertIfFeeAddressIsZero() public {
        vm.prank(owner);
        vm.expectRevert(OrderBookFactory.OrderBookFactory__InvalidFeeAddress.selector);
        factory.addOrderBook(address(tokenA), address(tokenB), 5, address(0));
    }

    //Verifica que el orden de los tokens esté correctamente gestionado dentro de la función, asegurando que el token de menor valor de dirección sea el baseToken.
    function testTokenOrderCorrectness() public {
        vm.prank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 5, feeAddress);
        bytes32[] memory keys = factory.getKeysOrderBooks();

        (address baseToken, address quoteToken,,,) = factory.getOrderBookById(keys[0]);
        assertEq(baseToken, address(tokenB)); // addr1 should be baseToken since it's lower in address value
        assertEq(quoteToken, address(tokenA));
    }

    //Verifica que se revierte la transacción si alguien que no es el propietario intenta agregar un libro de órdenes.
    function testRevertIfAddOrderBookCalledByNonOwner() public {
        vm.prank(trader1); // Simula que un usuario que no es el propietario llama a la función
        vm.expectRevert(OrderBookFactory.OrderBookFactory__InvalidOwnerAddress.selector);
        factory.addOrderBook(address(tokenA), address(tokenB), 5, feeAddress);
    }

    //Comprueba que se puedan agregar múltiples libros de órdenes de forma exitosa y que los identificadores sean únicos.
    function testAddMultipleOrderBooks() public {
        vm.prank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 5, feeAddress);
        vm.prank(owner);
        factory.addOrderBook(trader1, trader2, 10, feeAddress);

        bytes32[] memory keys = factory.getKeysOrderBooks();
        assertEq(keys.length, 2); // Se deberían agregar 2 libros de órdenes
    }

//Asegura que se revierte la transacción si se intenta agregar un libro de órdenes que ya existe.
    function testRevertIfAddingDuplicateOrderBook() public {
        vm.prank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 5, feeAddress); // Agregar primer libro de órdenes

        vm.expectRevert(); // Esperamos que la siguiente llamada revierta
        factory.addOrderBook(address(tokenA), address(tokenB), 5, feeAddress); // Intentar agregar el mismo libro de órdenes
    }

    //Verifica que un nuevo propietario pueda agregar un libro de órdenes después de que se haya cambiado el propietario.
    function testSetOwnerAndAddOrderBook() public {
        address newOwner = address(5);

        // Cambiamos el propietario
        vm.prank(owner);
        factory.setOwner(newOwner);

        vm.prank(newOwner); // Ahora simulamos que el nuevo propietario llama a la función
        factory.addOrderBook(address(tokenA), address(tokenB), 5, feeAddress);

        bytes32[] memory keys = factory.getKeysOrderBooks();
        assertEq(keys.length, 1); // Verificamos que el nuevo libro de órdenes se agregó
    }

    //Comprueba que se puedan agregar libros de órdenes con diferentes valores de tarifas y que estas se almacenen correctamente.
    function testAddOrderBookWithDifferentFeeValues() public {
        vm.prank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 5, feeAddress); // Primer libro de órdenes
        vm.prank(owner);
        factory.addOrderBook(trader1, trader2, 15, feeAddress); // Segundo libro de órdenes

        bytes32[] memory keys = factory.getKeysOrderBooks();
        assertEq(keys.length, 2); // Verificamos que se hayan agregado dos libros de órdenes

        (address _baseToken1,address _quoteToken1, bool _status1, uint256 lastTradePrice1, uint256 fee1) = factory.getOrderBookById(keys[0]);
        console.log(fee1);
        console.log(_baseToken1);
    (address _baseToken2,address _quoteToken2, bool _status2,uint256 lastTradePrice2,  uint256 fee2) = factory.getOrderBookById(keys[1]);

        assertEq(fee1, 5); // Verifica que la tarifa del primer libro sea correcta
        assertEq(fee2, 15); // Verifica que la tarifa del segundo libro sea correcta
    }

    //Verifica que el estado predeterminado de un nuevo libro de órdenes sea true al ser creado.
    function testOrderBookStatusDefault() public {
        vm.prank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 5, feeAddress); // Agregar libro de órdenes

        bytes32[] memory keys = factory.getKeysOrderBooks();
        (,, bool status,,) = factory.getOrderBookById(keys[0]);

        assertTrue(status); // Verifica que el estado predeterminado sea verdadero
    }

    //-------------------- GET KEYS ORDERS ------------------------------

    //Verifica que la función getKeysOrderBooks devuelva un array vacío cuando no se ha creado ningún libro de órdenes.
    function testGetKeysOrderBooksWithNoOrderBooks() public {
        // Llamar a getKeysOrderBooks antes de agregar ningún libro de órdenes
        bytes32[] memory keys = factory.getKeysOrderBooks();

        // Verificar que el array esté vacío
        assertEq(keys.length, 0, unicode"El array de claves debería estar vacío");
    }

    //Verifica que la función getKeysOrderBooks devuelva una lista que contenga el identificador de un único libro de órdenes creado.
    function testGetKeysOrderBooksWithSingleOrderBook() public {
        // Agregar un solo libro de órdenes
        vm.prank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 5, feeAddress);

        // Obtener las claves de los libros de órdenes
        bytes32[] memory keys = factory.getKeysOrderBooks();

        // Verificar que hay exactamente una clave
        assertEq(keys.length, 1, unicode"Debería haber una sola clave en el array");

        // Verificar que el identificador del libro de órdenes es correcto
        bytes32 expectedKey = keccak256(abi.encodePacked(address(tokenB), address(tokenA)));
        assertEq(keys[0], expectedKey, unicode"El identificador del libro de órdenes debería coincidir");
    }

    //Verifica que la función getKeysOrderBooks devuelva una lista de múltiples identificadores después de crear varios libros de órdenes.
    function testGetKeysOrderBooksWithMultipleOrderBooks() public {
        // Agregar varios libros de órdenes
        vm.startPrank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 5, feeAddress);
        factory.addOrderBook(address(tokenB), trader1, 10, feeAddress);
        vm.stopPrank();

        // Obtener las claves de los libros de órdenes
        bytes32[] memory keys = factory.getKeysOrderBooks();

        // Verificar que hay dos claves
        assertEq(keys.length, 2, unicode"Debería haber dos claves en el array");

        // Verificar que los identificadores de los libros de órdenes son correctos
        bytes32 expectedKey1 = keccak256(abi.encodePacked(address(tokenB), address(tokenA))); //TODO REVISAR PQ LOS DEBO INVERTIR
        bytes32 expectedKey2 = keccak256(abi.encodePacked(trader1,address(tokenB)));
        assertEq(keys[0], expectedKey1, unicode"El primer identificador debería coincidir");
        assertEq(keys[1], expectedKey2, unicode"El segundo identificador debería coincidir");
    }

    //Verifica que los identificadores devueltos estén en el mismo orden en que se crearon los libros de órdenes.
    function testGetKeysOrderBooksOrderConsistency() public {
        // Agregar varios libros de órdenes
        vm.startPrank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 5, feeAddress);
        factory.addOrderBook(address(tokenB), trader1, 10, feeAddress);
        factory.addOrderBook(trader1, trader2, 15, feeAddress);
        vm.stopPrank();

        // Obtener las claves de los libros de órdenes
        bytes32[] memory keys = factory.getKeysOrderBooks();

        // Verificar que las claves se devuelven en el mismo orden en que se agregaron
        bytes32 expectedKey1 = keccak256(abi.encodePacked(address(tokenB), address(tokenA)));
        bytes32 expectedKey2 = keccak256(abi.encodePacked(trader1,address(tokenB)));
        bytes32 expectedKey3 = keccak256(abi.encodePacked(trader2, trader1));

        assertEq(keys.length, 3, unicode"Debería haber tres claves en el array");
        console.logBytes32(expectedKey1);
        console.logBytes32(expectedKey2);
        console.logBytes32(expectedKey3);

        console.logBytes32(keys[0]);
        console.logBytes32(keys[1]);
        console.logBytes32(keys[2]);

        console.logBytes32(keccak256(abi.encodePacked(address(tokenB), address(tokenA))));
        console.logBytes32(keccak256(abi.encodePacked( trader1,address(tokenB))));
        console.logBytes32(keccak256(abi.encodePacked(trader2, trader1)));
        assertEq(keys[0], expectedKey1, unicode"El primer identificador debería coincidir");
        assertEq(keys[1], expectedKey2, unicode"El segundo identificador debería coincidir");
        assertEq(keys[2], expectedKey3, unicode"El tercer identificador debería coincidir");
    }

    //-------------------- GET ORDERS BOOK BY ID ------------------------------

    //Verifica que la función getOrderBookById devuelva valores por defecto (dirección 0x0, false, etc.) cuando se consulta por un libro de órdenes que no existe.
    function testGetOrderBookByIdForNonExistentOrderBook() public {
        // Intentar obtener un libro de órdenes con un ID inexistente
        bytes32 nonExistentId = keccak256(abi.encodePacked(address(tokenA), address(tokenB)));

        // Llamar a la función getOrderBookById
        (
            address baseToken,
            address quoteToken,
            bool status,
            uint256 lastTradePrice,
            uint256 fee
        ) = factory.getOrderBookById(nonExistentId);

        // Verificar que los valores devueltos sean los por defecto
        assertEq(baseToken, address(0), unicode"El baseToken debería ser la dirección cero");
        assertEq(quoteToken, address(0), unicode"El quoteToken debería ser la dirección cero");
        assertEq(status, false, unicode"El estado debería ser falso");
        assertEq(lastTradePrice, 0, unicode"El último precio de operación debería ser cero");
        assertEq(fee, 0, unicode"La tarifa debería ser cero");
    }

    //Verifica que la función getOrderBookById devuelva los valores correctos después de crear un nuevo libro de órdenes.
    function testGetOrderBookByIdAfterCreation() public {
        // Crear un libro de órdenes
        vm.prank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 5, feeAddress);

        // Obtener las claves de los libros de órdenes
        bytes32[] memory keys = factory.getKeysOrderBooks();

        // Verificar que hay exactamente una clave
        assertEq(keys.length, 1, unicode"Debería haber una sola clave en el array");

        // Llamar a la función getOrderBookById
        (
            address baseToken,
            address quoteToken,
            bool status,
            uint256 lastTradePrice,
            uint256 fee
        ) = factory.getOrderBookById(keys[0]);

        console.log(baseToken);
        console.log(quoteToken);

    // Verificar que los valores devueltos coincidan con los del libro de órdenes
        //TODO REVISAR PQ LOS INVIERTE
        assertEq(baseToken, address(tokenB), unicode"El baseToken debería coincidir con el libro de órdenes creado");
        assertEq(quoteToken, address(tokenA), unicode"El quoteToken debería coincidir con el libro de órdenes creado");
        assertEq(status, true, unicode"El estado debería ser verdadero");
        assertEq(lastTradePrice, 0, unicode"El último precio de operación debería ser cero");
        assertEq(fee, 5, unicode"La tarifa debería ser la especificada en la creación");
    }

    //Verifica que se puedan consultar varios libros de órdenes creados, y que la función devuelva los datos correctos para cada uno.
    function testGetOrderBookByIdForMultipleOrderBooks() public {
        // Crear múltiples libros de órdenes
        vm.startPrank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 5, feeAddress);
        factory.addOrderBook(address(tokenB), trader1, 10, feeAddress);
        vm.stopPrank();

        // Obtener las claves de los libros de órdenes
        bytes32[] memory keys = factory.getKeysOrderBooks();

        // Verificar que hay exactamente una clave
        assertEq(keys.length, 2, unicode"Debería haber dos claves en el array");

        // Generar los IDs esperados
        //bytes32 orderId1 = keccak256(abi.encodePacked(address(tokenA), address(tokenB)));
        //bytes32 orderId2 = keccak256(abi.encodePacked(address(tokenB), trader1));

        // Obtener y verificar el primer libro de órdenes
        (
            address baseToken1,
            address quoteToken1,
            bool status1,
            uint256 lastTradePrice1,
            uint256 fee1
        ) = factory.getOrderBookById(keys[0]);
        //TODO REVISA PQ CAMBIA
        assertEq(baseToken1, address(tokenB), unicode"El baseToken del primer libro debería coincidir");
        assertEq(quoteToken1, address(tokenA), unicode"El quoteToken del primer libro debería coincidir");
        assertEq(status1, true, unicode"El estado del primer libro debería ser verdadero");
        assertEq(lastTradePrice1, 0, unicode"El último precio del primer libro debería ser cero");
        assertEq(fee1, 5, unicode"La tarifa del primer libro debería ser 5");

        // Obtener y verificar el segundo libro de órdenes
        (
            address baseToken2,
            address quoteToken2,
            bool status2,
            uint256 lastTradePrice2,
            uint256 fee2
        ) = factory.getOrderBookById(keys[1]);
        assertEq(baseToken2, trader1, unicode"El baseToken del segundo libro debería coincidir");
        assertEq(quoteToken2, address(tokenB), unicode"El quoteToken del segundo libro debería coincidir");
        assertEq(status2, true, unicode"El estado del segundo libro debería ser verdadero");
        assertEq(lastTradePrice2, 0, unicode"El último precio del segundo libro debería ser cero");
        assertEq(fee2, 10, unicode"La tarifa del segundo libro debería ser 10");
    }

    //-------------------- SET OWNER ------------------------------

    //Verifica que el propietario actual pueda cambiar correctamente la dirección del propietario a una nueva dirección válida.
    function testSetOwnerAsOwner() public {
        // El propietario actual intenta cambiar la dirección del propietario
        vm.prank(owner); // Simular que el propietario actual está llamando
        factory.setOwner(trader1);

        // Verificar que el propietario haya sido cambiado correctamente
        assertEq(factory.getOwner(), trader1, unicode"La nueva dirección del propietario debería ser addr1");
    }

    //Verifica que la función setOwner revierta si es llamada por una dirección que no es el propietario actual.
    function testSetOwnerRevertsIfCallerIsNotOwner() public {
        // Intentar cambiar el propietario desde una dirección que no es el propietario actual

        // Verificar que la llamada revierte
        vm.startPrank(trader1);
        vm.expectRevert(OrderBookFactory.OrderBookFactory__InvalidOwnerAddress.selector);
        factory.setOwner(trader1);
        vm.stopPrank();
    }

    //Verifica que la función setOwner revierta si se intenta establecer la dirección del propietario como la dirección cero (address(0)).
    function testSetOwnerRevertsIfNewOwnerIsZeroAddress() public {
        // El propietario intenta establecer la dirección cero como el nuevo propietario
        vm.prank(owner); // Simular que el propietario actual está llamando

        // Verificar que la llamada revierte debido a que la dirección nueva es 0x0
        vm.expectRevert(OrderBookFactory.OrderBookFactory__InvalidOwnerAddressZero.selector);
        factory.setOwner(address(0));
    }

    //Después de cambiar la propiedad una vez, verificar que el nuevo propietario pueda cambiar la propiedad nuevamente a otra dirección válida.
    function testSetOwnerFromNewOwner() public {
        // El propietario actual (owner) cambia la propiedad a addr1
        vm.prank(owner); // Simular que el propietario actual llama
        factory.setOwner(trader1);

        // Verificar que la propiedad haya sido transferida a addr1
        assertEq(factory.getOwner(), trader1, unicode"El nuevo propietario debería ser addr1");

        // El nuevo propietario (addr1) cambia la propiedad a addr2
        vm.prank(trader1); // Simular que el nuevo propietario llama
        factory.setOwner(owner);

        // Verificar que la propiedad haya sido transferida a addr2
        assertEq(factory.getOwner(), owner, unicode"El nuevo propietario debería ser addr2");
    }


    //-------------------- SET ORDER BOOK STATUS ------------------------------

    //Verifica que el propietario pueda cambiar el estado de un libro de órdenes existente.
    function testSetOrderBookStatusAsOwner() public {
        // Cambiar el estado del libro de órdenes a inactivo (false)
        vm.startPrank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 5, feeAddress);
        vm.stopPrank();

        // Obtener las claves de los libros de órdenes
        bytes32[] memory keys = factory.getKeysOrderBooks();

        // Verificar que hay exactamente una clave
        assertEq(keys.length, 1, unicode"Debería haber dos claves en el array");

        vm.prank(owner); // Simular que el propietario está llamando
        factory.setOrderBookStatus(keys[0], false);

        // Verificar que el estado haya cambiado correctamente
        (, , bool status, , ) = factory.getOrderBookById(keys[0]);
        assertEq(status, false, unicode"El estado del libro de órdenes debería ser inactivo");
    }

    //Verifica que la función setOrderBookStatus revierta si es llamada por una dirección que no es el propietario.
    function testSetOrderBookStatusRevertsIfNotOwner() public {
        // Intentar cambiar el estado desde una dirección no propietaria
        bytes32 orderId1 = keccak256(abi.encodePacked(address(tokenA), address(tokenB)));

        vm.prank(owner); // Simular que una dirección que no es el propietario llama
        // Verificar que la llamada revierte
        vm.expectRevert(OrderBookFactory.OrderBookFactory__OrderBookIdOutOfRange.selector);
        factory.setOrderBookStatus(orderId1, false);
    }

    //Verifica que la función setOrderBookStatus revierta si se intenta cambiar el estado de un libro de órdenes que no existe.
    function testSetOrderBookStatusRevertsIfOrderBookDoesNotExist() public {
        bytes32 nonExistentOrderBookId = keccak256(abi.encodePacked(address(6), address(7)));

        // Intentar cambiar el estado de un libro de órdenes inexistente
        vm.prank(owner); // Simular que el propietario actual está llamando
        // Verificar que la llamada revierte debido a que el libro no existe
        vm.expectRevert(OrderBookFactory.OrderBookFactory__OrderBookIdOutOfRange.selector);
        factory.setOrderBookStatus(nonExistentOrderBookId, false);
    }

    //-------------------- SET ORDER BOOK FEE ------------------------------
    //Verifica que el propietario pueda cambiar la tarifa de un libro de órdenes existente.
    function testSetOrderBookFeeAsOwner() public {
        uint256 newFee = 5; // Nueva tarifa del 5%
        vm.startPrank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 10, feeAddress);
        vm.stopPrank();

        // Obtener las claves de los libros de órdenes
        bytes32[] memory keys = factory.getKeysOrderBooks();

        // Verificar que hay exactamente una clave
        assertEq(keys.length, 1, unicode"Debería haber dos claves en el array");

        // Cambiar la tarifa del libro de órdenes
        vm.prank(owner); // Simular que el propietario está llamando
        factory.setOrderBookFee(keys[0], newFee);

        // Verificar que la tarifa haya cambiado correctamente
        (, , , , uint256 fee) = factory.getOrderBookById(keys[0]);
        assertEq(fee, newFee, unicode"La tarifa del libro de órdenes debería haberse actualizado al 5%");
    }

    //Verifica que la función setOrderBookFee revierta si es llamada por una dirección que no es el propietario.
    function testSetOrderBookFeeRevertsIfNotOwner() public {
        bytes32 orderId1 = keccak256(abi.encodePacked(address(tokenA), address(tokenB)));
        uint256 newFee = 5; // Nueva tarifa del 5%

        // Intentar cambiar la tarifa desde una dirección no propietaria
        vm.prank(trader1); // Simular que una dirección no propietaria llama

        // Verificar que la llamada revierte
        vm.expectRevert(OrderBookFactory.OrderBookFactory__InvalidOwnerAddress.selector);
        factory.setOrderBookFee(orderId1, newFee);
    }

    //Verifica que la función setOrderBookFee revierta si se intenta cambiar la tarifa de un libro de órdenes que no existe.
    function testSetOrderBookFeeRevertsIfOrderBookDoesNotExist() public {
        uint256 newFee = 5; // Nueva tarifa del 5%
        bytes32 nonExistentOrderBookId = keccak256(abi.encodePacked(address(6), address(7)));

        // Intentar cambiar la tarifa de un libro de órdenes inexistente
        vm.prank(owner); // Simular que el propietario actual está llamando
        // Verificar que la llamada revierte debido a que el libro no existe
        vm.expectRevert(OrderBookFactory.OrderBookFactory__OrderBookIdOutOfRange.selector);
        factory.setOrderBookFee(nonExistentOrderBookId, newFee);
    }

    //Verifica que se emite correctamente el evento OrderBookFeeChanged después de cambiar la tarifa.
    function testSetOrderBookFeeEmitEvent() public {
        uint256 newFee = 5; // Nueva tarifa del 5%
        vm.startPrank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 10, feeAddress);
        vm.stopPrank();

        // Obtener las claves de los libros de órdenes
        bytes32[] memory keys = factory.getKeysOrderBooks();

        // Verificar que hay exactamente una clave
        assertEq(keys.length, 1, unicode"Debería haber dos claves en el array");

        // Esperar a que el evento `OrderBookFeeChanged` sea emitido
        vm.expectEmit(true, true, true, true);
        emit OrderBookFeeChanged(keys[0], newFee);

        // Cambiar la tarifa del libro de órdenes
        vm.prank(owner); // Simular que el propietario está llamando
        factory.setOrderBookFee(keys[0], newFee);
    }

    //-------------------- SET ORDER BOOK FEE ADDRESS ------------------------------

    //Verifica que el propietario pueda cambiar la dirección de la tarifa de un libro de órdenes existente.
    function testSetOrderBookFeeAddressAsOwner() public {
        // Cambiar la dirección de la tarifa del libro de órdenes
        address newFeeAddress = makeAddr("newFeeAddress");

        vm.startPrank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 10, feeAddress);
        vm.stopPrank();

        // Obtener las claves de los libros de órdenes
        bytes32[] memory keys = factory.getKeysOrderBooks();

        // Verificar que hay exactamente una clave
        assertEq(keys.length, 1, unicode"Debería haber dos claves en el array");

        vm.prank(owner); // Simular que el propietario está llamando
        factory.setOrderBookFeeAddress(keys[0], newFeeAddress);

        // Verificar que la dirección de la tarifa haya cambiado correctamente
        //(, , , , ,address feeAddr) = factory.getOrderBookById(keys[0]);
        //assertEq(feeAddr, newFeeAddress, unicode"La dirección de la tarifa debería haberse actualizado correctamente.");
    }

    //Verifica que la función setOrderBookFeeAddress revierta si es llamada por una dirección que no es el propietario.
    function testSetOrderBookFeeAddressRevertsIfNotOwner() public {
        bytes32 nonExistentOrderBookId = keccak256(abi.encodePacked(address(6), address(7)));
        address newFeeAddress = makeAddr("newFeeAddress");
        // Intentar cambiar la dirección de la tarifa desde una dirección no propietaria
        vm.prank(trader1); // Simular que una dirección no propietaria llama
        // Verificar que la llamada revierte
        vm.expectRevert(OrderBookFactory.OrderBookFactory__InvalidOwnerAddress.selector);
        factory.setOrderBookFeeAddress(nonExistentOrderBookId, newFeeAddress);
    }

    //Verifica que la función setOrderBookFeeAddress revierta si se intenta cambiar la dirección de la tarifa de un libro de órdenes que no existe.
    function testSetOrderBookFeeAddressRevertsIfOrderBookDoesNotExist() public {
        address newFeeAddress = makeAddr("newFeeAddress");
        bytes32 nonExistentOrderBookId = keccak256(abi.encodePacked(address(7), address(8)));

        // Intentar cambiar la dirección de la tarifa de un libro de órdenes inexistente
        vm.prank(owner); // Simular que el propietario actual está llamando

        // Verificar que la llamada revierte debido a que el libro no existe
        vm.expectRevert(OrderBookFactory.OrderBookFactory__OrderBookIdOutOfRange.selector);
        factory.setOrderBookFeeAddress(nonExistentOrderBookId, newFeeAddress);
    }

    //Verifica que la función setOrderBookFeeAddress revierta si se intenta establecer una dirección de tarifa inválida (la dirección cero).
    function testSetOrderBookFeeAddressRevertsIfFeeAddressIsZero() public {
        vm.startPrank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 10, feeAddress);
        vm.stopPrank();

        // Obtener las claves de los libros de órdenes
        bytes32[] memory keys = factory.getKeysOrderBooks();

        // Verificar que hay exactamente una clave
        assertEq(keys.length, 1, unicode"Debería haber dos claves en el array");
        // Intentar cambiar la dirección de la tarifa a la dirección cero
        vm.prank(owner); // Simular que el propietario actual está llamando
        // Verificar que la llamada revierte debido a que la dirección de tarifa es inválida
        vm.expectRevert(OrderBookFactory.OrderBookFactory__InvalidFeeAddress.selector);
        factory.setOrderBookFeeAddress(keys[0], address(0));
    }

    //Verifica que se emita correctamente el evento OrderBookFeeAddressChanged después de cambiar la dirección de la tarifa.
    function testSetOrderBookFeeAddressEmitEvent() public {
        address newFeeAddress = makeAddr("newFeeAddress");
        vm.startPrank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 10, feeAddress);
        vm.stopPrank();

        // Obtener las claves de los libros de órdenes
        bytes32[] memory keys = factory.getKeysOrderBooks();

        // Verificar que hay exactamente una clave
        assertEq(keys.length, 1, unicode"Debería haber dos claves en el array");

        // Esperar a que el evento `OrderBookFeeAddressChanged` sea emitido
        vm.expectEmit(true, true, true, true);
        emit OrderBookFeeAddressChanged(keys[0], newFeeAddress);

        // Cambiar la dirección de la tarifa del libro de órdenes
        vm.prank(owner); // Simular que el propietario está llamando
        factory.setOrderBookFeeAddress(keys[0], newFeeAddress);
    }

    //-------------------- GET OWNER ------------------------------

    //Verifica que la dirección del propietario sea la dirección inicialmente establecida al desplegar el contrato.
    function testGetOwnerInitially() public {
        // Verificar que la dirección del propietario inicial sea la correcta
        assertEq(factory.getOwner(), owner, unicode"La dirección del propietario debería ser la dirección inicial establecida.");
    }

    //Verifica que la función getOwner devuelva la dirección correcta después de que el propietario haya sido cambiado utilizando la función setOwner.
    function testGetOwnerAfterOwnershipChange() public {
        address newOwner = makeAddr("newOwner");
        // Cambiar la propiedad a una nueva dirección
        vm.prank(owner); // Simular que el propietario actual está llamando
        factory.setOwner(newOwner);

        // Verificar que la función getOwner devuelva la nueva dirección de propietario
        assertEq(factory.getOwner(), newOwner, unicode"La dirección del propietario debería haber cambiado a la nueva dirección.");
    }

    //-------------------- ADD NEW ORDER ------------------------------

    //Verifica que una nueva orden de compra se agrega correctamente a un libro de órdenes existente.
    function testAddNewBuyOrder() public {

        vm.startPrank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 10, feeAddress);
        vm.stopPrank();

        // Obtener las claves de los libros de órdenes
        bytes32[] memory keys = factory.getKeysOrderBooks();

        // Verificar que hay exactamente una clave
        assertEq(keys.length, 1, unicode"Debería haber dos claves en el array");

        // Agregar una nueva orden de compra
        uint256 quantity = 10;
        uint256 price = 100;
        bool isBuy = true;

        vm.prank(trader2);
        factory.addNewOrder(keys[0], quantity, price, isBuy, trader2);

        // Verificar que la orden de compra se haya agregado correctamente
        //TODO PQ SE INVIERTE EL TOKEN
        (address baseTokenOrder, address quoteTokenOrder, , uint256 lastTradePrice,) = factory.getOrderBookById(keys[0]);
        assertEq(baseTokenOrder, address(tokenB), "El token base debe coincidir");
        assertEq(quoteTokenOrder, address(tokenA), unicode"El token de cotización debe coincidir");
        assertEq(lastTradePrice, 0, unicode"El último precio negociado debe ser 0 al inicio");
    }

    //Verifica que una nueva orden de venta se agrega correctamente a un libro de órdenes existente.
    function testAddNewSellOrder() public {
        vm.startPrank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 10, feeAddress);
        vm.stopPrank();

        // Obtener las claves de los libros de órdenes
        bytes32[] memory keys = factory.getKeysOrderBooks();

        // Verificar que hay exactamente una clave
        assertEq(keys.length, 1, unicode"Debería haber dos claves en el array");

        // Agregar una nueva orden de venta
        uint256 quantity = 10;
        uint256 price = 100;
        bool isBuy = false;

        vm.prank(trader1);
        factory.addNewOrder(keys[0], quantity, price, false, trader1);

        // Verificar que la orden de venta se haya agregado correctamente
        (address baseTokenOrder, address quoteTokenOrder, , uint256 lastTradePrice,) = factory.getOrderBookById(keys[0]);
        assertEq(baseTokenOrder, address(tokenB), "El token base debe coincidir");
        assertEq(quoteTokenOrder, address(tokenA), unicode"El token de cotización debe coincidir");
        assertEq(lastTradePrice, 0, unicode"El último precio negociado debe ser 0 al inicio");
    }

    //Verifica que se revierte si se intenta agregar una orden a un libro de órdenes que no existe.
    function testAddOrderToNonExistentOrderBook() public {
        // Intentar agregar una orden a un libro de órdenes inexistente
        bytes32 nonExistentOrderBookId = keccak256(abi.encodePacked(address(100), address(101)));
        uint256 quantity = 10;
        uint256 price = 100;
        bool isBuy = true;

        vm.prank(owner);
        vm.expectRevert(OrderBookFactory.OrderBookFactory__OrderBookIdOutOfRange.selector);
        factory.addNewOrder(nonExistentOrderBookId, quantity, price, isBuy, trader1);
    }

    //Verifica que no se pueda agregar una orden de compra con cantidad cero.
    function testAddBuyOrderWithZeroQuantity() public {
        vm.startPrank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 10, feeAddress);
        vm.stopPrank();

        // Obtener las claves de los libros de órdenes
        bytes32[] memory keys = factory.getKeysOrderBooks();

        // Verificar que hay exactamente una clave
        assertEq(keys.length, 1, unicode"Debería haber dos claves en el array");

        // Verificar que no se pueda agregar una orden de compra con cantidad cero
        uint256 price = 10;
        bool isBuy = true;
        uint256 quantity = 0;

        vm.prank(owner);
        vm.expectRevert(OrderBookFactory.OrderBookFactory__InvalidQuantityValueZero.selector);  // Puedes agregar un revert message si implementas uno en el contrato
        factory.addNewOrder(keys[0], quantity, price, isBuy, trader1);
    }

    //Verifica que no se pueda agregar una orden de venta con cantidad cero.
    function testAddSellOrderWithZeroQuantity() public {
        vm.startPrank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 10, feeAddress);
        vm.stopPrank();

        // Obtener las claves de los libros de órdenes
        bytes32[] memory keys = factory.getKeysOrderBooks();

        // Verificar que hay exactamente una clave
        assertEq(keys.length, 1, unicode"Debería haber dos claves en el array");

        // Verificar que no se pueda agregar una orden de venta con cantidad cero
        uint256 price = 15;
        bool isBuy = false;
        uint256 quantity = 0;

        vm.prank(owner);
        vm.expectRevert(OrderBookFactory.OrderBookFactory__InvalidQuantityValueZero.selector);  // Puedes agregar un revert message si implementas uno en el contrato
        factory.addNewOrder(keys[0], quantity, price, isBuy, trader2);
    }

    /*//Verifica que no se pueda agregar una orden de compra con una dirección de trader inválida (por ejemplo, la dirección cero).
    function testAddBuyOrderWithInvalidTraderAddress() public {
        vm.startPrank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 10, feeAddress);
        vm.stopPrank();

        // Obtener las claves de los libros de órdenes
        bytes32[] memory keys = factory.getKeysOrderBooks();

        // Verificar que hay exactamente una clave
        assertEq(keys.length, 1, unicode"Debería haber dos claves en el array");

        // Verificar que no se pueda agregar una orden con una dirección de trader inválida (dirección cero)
        uint256 quantity = 10;
        uint256 price = 100;
        bool isBuy = true;
        address invalidTrader = address(0);

        vm.prank(invalidTrader);
        //vm.expectRevert(OrderBookFactory.OrderBookFactory__InvalidQuantityValueZero.selector);  // Puedes agregar un revert message si implementas uno en el contrato
        factory.addNewOrder(keys[0], quantity, price, isBuy, invalidTrader);
    }*/

    //Verifica que no se pueda agregar una orden de venta con una dirección de trader inválida (dirección cero).
    /*function testAddSellOrderWithInvalidTraderAddress() public {
        // Verificar que no se pueda agregar una orden de venta con una dirección de trader inválida (dirección cero)
        uint256 quantity = 500;
        uint256 price = 20;
        bool isBuy = false;
        address invalidTrader = address(0);

        vm.prank(invalidTrader);
        vm.expectRevert("Invalid trader address");  // Puedes agregar un revert message si implementas uno en el contrato
        factory.addNewOrder(orderBookId, quantity, price, isBuy, invalidTrader);
    }

    //Verifica que se pueden agregar múltiples órdenes de compra y venta con el mismo precio en un libro de órdenes.
    function testAddOrderWithSamePrice() public {
        // Verificar que se pueden agregar múltiples órdenes con el mismo precio
        uint256 quantity1 = 1000;
        uint256 quantity2 = 500;
        uint256 price = 10;
        bool isBuy = true;

        vm.prank(trader);
        factory.addNewOrder(orderBookId, quantity1, price, isBuy, trader);

        vm.prank(trader);
        factory.addNewOrder(orderBookId, quantity2, price, isBuy, trader);

        // Verificar si el libro de órdenes tiene ambas órdenes con el mismo precio
        (address baseTokenOrder, address quoteTokenOrder, , uint256 lastTradePrice,) = factory.getOrderBookById(orderBookId);
        assertEq(baseTokenOrder, baseToken, "El token base debe coincidir");
        assertEq(quoteTokenOrder, quoteToken, "El token de cotización debe coincidir");
        assertEq(lastTradePrice, 0, "El último precio negociado debe ser 0 al inicio");
    }

    //Verifica que no se puede agregar una orden a un libro de órdenes que ha sido desactivado (su estado está en false).
    function testAddOrderAfterOrderBookDeactivated() public {
        // Desactivar el libro de órdenes
        vm.prank(owner);
        factory.setOrderBookStatus(orderBookId, false);

        // Intentar agregar una orden después de desactivar el libro de órdenes
        uint256 quantity = 1000;
        uint256 price = 10;
        bool isBuy = true;

        vm.prank(trader);
        vm.expectRevert("Order book is inactive");  // Puedes agregar un revert message si implementas uno en el contrato
        factory.addNewOrder(orderBookId, quantity, price, isBuy, trader);
    }*/


    //-------------------- CANCEL ORDER ------------------------------

    /*//Verifica que una orden puede ser cancelada exitosamente en un libro de órdenes válido.
    function testCancelOrderSuccessfully() public {
        vm.startPrank(owner);
        factory.addOrderBook(address(tokenA), address(tokenB), 10, feeAddress);
        vm.stopPrank();

        // Obtener las claves de los libros de órdenes
        bytes32[] memory keys = factory.getKeysOrderBooks();

        // Verificar que hay exactamente una clave
        assertEq(keys.length, 1, unicode"Debería haber dos claves en el array");

        // Agregar una nueva orden de compra
        uint256 quantity = 10;
        uint256 price = 100;
        bool isBuy = true;

        vm.prank(trader2);
        factory.addNewOrder(keys[0], quantity, price, isBuy, trader2);

        // Cancelar la orden exitosamente
        //vm.prank(trader2);
        factory.cancelOrder(keys[0]);

        // Verificar que la orden fue cancelada
        //(, , bool status,,) = factory.getOrderBookById(keys[0]);
        //assertFalse(status, unicode"La orden debería estar cancelada");
    }

    /*function testCancelOrderNonExistentOrderBook() public {
        // Intentar cancelar una orden en un libro de órdenes que no existe
        bytes32 nonExistentOrderBookId = keccak256(abi.encodePacked(address(6), address(7)));

        vm.prank(trader);
        vm.expectRevert(OrderBookFactory.OrderBookFactory__OrderBookIdOutOfRange.selector);
        factory.cancelOrder(nonExistentOrderBookId);
    }

    function testCancelOrderFromNonOwner() public {
        // Intentar cancelar una orden desde una cuenta no autorizada
        address nonOwner = address(6);

        vm.prank(nonOwner);
        vm.expectRevert("Caller is not authorized to cancel this order");
        factory.cancelOrder(orderBookId);
    }

    function testCancelOrderOnInactiveOrderBook() public {
        // Desactivar el libro de órdenes primero
        vm.prank(owner);
        factory.setOrderBookStatus(orderBookId, false);

        // Intentar cancelar una orden en un libro de órdenes desactivado
        vm.prank(trader);
        vm.expectRevert("Order book is inactive");
        factory.cancelOrder(orderBookId);
    }

    function testCancelOrderAfterAlreadyCanceled() public {
        // Cancelar la orden una primera vez
        vm.prank(trader);
        factory.cancelOrder(orderBookId);

        // Intentar cancelar la misma orden de nuevo
        vm.prank(trader);
        vm.expectRevert("Order already canceled");
        factory.cancelOrder(orderBookId);
    }*/


}
