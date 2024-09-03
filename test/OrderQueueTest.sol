// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/OrderQueue.sol";
import "forge-std/console.sol";

contract OrderQueueTest is Test {
    using OrderQueue for OrderQueue.Queue;

    OrderQueue.Queue private queue;

    address private trader1 = address(1);
    address private trader2 = address(2);
    address private trader3 = address(3);

    bytes32 private orderId1 = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
    bytes32 private orderId2 = keccak256(abi.encodePacked(trader2, "sell", "200", block.timestamp));
    bytes32 private orderId3 = keccak256(abi.encodePacked(trader3, "buy", "300", block.timestamp));

    function setUp() public {
        //queue = OrderQueue.Queue();
    }

    //-------------------- ORDER EXISTS ------------------------------

    //Existencia de Órdenes (orderExists):Verificar que una orden añadida esté en la cola.
    function testOrderExistsAfterAddingQueue() public {
        queue.push(trader1, orderId1);
        bool exists = queue.orderExists(orderId1);
        assertTrue(exists, "Order should exist after being added");
    }

    //Existencia de Órdenes (orderExists):Verificar que una orden que no ha sido añadida no exista en la cola.
    function testOrderDoesNotExistIfNotAddedQueue() public view {
        bool exists = queue.orderExists(orderId1);
        assertFalse(exists, "Order should not exist if it has not been added");
    }

    //Existencia de Órdenes (orderExists): Verificar que devuelve false después de la eliminación, indicando que la orden ya no existe.
    function testOrderExistsAfterRemovingOrderQueue() public {
        queue.push(trader1, orderId1);
        queue.removeOrder(orderId1); // Elimina la orden
        bool exists = queue.orderExists(orderId1);
        assertFalse(exists, "Order should not exist after being removed");
    }

    //-------------------- ISEMPTY ------------------------------

    //IsEmpty: Verificar que la cola está vacía al inicializar
    function testIsEmptyInitialQueue() public view {
        bool empty = queue.isEmpty();
        assertTrue(empty, "Queue should be empty initially");
    }

    //IsEmpty: Verificar que la cola no está vacía después de añadir un elemento
    function testIsEmptyAfterAddingElementQueue() public {
        queue.push(trader1, orderId1);
        bool empty = queue.isEmpty();
        assertFalse(empty, "Queue should not be empty after adding an element");
    }

    //IsEmpty: Verificar que la cola está vacía después de eliminar todos los elementos
    function testIsEmptyAfterRemovingAllElementsQueue() public {
        queue.push(trader1, orderId1);
        queue.pop(); // Elimina el único elemento
        bool empty = queue.isEmpty();
        assertTrue(empty, "Queue should be empty after removing all elements");
    }

    //IsEmpty: Verifica que la cola no está vacía después de eliminar un elemento que no es ni el primero ni el último.
    function testIsEmptyAfterRemovingElementInMiddleQueue() public {
        queue.push(trader1, orderId1);
        queue.push(trader2, orderId2);
        queue.push(trader3, orderId3);
        queue.removeOrder(orderId2); // Elimina el elemento en medio
        bool empty = queue.isEmpty();
        assertFalse(empty, "Queue should not be empty after removing an element in the middle");
    }

    //IsEmpty: Verifica que la cola no está vacía después de eliminar la primera orden, asegurando que first se actualice correctamente.
    function testIsEmptyAfterRemovingFirstElementQueue() public {
        queue.push(trader1, orderId1);
        queue.push(trader2, orderId2);
        queue.removeOrder(orderId1); // Elimina la primera orden
        bool empty = queue.isEmpty();
        assertFalse(empty, "Queue should not be empty after removing the first element");
        assertEq(queue.first, orderId2);
    }

    //IsEmpty: Verifica que la cola no está vacía después de eliminar la última orden.
    function testIsEmptyAfterRemovingLastElementQueue() public {
        queue.push(trader1, orderId1);
        queue.push(trader2, orderId2);
        queue.removeOrder(orderId2); // Elimina la última orden
        bool empty = queue.isEmpty();
        assertFalse(empty, "Queue should not be empty after removing the last element");
        assertEq(queue.last, orderId1);
    }

    //-------------------- PUSH ------------------------------
    //Agregar Ordenes (push): Agregar una orden a la cola vacía y verificar que se actualicen correctamente los punteros first y last.
    function testPushEmptyQueue() public {
        queue.push(trader1, orderId1);
        assertFalse(queue.isEmpty());
        assertTrue(queue.orderExists(orderId1));
        assertEq(queue.first, orderId1);
        assertEq(queue.last, orderId1);
    }

    //Agregar Ordenes (push): Agregar una segunda orden a una cola que ya tiene una orden y verificar que la nueva orden se coloque correctamente después de la primera, y que el puntero last se actualice adecuadamente.
    function testPushOneOrderInQueue() public {
        queue.push(trader1, orderId1);
        queue.push(trader2, orderId2);
        assertFalse(queue.isEmpty());
        assertTrue(queue.orderExists(orderId1));
        assertTrue(queue.orderExists(orderId2));
        assertEq(queue.first, orderId1);
        assertEq(queue.last, orderId2);
    }

    //Agregar Ordenes (push): Agregar múltiples órdenes y verificar el correcto encadenamiento de los nodos (next y prev).
    function testPushMultipleOrdersQueue() public {
        queue.push(trader1, orderId1);
        queue.push(trader2, orderId2);
        queue.push(trader3, orderId3);

        assertEq(queue.first, orderId1);
        assertEq(queue.last, orderId3);

        assertEq(queue.orders[orderId1].next, orderId2);
        assertEq(queue.orders[orderId2].next, orderId3);
        assertEq(queue.orders[orderId2].prev, orderId1);
        assertEq(queue.orders[orderId3].prev, orderId2);
    }

    //Agregar Ordenes (push): Verificar el Estado de la Cola Antes y Después de la Inserción
    function testPushStateVerificationQueue() public {
        assertEq(queue.first, 0, "Initial first pointer should be zero");
        assertEq(queue.last, 0, "Initial last pointer should be zero");

        queue.push(trader1, orderId1);
        queue.push(trader2, orderId2);

        assertEq(queue.first, orderId1, "First order ID should be updated");
        assertEq(queue.last, orderId2, "Last order ID should be updated");
        assertEq(queue.orders[orderId1].next, orderId2, "Next pointer of the first node should point to the second");
        assertEq(queue.orders[orderId2].prev, orderId1, "Prev pointer of the second node should point to the first");
    }

    //-------------------- POP ------------------------------

    //Eliminación de Ordenes (pop): Eliminar una orden en una cola con un solo elemento y verificar que la cola quede vacía.
    function testPopSingleElementQueue() public {
        queue.push(trader1, orderId1);
        assertTrue(queue.orderExists(orderId1));
        queue.pop();
        // Verificar que la cola esté vacía
        assertEq(queue.first, 0);
        assertFalse(queue.orderExists(orderId1));
    }

    //Eliminación de Ordenes (pop): Eliminar una orden en una cola con múltiples elementos y verificar que se actualicen correctamente los punteros first y last.
    function testPopMultipleElementsQueue() public {
        queue.push(trader1, orderId1);
        queue.push(trader2, orderId2);

        OrderQueue.OrderBookNode memory poppedOrder = queue.pop();
        assertEq(poppedOrder.orderId, orderId1);
        assertTrue(queue.orderExists(orderId2));
        assertFalse(queue.orderExists(orderId1));
        assertEq(queue.first, orderId2);
    }

    //Eliminación de Ordenes (pop): Intentar eliminar una orden de una cola vacía y esperar el error OrderQueue__CantPopAnEmptyQueue.
    function testPopEmptyQueueRevertsQueue() public {
        //Indicar que se espera que una transacción falle y revierta con un error específico
        vm.expectRevert(OrderQueue.OrderQueue__CantPopAnEmptyQueue.selector);
        queue.pop();
    }

    //Eliminación de Ordenes (pop): Eliminar multiples ordenes en una cola con múltiples elementos y verificar que se actualicen correctamente los punteros first y last.
    function testPopMultipleRemovalsQueue() public {
        queue.push(trader1, orderId1);
        queue.push(trader2, orderId2);
        queue.push(trader3, orderId3);

        queue.pop();

        //Valido status
        assertEq(queue.first, orderId2, "First should be orderid2 after removing first order");
        assertEq(queue.last, orderId3, "Last should orderid3 after removing first order");
        assertEq(queue.orders[orderId2].next, orderId3, "Next pointer of the first node should point to the second");
        assertEq(queue.orders[orderId3].prev, orderId2, "Prev pointer of the second node should point to the first");

        queue.pop();

        //Valido status
        assertEq(queue.first, orderId3, "First should be orderid3 after removing first order");
        assertEq(queue.last, orderId3, "Last should orderid3 after removing first order");
        assertEq(queue.orders[orderId3].next, 0, "Next pointer of the first node should point to the second");

        queue.pop();

        assertEq(queue.first, 0, "First should be 0 after removing all orders");
        assertEq(queue.first, 0, "Last should be 0 after removing all orders");
    }

    //-------------------- REMOVE ORDER ------------------------------
    //Eliminación de Órdenes Específicas (removeOrder): Eliminar una orden en medio de la cola y verificar que se actualicen correctamente los punteros next y prev de los nodos adyacentes.
    function testRemoveOrderMiddleQueue() public {
        queue.push(trader1, orderId1);
        queue.push(trader2, orderId2);
        queue.push(trader3, orderId3);

        queue.removeOrder(orderId2);
        assertFalse(queue.orderExists(orderId2));
        assertEq(queue.orders[orderId1].next, orderId3);
        assertEq(queue.orders[orderId3].prev, orderId1);
    }

    //Eliminación de Órdenes Específicas (removeOrder): Eliminar la primera orden y verificar el cambio en el puntero first.
    function testRemoveOrderFirstQueue() public {
        queue.push(trader1, orderId1);
        queue.push(trader2, orderId2);

        queue.removeOrder(orderId1);
        assertFalse(queue.orderExists(orderId1));
        assertEq(queue.first,orderId2);
    }

    //Eliminación de Órdenes Específicas (removeOrder): Eliminar la última orden y verificar el cambio en el puntero last.
    function testRemoveOrderLastQueue() public {
        queue.push(trader1, orderId1);
        queue.push(trader2, orderId2);
        queue.push(trader3, orderId3);

        queue.removeOrder(orderId3);
        assertFalse(queue.orderExists(orderId3));
        assertEq(queue.last,orderId2);
    }

    //Eliminación de Órdenes Específicas (removeOrder): Intentar eliminar una orden de una cola vacía y esperar el error OrderQueue__CantRemoveFromAnEmptyQueue.
    function testRemoveOrderFromEmptyRevertsQueue() public {
        vm.expectRevert(OrderQueue.OrderQueue__CantRemoveFromAnEmptyQueue.selector);
        queue.removeOrder(orderId1);
    }

    //Eliminación de Órdenes Específicas (removeOrder): Eliminar multiples ordenes en una cola con múltiples elementos y verificar que se actualicen correctamente los punteros first y last.
    function testRemoveOrderMultipleRemovalsQueue() public {
        queue.push(trader1, orderId1);
        queue.push(trader2, orderId2);
        queue.push(trader3, orderId3);

        //Validar status
        assertEq(queue.first, orderId1, "First should be orderid1");
        assertEq(queue.last, orderId3, "Last should orderid3");
        assertEq(queue.orders[orderId1].next, orderId2, "Next pointer of the first node should point to the second");
        assertEq(queue.orders[orderId2].next, orderId3, "Next pointer of the second node should point to the third");
        assertEq(queue.orders[orderId2].prev, orderId1, "Prev pointer of the second node should point to the first");
        assertEq(queue.orders[orderId3].prev, orderId2, "Prev pointer of the third node should point to the second");

        queue.removeOrder(orderId2);

        //Valido status
        assertEq(queue.first, orderId1, "First should be orderid1 after removing second order");
        assertEq(queue.last, orderId3, "Last should orderid3 after removing second order");
        assertFalse(queue.orderExists(orderId2));
        assertEq(queue.orders[orderId1].next, orderId3, "Next pointer of the first node should point to the second after removing second order");
        assertEq(queue.orders[orderId3].prev, orderId1, "Prev pointer of the second node should point to the first after removing second order");

        queue.removeOrder(orderId3);

        //Valido status
        assertEq(queue.first, orderId1, "First should be orderid1 after removing third order");
        assertEq(queue.last, orderId1, "Last should orderid1 after removing third order");
        assertFalse(queue.orderExists(orderId3));
        assertEq(queue.orders[orderId1].next, 0, "Next pointer of the first node should point to the second after removing third order");

        queue.removeOrder(orderId1);
        assertFalse(queue.orderExists(orderId1));
        assertEq(queue.first, 0, "First should be 0 after removing all orders");
        assertEq(queue.first, 0, "Last should be 0 after removing all orders");
    }
}
