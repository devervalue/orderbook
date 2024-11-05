// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/QueueLib.sol";
import "../src/RedBlackTreeLib.sol";
import "forge-std/console.sol";

contract RedBlackTreeLibTest is Test {
    using RedBlackTreeLib for RedBlackTreeLib.Tree;

    RedBlackTreeLib.Tree private tree;

    uint256 constant EMPTY = 0;

    address private trader1 = address(1);
    address private trader2 = address(2);
    address private trader3 = address(3);
    address private trader4 = address(4);
    address private trader5 = address(5);

    bytes32 private orderId1 = keccak256(abi.encodePacked(trader1, "buy", "100", block.timestamp));
    bytes32 private orderId2 = keccak256(abi.encodePacked(trader2, "sell", "200", block.timestamp));
    bytes32 private orderId3 = keccak256(abi.encodePacked(trader3, "buy", "300", block.timestamp));
    bytes32 private orderId4 = keccak256(abi.encodePacked(trader4, "buy", "400", block.timestamp));
    bytes32 private orderId5 = keccak256(abi.encodePacked(trader4, "sell", "500", block.timestamp));

    function setUp() public {
        // Setup inicial para las pruebas
    }

    //-------------------- FIRST ------------------------------

    //Cuando el arbol esta vacio
    function testFirstOnEmptyTree() public {
        uint256 result = tree.first();
        assertEq(result, 0, "Should return 0 for an empty tree");
    }

    //Cuando el arbol tiene un solo nodo deberia retornar el unico nodo que existe
    function testFirstOnSingleNodeTree() public {
        tree.insert(10);
        uint256 result = tree.first();
        assertEq(result, 10, "Should return the only node in the tree");
    }

    //Cuando se insertan varios nodos deberian retornar el nodo mas pequeño
    function testFirstOnTreeWithMultipleNodes() public {
        tree.insert(10);
        tree.insert(20);
        tree.insert(5);

        uint256 result = tree.first();
        assertEq(result, 5, "Should return the smallest value node after removal");
    }

    //Cuando un arbol tiene multiples nodos pero no tiene un nodo izquierdo
    function testFirstOnTreeWithNoLeftNodes() public {
        tree.insert(20);
        tree.insert(30);

        uint256 result = tree.first();
        assertEq(result, 20, "Should return the first node when there are no left children");
    }

    //-------------------- LAST ------------------------------

    //Verifica que la función devuelve 0 si el árbol está vacío
    function testLastOnEmptyTree() public {
        uint256 result = tree.last();
        assertEq(result, 0, "Should return 0 for an empty tree");
    }

    //Verifica que la función devuelve el valor del único nodo si el árbol contiene solo uno.
    function testLastOnSingleNodeTree() public {
        tree.insert(10);
        uint256 result = tree.last();
        assertEq(result, 10, "Should return the only node in the tree");
    }

    //Crea un árbol sesgado a la izquierda y verifica que la función devuelve el valor correcto
    function testLastWithLeftHeavyTree() public {
        // Create a left-heavy tree
        tree.insert(30);
        tree.insert(25);
        tree.insert(20);

        uint256 result = tree.last();
        assertEq(result, 30, "Should return the last node with the highest value in a left-heavy tree");
    }

    //Crea un árbol sesgado a la derecha y verifica que la función devuelve el valor correcto.
    function testLastWithRightHeavyTree() public {
        // Create a right-heavy tree
        tree.insert(10);
        tree.insert(15);
        tree.insert(20);

        uint256 result = tree.last();
        assertEq(result, 20, "Should return the last node with the highest value in a right-heavy tree");
    }

    //Crea un árbol equilibrado y verifica que la función devuelve el valor del hijo derecho del nodo raíz.
    function testLastAfterInsertionsAndRemovals() public {
        tree.insert(10);
        tree.insert(30);
        tree.insert(20);
        tree.remove(20); // Remove the last node

        uint256 result = tree.last();
        assertEq(result, 30, "Should return the last node after removal of the last node");
    }

    //-------------------- NEXT ------------------------------

    //Verifica que la función revierte si se intenta obtener el siguiente valor desde un árbol vacío.
    function testNextOnEmptyTree() public {
        // Expecting a revert for trying to get next from an empty tree
        vm.expectRevert(RedBlackTreeLib.RBT__StartingValueCannotBeZero.selector);
        tree.next(EMPTY);
    }

    //Comprueba que no hay un siguiente nodo en un árbol con un solo nodo.
    function testNextOnSingleNodeTree() public {
        tree.insert(10);
        uint256 result = tree.next(10);
        assertEq(result, EMPTY, "Should return EMPTY when there is no next node");
    }
    //Verifica que se devuelve el hijo izquierdo más bajo si el nodo tiene un hijo derecho.

    function testNextOnNodeWithRightChild() public {
        tree.insert(10);
        tree.insert(15);
        tree.insert(20);

        uint256 result = tree.next(10);
        assertEq(result, 15, "Should return the next node (15) for the node (10)");
    }

    //Asegura que se devuelve el siguiente nodo correcto cuando no hay un hijo derecho.
    function testNextOnNodeWithoutRightChild() public {
        tree.insert(10);
        tree.insert(15);
        tree.insert(5);

        uint256 result = tree.next(10);
        assertEq(result, 15, "Should return the next node (15) for the node (10) with no right child");
    }

    //Verifica que se devuelva el siguiente nodo correcto desde un nodo hoja.
    function testNextOnLeafNode() public {
        tree.insert(10);
        tree.insert(15);
        tree.insert(20);

        uint256 result = tree.next(15); // 15 is a leaf node
        assertEq(result, 20, "Should return the next node (20) for the leaf node (15)");
    }

    //Comprueba el comportamiento en un árbol más complejo con múltiples nodos y relaciones padre-hijo.
    function testNextInComplexTree() public {
        // Build a more complex tree
        tree.insert(20);
        tree.insert(10);
        tree.insert(30);
        tree.insert(25);

        uint256 result = tree.next(20); // 20 has a right child (30)
        assertEq(result, 25, "Should return the next node (25) for the node (20)");
    }

    //-------------------- PREV ------------------------------
    //Verifica que la función revierte si se intenta obtener el nodo previo desde un árbol vacío.
    function testPrevOnEmptyTree() public {
        // Expecting a revert for trying to get previous from an empty tree
        vm.expectRevert(RedBlackTreeLib.RBT__StartingValueCannotBeZero.selector);
        tree.prev(EMPTY);
    }
    //Comprueba que no hay un nodo previo en un árbol con un solo nodo.

    function testPrevOnSingleNodeTree() public {
        tree.insert(10);
        uint256 result = tree.prev(10);
        assertEq(result, EMPTY, "Should return EMPTY when there is no previous node");
    }
    //Verifica que se devuelve el máximo valor del subárbol izquierdo si el nodo tiene un hijo izquierdo.

    function testPrevOnNodeWithLeftChild() public {
        tree.insert(20);
        tree.insert(15);
        tree.insert(10);

        uint256 result = tree.prev(20);
        assertEq(result, 15, "Should return the previous node (15) for the node (20)");
    }

    //Asegura que se devuelve el padre o el ancestro más cercano que sea un hijo derecho cuando no hay un hijo izquierdo.
    function testPrevOnNodeWithoutLeftChild() public {
        tree.insert(20);
        tree.insert(25);
        tree.insert(30);

        uint256 result = tree.prev(25);
        assertEq(result, 20, "Should return the previous node (20) for the node (25) with no left child");
    }

    //Verifica que se devuelve el nodo correcto para un nodo hoja.
    function testPrevOnLeafNode() public {
        tree.insert(10);
        tree.insert(5);
        tree.insert(1);

        uint256 result = tree.prev(5); // 5 is a leaf node
        assertEq(result, 1, "Should return the previous node (1) for the leaf node (5)");
    }

    //Comprueba el comportamiento en un árbol más complejo con múltiples nodos y relaciones padre-hijo.
    function testPrevInComplexTree() public {
        // Build a more complex tree
        tree.insert(30);
        tree.insert(20);
        tree.insert(10);
        tree.insert(5);
        tree.insert(25);

        uint256 result = tree.prev(25); // 25 has a left child (20)
        assertEq(result, 20, "Should return the previous node (20) for the node (25)");
    }

    //Verifica que la función devuelve el nodo anterior correctamente para un nodo raíz.
    function testPrevOnRootNode() public {
        tree.insert(15);
        tree.insert(20);
        tree.insert(10);

        uint256 result = tree.prev(15); // 15 is the root node
        assertEq(result, 10, "Should return the previous node (10) for the root node (15)");
    }

    //-------------------- EXISTS ------------------------------

    //Verifica que la función exists devuelve false cuando se consulta en un árbol vacío.
    function testExistsOnEmptyTree() public {
        bool result = tree.exists(10);
        assertFalse(result, "Should return false for any node in an empty tree");
    }

    //Verifica que la función devuelve true cuando se consulta por el único nodo presente en el árbol.
    function testExistsOnSingleNodeTree() public {
        tree.insert(10);
        bool result = tree.exists(10);
        assertTrue(result, "Should return true for the only node in the tree");
    }

    //Verifica que la función devuelve false cuando se consulta por un valor que no existe en el árbol.
    function testExistsOnNonExistingNode() public {
        tree.insert(10);
        bool result = tree.exists(20);
        assertFalse(result, "Should return false for a node that doesn't exist in the tree");
    }

    //Verifica que la función devuelve true cuando se consulta por el nodo raíz.
    function testExistsOnRootNode() public {
        tree.insert(15);
        bool result = tree.exists(15);
        assertTrue(result, "Should return true for the root node");
    }

    //Verifica que la función devuelve true cuando se consulta por un nodo hoja.
    function testExistsOnLeafNode() public {
        tree.insert(20);
        tree.insert(10);

        bool result = tree.exists(10); // 10 is a leaf node
        assertTrue(result, "Should return true for a leaf node");
    }

    //Verifica que la función devuelve true para un nodo intermedio en el árbol.
    function testExistsOnIntermediateNode() public {
        tree.insert(30);
        tree.insert(20);
        tree.insert(25);

        bool result = tree.exists(20); // 20 is an intermediate node
        assertTrue(result, "Should return true for an intermediate node");
    }

    //Comprueba que la función sigue devolviendo true para el nodo raíz en un árbol con múltiples nodos.
    function testExistsOnRootWithMultipleNodes() public {
        tree.insert(50);
        tree.insert(30);
        tree.insert(70);

        bool result = tree.exists(50); // 50 is the root
        assertTrue(result, "Should return true for the root node in a tree with multiple nodes");
    }

    //Verifica que la función devuelve true para un nodo que es padre pero no es la raíz.
    function testExistsOnNonRootParentNode() public {
        tree.insert(40);
        tree.insert(20);
        tree.insert(10);

        bool result = tree.exists(20); // 20 is a non-root parent node
        assertTrue(result, "Should return true for a non-root parent node");
    }

    //Verifica que la función devuelve false cuando se consulta por un valor EMPTY, que representa un valor inválido.
    function testExistsOnInvalidValue() public {
        bool result = tree.exists(EMPTY); // EMPTY is a predefined constant for invalid values
        assertFalse(result, "Should return false for EMPTY value");
    }

    //-------------------- GET NODE ------------------------------

    //Verifica que la función falla cuando se intenta obtener un nodo de un árbol vacío.
    function testGetNodeOnEmptyTree() public {
        vm.expectRevert(RedBlackTreeLib.RBT__ValuesDoesNotExist.selector);
        tree.getNode(10); // Intentar obtener un nodo en un árbol vacío debería fallar
    }

    //Verifica que la función falla cuando se intenta acceder a un nodo que no existe.
    function testGetNodeOnNonExistentNode() public {
        tree.insert(10);
        vm.expectRevert(RedBlackTreeLib.RBT__ValuesDoesNotExist.selector);
        tree.getNode(20); // Intentar obtener un nodo que no existe debería fallar
    }

    //Verifica que la función devuelve correctamente el nodo para un valor existente.
    function testGetNodeOnValidNode() public {
        tree.insert(10);

        RedBlackTreeLib.Node storage node = tree.getNode(10);
        //TODO VERIFICAR ESTOS CAMPOS
        //assertEq(node.countTotalOrders, 1, "Should have 1 total order in the node");
        //assertEq(node.countValueOrders, 1, "Should have value of 1 in the node");
        assertEq(node.parent, EMPTY, "Parent should be EMPTY for the root node");
        assertEq(node.left, EMPTY, "Left child should be EMPTY for a single node");
        assertEq(node.right, EMPTY, "Right child should be EMPTY for a single node");
    }

    //Verifica que la función devuelve correctamente los nodos después de insertar varios valores.
    function testGetNodeAfterInsertions() public {
        tree.insert(10);
        tree.insert(20);

        RedBlackTreeLib.Node storage node1 = tree.getNode(10);
        RedBlackTreeLib.Node storage node2 = tree.getNode(20);
        //TODO VERIFICAR ESTOS CAMPOS
        //assertEq(node1.countTotalOrders, 1, "Node 10 should have 1 total order");
        //assertEq(node2.countTotalOrders, 1, "Node 20 should have 1 total order");
        assertEq(node1.right, 20, "Node 10 should have Node 20 as right child");
        assertEq(node2.parent, 10, "Node 20 should have Node 10 as parent");
    }

    //Verifica que la función falla cuando se pasa un valor inválido (por ejemplo, EMPTY).
    function testGetNodeOnInvalidValue() public {
        vm.expectRevert(RedBlackTreeLib.RBT__ValuesDoesNotExist.selector);
        tree.getNode(EMPTY); // Intentar obtener un nodo con un valor inválido debería fallar
    }

    //Verifica que la función falla después de eliminar un nodo del árbol.
    function testGetNodeAfterRemovingNode() public {
        tree.insert(10);

        tree.remove(10); // Supongamos que tienes una función para eliminar nodos

        vm.expectRevert(RedBlackTreeLib.RBT__ValuesDoesNotExist.selector);
        tree.getNode(10); // Intentar obtener un nodo eliminado debería fallar
    }

    //Verifica que la función devuelve correctamente el nodo cuando tiene múltiples órdenes asociadas.
    function testGetNodeWithMultipleOrders() public {
        bytes32 key1 = keccak256("order1");
        bytes32 key2 = keccak256("order2");

        tree.insert(10);
        tree.insert(10);

        RedBlackTreeLib.Node storage node = tree.getNode(10);
        //TODO VERIFICAR ESTOS CAMPOS
        assertEq(node.right, 0, "Node 10 should have Node 0 as right child");
        //assertEq(node.countTotalOrders, 2, "Node should have 2 total orders");
        //assertEq(node.countValueOrders, 201, "Node should have sum of order values equal to 201");
    }

    //Verifica la estructura del árbol después de insertar varios nodos para formar un árbol balanceado.
    function testGetNodeOnBalancedTree() public {
        tree.insert(10);
        tree.insert(20);
        tree.insert(5);

        RedBlackTreeLib.Node storage nodeRoot = tree.getNode(10);
        RedBlackTreeLib.Node storage nodeLeft = tree.getNode(5);
        RedBlackTreeLib.Node storage nodeRight = tree.getNode(20);

        assertEq(nodeRoot.left, 5, "Root node should have Node 5 as left child");
        assertEq(nodeRoot.right, 20, "Root node should have Node 20 as right child");
        assertEq(nodeLeft.parent, 10, "Node 5 should have Node 10 as parent");
        assertEq(nodeRight.parent, 10, "Node 20 should have Node 10 as parent");
    }

    //-------------------- INSERT ------------------------------

    //Inserta el primer nodo en el árbol y verifica que se convierte en la raíz.
    function testInsertFirstNode() public {
        tree.insert(10);

        //uint256 root = tree.root();
        //assertEq(root, 10, "Root should be the first inserted node");

        RedBlackTreeLib.Node storage node = tree.getNode(10);
        assertEq(node.parent, EMPTY, "Root node should have no parent");
        assertEq(node.left, EMPTY, "Root node should have no left child");
        assertEq(node.right, EMPTY, "Root node should have no right child");
        //assertEq(node.countTotalOrders, 1, "Node should have 1 order");
        //assertEq(node.countValueOrders, 100, "Order value should be 100");
    }

    //Inserta un segundo nodo y verifica la estructura correcta del árbol.
    function testInsertSecondNode() public {
        tree.insert(10);
        tree.insert(20);

        //uint256 root = tree.root();
        //assertEq(root, 10, "Root should remain as 10");

        RedBlackTreeLib.Node storage node1 = tree.getNode(10);
        RedBlackTreeLib.Node storage node2 = tree.getNode(20);

        assertEq(node1.right, 20, "Node 10 should have Node 20 as the right child");
        assertEq(node2.parent, 10, "Node 20 should have Node 10 as its parent");
        assertEq(node2.left, EMPTY, "Node 20 should have no left child");
        assertEq(node2.right, EMPTY, "Node 20 should have no right child");
    }

    //Verifica que no se puede insertar un nodo con el mismo valor y clave.
    function testInsertDuplicateKey() public {
        tree.insert(10);
        //vm.expectRevert(RedBlackTreeLib.RedBlackTreeLib__ValueAndKeyPairExists.selector);
        tree.insert(10); // Intentar insertar con la misma clave y valor
    }

    //Inserta varios nodos y verifica que se colocan en las posiciones correctas en el árbol.
    function testInsertMultipleNodes() public {
        tree.insert(10);
        tree.insert(20);
        tree.insert(5);

        RedBlackTreeLib.Node storage node1 = tree.getNode(10);
        RedBlackTreeLib.Node storage node2 = tree.getNode(20);
        RedBlackTreeLib.Node storage node3 = tree.getNode(5);

        assertEq(node1.left, 5, "Node 10 should have Node 5 as the left child");
        assertEq(node1.right, 20, "Node 10 should have Node 20 as the right child");
        assertEq(node2.parent, 10, "Node 20 should have Node 10 as its parent");
        assertEq(node3.parent, 10, "Node 5 should have Node 10 as its parent");
    }

    //Verifica que intentar insertar un valor igual a 0 produce un error.
    function testInsertZeroValue() public {
        vm.expectRevert(RedBlackTreeLib.RBT__ValueToInsertCannotBeZero.selector);
        tree.insert(0); // Insertar un valor igual a 0 debería fallar
    }

    //Inserta nodos para crear un árbol más equilibrado y verifica la estructura.
    function testInsertBalancedTree() public {
        bytes32 key1 = keccak256("order1");
        bytes32 key2 = keccak256("order2");
        bytes32 key3 = keccak256("order3");
        bytes32 key4 = keccak256("order4");
        bytes32 key5 = keccak256("order5");

        tree.insert(10);
        tree.insert(20);
        tree.insert(5);
        tree.insert(15);
        tree.insert(25);

        RedBlackTreeLib.Node storage node1 = tree.getNode(10);
        RedBlackTreeLib.Node storage node2 = tree.getNode(20);
        RedBlackTreeLib.Node storage node3 = tree.getNode(5);
        RedBlackTreeLib.Node storage node4 = tree.getNode(15);
        RedBlackTreeLib.Node storage node5 = tree.getNode(25);

        // Verifica la estructura del árbol
        assertEq(node1.left, 5, "Node 10 should have Node 5 as left child");
        assertEq(node1.right, 20, "Node 10 should have Node 20 as right child");
        assertEq(node2.left, 15, "Node 20 should have Node 15 as left child");
        assertEq(node2.right, 25, "Node 20 should have Node 25 as right child");
    }

    //Verifica que la función insertFixup balancea correctamente el árbol.
    function testInsertFixup() public {
        // Prueba específica para verificar que la función `insertFixup` balancea correctamente el árbol.
        tree.insert(10);
        tree.insert(20);
        tree.insert(5);

        RedBlackTreeLib.Node storage node1 = tree.getNode(10);
        RedBlackTreeLib.Node storage node2 = tree.getNode(20);
        RedBlackTreeLib.Node storage node3 = tree.getNode(5);

        assertEq(node1.red, false, "Root node should be black after fixup");
        assertEq(node2.red, true, "Node 20 should be red");
        assertEq(node3.red, true, "Node 5 should be red");
    }

    //-------------------- REMOVE ------------------------------

    //Inserta y luego elimina un nodo único, verificando que el árbol está vacío.
    function testRemoveSingleNode() public {
        tree.insert(10);
        RedBlackTreeLib.Node storage node = tree.getNode(10);
        assertEq(node.parent, EMPTY, "Root node should have no parent");
        assertEq(node.left, EMPTY, "Root node should have no left child");
        assertEq(node.right, EMPTY, "Root node should have no right child");
        //assertEq(node.countTotalOrders, 1, "Node should have 1 order");
        //assertEq(node.countValueOrders, 100, "Order value should be 100");
        // Verificar que el nodo ha sido insertado
        uint256 root = tree.root;
        assertEq(root, 10, "Root should be 10");

        // Remover el nodo
        tree.remove(10);
        vm.expectRevert(RedBlackTreeLib.RBT__ValuesDoesNotExist.selector);
        tree.getNode(10); // Intentar obtener un nodo en un árbol vacío debería fallar
    }

    //Intenta eliminar un nodo que no existe, lo cual debería generar un error.
    function testRemoveNonExistentNode() public {
        // Intentar eliminar un nodo que no existe
        vm.expectRevert(RedBlackTreeLib.RBT__NodeDoesNotExist.selector);
        tree.remove(10);
    }

    //Inserta dos nodos y elimina un nodo hoja (sin hijos).
    function testRemoveLeafNode() public {
        // Insertar dos nodos
        tree.insert(10);
        tree.insert(20);

        // Verificar que los nodos fueron insertados
        uint256 root = tree.root;
        assertEq(root, 10, "Root should be 10");

        // Remover el nodo hoja (20)
        tree.remove(20);

        // Verificar que el nodo raíz sigue siendo 10 y que 20 ha sido eliminado
        root = tree.root;
        assertEq(root, 10, "Root should remain 10");
        assertEq(tree.getNode(10).right, EMPTY, "Right child of root should be empty");
    }

    //Elimina un nodo que tiene un único hijo.
    function testRemoveNodeWithOneChild() public {
        // Insertar dos nodos
        tree.insert(10);
        tree.insert(5);

        // Verificar que el nodo 10 tiene un hijo izquierdo
        RedBlackTreeLib.Node storage node = tree.getNode(10);
        assertEq(node.left, 5, "Node 10 should have 5 as left child");

        // Remover el nodo con un hijo (10)
        tree.remove(10);

        // Verificar que el nodo 5 ahora es la raíz
        uint256 root = tree.root;
        assertEq(root, 5, "Root should be 5 after removing 10");
    }

    //Elimina un nodo con dos hijos, verificando que el árbol se ajusta correctamente.
    function testRemoveNodeWithTwoChildren() public {
        // Insertar tres nodos
        tree.insert(10);
        tree.insert(5);
        tree.insert(20);

        // Verificar que el nodo 10 tiene hijos
        RedBlackTreeLib.Node storage node = tree.getNode(10);
        assertEq(node.left, 5, "Node 10 should have 5 as left child");
        assertEq(node.right, 20, "Node 10 should have 20 as right child");

        // Remover el nodo con dos hijos (10)
        tree.remove(10);

        // Verificar que 20 ahora es la raíz y 5 es el hijo izquierdo
        uint256 root = tree.root;
        assertEq(root, 20, "Root should be 20 after removing 10");
        node = tree.getNode(20);
        assertEq(node.left, 5, "Node 20 should have 5 as left child");
    }

    //Inserta varias órdenes en un nodo, elimina órdenes individualmente, y luego elimina el nodo cuando se quedan sin órdenes.
    function testRemoveRootNodeWithMultipleOrders() public {
        // Insertar dos órdenes en el mismo nodo
        tree.insert(10);
        tree.insert(20);

        // Verificar que hay dos órdenes en el nodo 10
        RedBlackTreeLib.Node storage node = tree.getNode(10);
        //assertEq(node.countTotalOrders, 2, "Node should have 2 orders");
        //assertEq(node.countValueOrders, 300, "Node should have total value orders of 300");

        // Remover una de las órdenes
        tree.remove(10);

        // Verificar que el nodo sigue existiendo pero con una orden menos
        node = tree.getNode(20);
        //assertEq(node.countTotalOrders, 1, "Node should now have 1 order");
        //assertEq(node.countValueOrders, 200, "Node should now have total value orders of 200");

        // Remover la segunda orden, lo que debería eliminar el nodo por completo
        tree.remove(20);

        // Verificar que el árbol está vacío
        uint256 root = tree.root;
        assertEq(root, EMPTY, "Tree should be empty after removing all orders from root");
    }

    //Verifica que el árbol sigue siendo válido después de una eliminación, especialmente revisando las propiedades del árbol Red-Black.
    function testRemoveFixup() public {
        // Insertar tres nodos
        tree.insert(10);
        tree.insert(5);
        tree.insert(20);

        // Eliminar el nodo raíz (10)
        tree.remove(10);

        // Verificar que el árbol sigue siendo un árbol Red-Black válido
        uint256 root = tree.root;
        assertEq(root, 20, "Root should be 20 after removing 10");
        RedBlackTreeLib.Node storage node = tree.getNode(root);
        assertEq(node.red, false, "Root node should be black after removal");
        assertEq(node.left, 5, "New root should have 5 as left child");
        assertEq(node.right, 0, "New root should have 0 as right child");
    }

    function testRemoveFixup2() public {
        // Insertar tres nodos
        tree.insert(10);
        tree.insert(5);
        tree.insert(20);
        tree.insert(25);

        // Eliminar el nodo raíz (10)
        tree.remove(10);

        // Verificar que el árbol sigue siendo un árbol Red-Black válido
        uint256 root = tree.root;
        assertEq(root, 20, "Root should be 20 after removing 10");
        RedBlackTreeLib.Node storage node = tree.getNode(root);
        assertEq(node.red, false, "Root node should be black after removal");
        assertEq(node.left, 5, "New root should have 5 as left child");
        assertEq(node.right, 25, "New root should have 25 as right child");
    }

    function testRemoveRedLeafNode() public {
        // Case 1: Removing a red leaf node
        tree.insert(10);
        tree.insert(5);
        tree.insert(15);
        tree.insert(3);

        // Verify initial structure
        assertEq(tree.root, 10);
        assertEq(tree.nodes[10].left, 5);
        assertEq(tree.nodes[10].right, 15);
        assertEq(tree.nodes[5].left, 3);

        // Remove the leaf node 3
        tree.remove(3);

        // Verify the structure after removal
        assertEq(tree.root, 10);
        assertEq(tree.nodes[10].left, 5);
        assertEq(tree.nodes[10].right, 15);
        assertEq(tree.nodes[5].left, 0); // 0 represents EMPTY
        assertTrue(tree.nodes[10].red == false);
        assertTrue(tree.nodes[5].red == false);
        assertTrue(tree.nodes[15].red == false);
    }

    function testRemoveBlackNodeWithOneChildren() public {
        // Case 2: Removing a black node with one child
        tree.insert(10);
        tree.insert(5);
        tree.insert(15);
        tree.insert(3);

        // Verify initial structure
        assertEq(tree.root, 10);
        assertEq(tree.nodes[10].left, 5);
        assertEq(tree.nodes[5].left, 3);

        // Remove node 5 (black node with one red child)
        tree.remove(5);

        // Verify the structure after removal
        assertEq(tree.root, 10);
        assertTrue(tree.nodes[10].left == 3);
        assertTrue(tree.nodes[10].red == false);
        assertTrue(tree.nodes[3].red == false);
        assertTrue(tree.nodes[15].red == false);
    }

    function testRemoveBlackNodeWithTwoChildren() public {
        // Case 2: Removing a black node with one child
        tree.insert(10);
        tree.insert(5);
        tree.insert(15);
        tree.insert(3);
        tree.insert(7);

        // Verify initial structure
        assertEq(tree.root, 10);
        assertEq(tree.nodes[10].left, 5);
        assertEq(tree.nodes[5].left, 3);
        assertEq(tree.nodes[5].right, 7);

        // Remove node 5 (black node with one red child)
        tree.remove(5);

        // Verify the structure after removal
        assertEq(tree.root, 10);
        assertTrue(tree.nodes[10].left == 3 || tree.nodes[10].left == 7);
        assertTrue(tree.nodes[10].red == false);
        assertTrue(tree.nodes[3].red == true);
        assertTrue(tree.nodes[7].red == false);
        assertTrue(tree.nodes[15].red == false);
    }

    function testBasicLeftRotation() public {
        tree.insert(5);
        tree.insert(7);

        // Perform left rotation on 5
        // Note: Since rotateLeft is private, we'll need to trigger it indirectly
        // This could be done by inserting more nodes or removing nodes to cause rebalancing
        tree.insert(8);

        // Assert the new structure
        assertEq(tree.root, 7);
        assertEq(tree.getNode(7).left, 5);
        assertEq(tree.getNode(7).right, 8);
    }

    function testLeftRotationWithNonEmptyCursorLeft() public {
        tree.insert(10);
        tree.insert(5);
        tree.insert(20);
        tree.insert(15);
        tree.insert(25);
        tree.insert(28);
        tree.insert(30);

        // Trigger rotation
        tree.insert(35);

        // Assert the new structure
        assertEq(tree.root, 20);
        assertEq(tree.getNode(20).left, 10);
        assertEq(tree.getNode(20).right, 28);
        assertEq(tree.getNode(10).right, 15);
    }

    function testLeftRotationOnRoot() public {
        tree.insert(5);
        tree.insert(7);

        // Trigger rotation
        tree.insert(8);

        // Assert the new root
        assertEq(tree.root, 7);
    }

    function testLeftRotationOnLeftChild() public {
        tree.insert(20);
        tree.insert(5);
        tree.insert(25);

        // Trigger rotation
        tree.insert(10);
        tree.insert(15);


        // Assert the new structure
        assertEq(tree.getNode(10).left, 5);
        assertEq(tree.getNode(10).right, 15);
        assertEq(tree.getNode(20).left, 10);
    }

    function testLeftRotationOnRightChild() public {
        tree.insert(20);
        tree.insert(5);
        tree.insert(25);

        // Trigger rotation
        tree.insert(30);
        tree.insert(35);


        // Assert the new structure
        assertEq(tree.getNode(20).right, 30);
        assertEq(tree.getNode(30).right, 35);
        assertEq(tree.getNode(30).left, 25);
    }

    function testBasicRightRotation() public {
        tree.insert(7);
        tree.insert(5);

        // Trigger rotation
        tree.insert(3);

        // Assert the new structure
        assertEq(tree.root, 5);
        assertEq(tree.getNode(5).left, 3);
        assertEq(tree.getNode(5).right, 7);
    }

    function testRightRotationWithNonEmptyCursorRight() public {
        tree.insert(35);
        tree.insert(20);
        tree.insert(30);
        tree.insert(25);


        tree.insert(15);
        tree.insert(10);
        tree.insert(5);

        // Trigger rotation
        tree.insert(2);

        // Assert the new structure
        assertEq(tree.root, 20);
        assertEq(tree.getNode(20).left, 10);
        assertEq(tree.getNode(20).right, 30);
        assertEq(tree.getNode(30).left, 25);
    }

    function testRightRotationOnRoot() public {
        tree.insert(7);
        tree.insert(5);

        // Trigger rotation
        tree.insert(3);

        // Assert the new root
        assertEq(tree.root, 5);
    }

    function testRightRotationOnRightChild() public {
        tree.insert(5);
        tree.insert(10);
        tree.insert(20);
        tree.insert(15);

        // Trigger rotation
        tree.insert(13);

        // Assert the new structure
        assertEq(tree.getNode(10).right, 15);
        assertEq(tree.getNode(15).left, 13);
        assertEq(tree.getNode(15).right, 20);
    }

    function testRightRotationOnLeftChild() public {
        tree.insert(20);
        tree.insert(25);
        tree.insert(30);
        tree.insert(10);

        // Trigger rotation
        tree.insert(5);

        // Assert the new structure
        assertEq(tree.getNode(25).left, 10);
        assertEq(tree.getNode(10).left, 5);
        assertEq(tree.getNode(10).right, 20);
    }

    function testComplexTreeStructureLeftRotation() public {
        tree.insert(10);
        tree.insert(5);
        tree.insert(15);
        tree.insert(3);
        tree.insert(7);
        tree.insert(12);
        tree.insert(17);
        tree.insert(6);
        tree.insert(8);

        // Trigger rotation on 5
        tree.insert(9);

        // Assert the new structure
        assertEq(tree.getNode(10).left, 8);
        assertEq(tree.getNode(7).left, 5);
        assertEq(tree.getNode(7).right, 10);
        assertEq(tree.getNode(8).right, 9);
    }

    function testComplexTreeStructureRightRotation() public {
        tree.insert(10);
        tree.insert(5);
        tree.insert(15);
        tree.insert(3);
        tree.insert(7);
        tree.insert(12);
        tree.insert(17);
        tree.insert(13);
        tree.insert(14);

        // Trigger rotation on 15
        tree.insert(11);

        // Assert the new structure
        assertEq(tree.getNode(13).right, 15);
        assertEq(tree.getNode(15).left, 14);
        assertEq(tree.getNode(15).right, 17);
        assertEq(tree.getNode(10).right, 12);
    }

    function testRotationAfterRemoval() public {
        tree.insert(10);
        tree.insert(5);
        tree.insert(15);
        tree.insert(3);
        tree.insert(7);
        tree.remove(3);

        // Trigger rotation
        tree.insert(4);

        // Assert the new structure
        assertEq(tree.getNode(10).left, 5);
        assertEq(tree.getNode(5).left, 4);
        assertEq(tree.getNode(5).right, 7);
    }

    // Helper functions
    function assertNodeColor(uint256 value, bool expectedRed) internal {
        assertEq(tree.nodes[value].red, expectedRed);
    }


    // Test scenarios
    function testRemoveBlackLeafWithRedSibling() public {
        // Scenario 1
        tree.insert(10);
        tree.insert(5);
        tree.insert(15);
        tree.insert(3);
        tree.insert(7);

        assertNodeColor(10, false);
        assertNodeColor(5, false);
        assertNodeColor(15, false);
        assertNodeColor(3, true);
        assertNodeColor(7, true);

        tree.remove(3);


        assertEq(tree.nodes[10].left,5);
        assertEq(tree.nodes[10].right,15);
        assertEq(tree.nodes[5].right,7);
        assertNodeColor(10, false);
        assertNodeColor(5, false);
        assertNodeColor(15, false);
        assertNodeColor(7, true);
    }

    function testRemoveBlackNodeWithTwoBlackNephews() public {
        // Scenario 2
        tree.insert(10);
        tree.insert(5);
        tree.insert(15);
        tree.insert(3);
        tree.insert(7);
        tree.insert(13);
        tree.insert(17);

        assertNodeColor(10, false);
        assertNodeColor(5, false);
        assertNodeColor(15, false);
        assertNodeColor(3, true);
        assertNodeColor(7, true);
        assertNodeColor(13, true);
        assertNodeColor(17, true);

        tree.remove(3);

        assertEq(tree.nodes[10].left,5);
        assertEq(tree.nodes[10].right,15);
        assertEq(tree.nodes[5].right,7);
        assertNodeColor(10, false);
        assertNodeColor(5, false);
        assertNodeColor(15, false);
        assertNodeColor(7, true);
        assertNodeColor(13, true);
        assertNodeColor(17, true);
    }

    function testRemoveBlackNodeSiblingFarChildBlackNearChildRed() public {
        // Scenario 3
        tree.insert(10);
        tree.insert(5);
        tree.insert(15);
        tree.insert(3);
        tree.insert(7);
        tree.insert(6);

        assertNodeColor(10, false);
        assertNodeColor(5, true);
        assertNodeColor(15, false);
        assertNodeColor(3, false);
        assertNodeColor(7, false);
        assertNodeColor(6, true);

        tree.remove(3);

        assertEq(tree.nodes[10].left,6);
        assertEq(tree.nodes[10].right,15);
        assertEq(tree.nodes[6].right,7);
        assertEq(tree.nodes[6].left,5);

        assertNodeColor(10, false);
        assertNodeColor(6, true);
        assertNodeColor(15, false);
        assertNodeColor(5, false);
        assertNodeColor(7, false);
    }

    function testRemoveBlackNodeSiblingBothChildrenRed() public {
        // Scenario 4
        tree.insert(10);
        tree.insert(5);
        tree.insert(15);
        tree.insert(3);
        tree.insert(7);
        tree.insert(6);
        tree.insert(8);

        assertNodeColor(10, false);
        assertNodeColor(5, true);
        assertNodeColor(15, false);
        assertNodeColor(3, false);
        assertNodeColor(7, false);
        assertNodeColor(6, true);
        assertNodeColor(8, true);

        tree.remove(3);

        assertEq(tree.nodes[10].left,7);
        assertEq(tree.nodes[7].right,8);
        assertEq(tree.nodes[7].left,5);
        assertEq(tree.nodes[5].right,6);

        assertNodeColor(10, false);
        assertNodeColor(7, true);
        assertNodeColor(15, false);
        assertNodeColor(5, false);
        assertNodeColor(8, false);
        assertNodeColor(6, true);
    }

    function testRemoveBlackNodeMultipleIterations() public {
        // Scenario 5
        tree.insert(10);
        tree.insert(5);
        tree.insert(15);
        tree.insert(3);
        tree.insert(7);
        tree.insert(13);
        tree.insert(17);
        tree.insert(1);
        tree.insert(4);


        assertNodeColor(10, false);
        assertNodeColor(5, true);
        assertNodeColor(15, false);
        assertNodeColor(3, false);
        assertNodeColor(7, false);
        assertNodeColor(13, true);
        assertNodeColor(17, true);
        assertNodeColor(1, true);
        assertNodeColor(4, true);

        tree.remove(13);

        assertEq(tree.nodes[10].left,5);
        assertEq(tree.nodes[10].right,15);
        assertEq(tree.nodes[15].left,0);
        assertEq(tree.nodes[15].right,17);

        assertNodeColor(10, false);
        assertNodeColor(5, true);
        assertNodeColor(15, false);
        assertNodeColor(3, false);
        assertNodeColor(7, false);
        assertNodeColor(17, true);
        assertNodeColor(1, true);
        assertNodeColor(4, true);
    }

    function testRemoveBlackLeftChild() public {
        // Scenario 6 (using tree from scenario 5)
        tree.insert(10);
        tree.insert(5);
        tree.insert(15);
        tree.insert(3);
        tree.insert(7);
        tree.insert(13);
        tree.insert(17);
        tree.insert(1);
        tree.insert(4);

        tree.remove(3);

        assertEq(tree.nodes[10].left,5);
        assertEq(tree.nodes[10].right,15);
        assertEq(tree.nodes[15].left,13);
        assertEq(tree.nodes[15].right,17);
        assertEq(tree.nodes[5].left,4);
        assertEq(tree.nodes[4].left,1);

        assertNodeColor(10, false);
        assertNodeColor(5, true);
        assertNodeColor(15, false);
        assertNodeColor(7, false);
        assertNodeColor(17, true);
        assertNodeColor(13, true);
        assertNodeColor(1, true);
        assertNodeColor(4, false);
    }

    function testRemoveBlackRightChild() public {
        // Scenario 7 (using tree from scenario 5)
        tree.insert(10);
        tree.insert(5);
        tree.insert(15);
        tree.insert(3);
        tree.insert(7);
        tree.insert(13);
        tree.insert(17);
        tree.insert(1);
        tree.insert(4);

        assertEq(tree.nodes[10].left,5);
        assertEq(tree.nodes[10].right,15);
        assertEq(tree.nodes[15].left,13);
        assertEq(tree.nodes[15].right,17);
        assertEq(tree.nodes[5].left,3);
        assertEq(tree.nodes[3].left,1);
        assertEq(tree.nodes[3].left,1);
        assertEq(tree.nodes[3].right,4);

        tree.remove(7);

        assertEq(tree.nodes[10].left,3);
        assertEq(tree.nodes[10].right,15);
        assertEq(tree.nodes[15].left,13);
        assertEq(tree.nodes[15].right,17);
        assertEq(tree.nodes[3].right,5);
        assertEq(tree.nodes[3].left,1);
        assertEq(tree.nodes[5].left,4);

        assertNodeColor(10, false);
        assertNodeColor(5, false);
        assertNodeColor(15, false);
        assertNodeColor(7, false);
        assertNodeColor(17, true);
        assertNodeColor(13, true);
        assertNodeColor(3, true);
        assertNodeColor(4, true);
    }

    function testRemoveNodeFixRoot() public {
        // Scenario 8
        tree.insert(10);
        tree.insert(5);
        tree.insert(15);

        assertNodeColor(10, false);
        assertNodeColor(5, true);
        assertNodeColor(15, true);

        tree.remove(10);


        assertNodeColor(5, true);
        assertNodeColor(15, false);
    }

    function testNextWithRightChildNoLeftDescendant() public {
        // 1. Create a tree with at least three nodes
        tree.insert(10);
        tree.insert(5);
        tree.insert(15);

        // 2. Set up the tree so that one node has a right child,
        // but that right child doesn't have any left descendants
        tree.insert(20);

        // The tree should now look like this:
        //       10
        //      /  \
        //     5    15
        //           \
        //            20

        // 3. Call the next function on the parent of this right child
        uint256 nextValue = tree.next(15);

        // 4. Verify that the function correctly returns the right child as the next node
        assertEq(nextValue, 20, "Next value after 15 should be 20");

        // Additional test to ensure the structure is correct
        assertEq(tree.next(10), 15, "Next value after 10 should be 15");
        assertEq(tree.next(5), 10, "Next value after 5 should be 10");
        assertEq(tree.next(20), 0, "Next value after 20 should be 0 (EMPTY)");
    }

    function testRemoveNodeWithLeftChildNoRightChild() public {
        // 1. Create a tree with at least three nodes
        tree.insert(10);
        tree.insert(5);
        tree.insert(15);

        // 2. Set up the tree so that the node to be removed has a left child but no right child
        tree.insert(3);

        // The tree should now look like this:
        //       10
        //      /  \
        //     5   15
        //    /
        //   3

        // Verify initial structure
        assertEq(tree.nodes[10].left, 5);
        assertEq(tree.nodes[10].right, 15);
        assertEq(tree.nodes[5].left, 3);
        assertEq(tree.nodes[5].right, 0); // No right child

        // 3. Call the remove function on the node with only a left child (5)
        tree.remove(5);

        // 4. Verify that the function correctly replaces the removed node with its left child
        assertEq(tree.nodes[10].left, 3, "Node 5 should be replaced by its left child 3");
        assertEq(tree.nodes[10].right, 15, "Right child of root should still be 15");
        assertEq(tree.nodes[3].left, 0, "Node 3 should not have a left child");
        assertEq(tree.nodes[3].right, 0, "Node 3 should not have a right child");

        // Additional checks to ensure the tree structure is correct
        assertEq(tree.first(), 3, "First (smallest) node should be 3");
        assertEq(tree.last(), 15, "Last (largest) node should be 15");
        assertEq(tree.next(3), 10, "Next node after 3 should be 10");
        assertEq(tree.next(10), 15, "Next node after 10 should be 15");
        assertEq(tree.next(15), 0, "Next node after 15 should be 0 (EMPTY)");

        // Check colors to ensure Red-Black properties are maintained
        assertNodeColor(10, false);
        assertNodeColor(3, false);
        assertNodeColor(15, false);
    }

    function testRemoveEmptyNode() public {
        tree.insert(10);
        tree.insert(20);

        // Try to remove a node that doesn't exist
        vm.expectRevert(RedBlackTreeLib.RBT__ValueCannotBeZero.selector);
        tree.remove(0);
    }

    function testRemoveNodeWithTwoChildren2() public {
        tree.insert(50);
        tree.insert(30);
        tree.insert(70);
        tree.insert(20);
        tree.insert(40);
        tree.insert(60);
        tree.insert(80);

        // Remove the root node (50), which has both left and right children
        tree.remove(50);

        // Verify the new structure
        assertTrue(!tree.exists(50));
        assertTrue(tree.exists(60)); // 60 should replace 50 as the new root
        assertTrue(tree.root == 60); // 60 should replace 50 as the new root
        // Add more assertions to verify the new tree structure
    }

    function testReplaceParentScenarios() public {

        // Setup: Create a simple tree
        tree.insert( 50);
        tree.insert( 25);
        tree.insert( 75);
        tree.insert( 12);
        tree.insert( 37);
        tree.insert( 62);
        tree.insert( 87);

        // Scenario 1: Replace a non-root node (left child)
        // Removing 25 will cause 37 to replace it, triggering replaceParent
        tree.remove( 25);
        assert(tree.nodes[50].left == 37);
        assert(tree.nodes[37].parent == 50);

        // Scenario 2: Replace a non-root node (right child)
        // Removing 75 will cause 87 to replace it, triggering replaceParent
        tree.remove( 75);
        assert(tree.nodes[50].right == 87);
        assert(tree.nodes[87].parent == 50);

        // Scenario 3: Replace the root
        // Removing 50 will cause another node (likely 62) to become the new root
        uint256 oldRoot = tree.root;
        tree.remove(50);
        assert(tree.root != oldRoot);
        assert(tree.nodes[tree.root].parent == EMPTY);

        // Verify the structure after removals
        assert(tree.exists(12));
        assert(tree.exists(37));
        assert(tree.exists(62));
        assert(tree.exists(87));
        assert(!tree.exists(25));
        assert(!tree.exists(50));
        assert(!tree.exists(75));
    }

    function testNextIsTheLeftmostNodeInRightSubtree() public {
        // Scenario 7 (using tree from scenario 5)
        tree.insert(20);
        tree.insert(100);
        tree.insert(50);
        tree.insert(75);
        tree.insert(60);
        tree.insert(58);

        assertEq(tree.nodes[50].left,20);
        assertEq(tree.nodes[50].right,75);
        assertEq(tree.root,50);
        assertEq(tree.next(50),58);

    }

    function testRemoveFixupRightSideRedSibling() public {

        // Insert nodes to create a specific tree structure
        tree.insert( 50);
        tree.insert( 25);
        tree.insert( 75);
        tree.insert( 60);
        tree.insert( 80);
        tree.insert( 55);
        tree.insert( 65);

        // The tree should look like this:
        //       50B
        //     /     \
        //   25B     75R
        //          /   \
        //        60B   80B
        //       /  \
        //     55R  65R

        // Remove node 25, which will trigger the removeFixup function
        tree.remove( 25);

        // Verify the tree structure and colors after removal
        assertEq(tree.root, 75);
        assertNodeColor(75, false);// Root should be black

        assertEq(tree.nodes[75].left, 60);
        assertNodeColor(60, true);// Root-left should be red

        assertEq(tree.nodes[75].right, 80);
        assertNodeColor(80, false);// Root-left should be red


    }

    function testPrevIsTheRightmostNodeInLeftSubtree() public {
        // Scenario 7 (using tree from scenario 5)
        tree.insert(20);
        tree.insert(100);
        tree.insert(10);
        tree.insert(19);
        tree.insert(17);
        tree.insert(18);

        assertEq(tree.nodes[20].left,17);
        assertEq(tree.nodes[20].right,100);
        assertEq(tree.root,20);
        assertEq(tree.prev(20),19);

    }



}
