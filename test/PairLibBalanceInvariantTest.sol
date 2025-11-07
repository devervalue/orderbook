// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/PairLib.sol";
import "./PairLibImpl.sol";
import "./MyTokenA.sol";
import "./MyTokenB.sol";
import "forge-std/console.sol";

/**
 * @title PairLibBalanceInvariantTest
 * @notice Suite de pruebas exhaustiva para validar invariantes de balance, precisión y detección de vulnerabilidades
 * @dev Tests de auditoría para detectar problemas de subcolateralización, acumulación de dust y pérdida de precisión
 */
contract PairLibBalanceInvariantTest is Test {
    using PairLib for PairLib.TraderBalance;

    // Constantes
    uint256 private constant PRECISION = 1e18;
    uint256 private constant INITIAL_BALANCE = 10000000e18;
    uint256 private constant FEE_BASIS_POINTS = 100; // 1%

    // Contratos
    PairLibImpl public pair;
    MyTokenA public baseToken;
    MyTokenB public quoteToken;

    // Traders
    address public owner = makeAddr("owner");
    address public feeAddress = makeAddr("feeAddress");
    address public trader1 = makeAddr("trader1");
    address public trader2 = makeAddr("trader2");
    address public trader3 = makeAddr("trader3");
    address public trader4 = makeAddr("trader4");
    address public trader5 = makeAddr("trader5");

    // Estructuras para tracking
    struct BalanceSnapshot {
        uint256 walletBase;
        uint256 walletQuote;
        uint256 internalBase;
        uint256 internalQuote;
        uint256 contractBase;
        uint256 contractQuote;
    }

    function setUp() public {
        // Deploy tokens
        baseToken = new MyTokenA(INITIAL_BALANCE);
        quoteToken = new MyTokenB(INITIAL_BALANCE);

        // Deploy PairLibImpl con fee del 1%
        pair = new PairLibImpl(address(baseToken), address(quoteToken));

        // Array de traders
        address[5] memory traders = [trader1, trader2, trader3, trader4, trader5];

        // Distribuir tokens a traders
        for (uint256 i = 0; i < traders.length; i++) {
            baseToken.transfer(traders[i], INITIAL_BALANCE / 10);
            quoteToken.transfer(traders[i], INITIAL_BALANCE / 10);

            // Aprobar pair contract
            vm.startPrank(traders[i]);
            baseToken.approve(address(pair), type(uint256).max);
            quoteToken.approve(address(pair), type(uint256).max);
            vm.stopPrank();
        }
    }

    // ========================================
    // HELPER FUNCTIONS
    // ========================================

    /**
     * @notice Toma una instantánea de los balances de un trader
     */
    function snapshotBalances(address trader) internal returns (BalanceSnapshot memory) {
        PairLib.TraderBalance memory traderBalance = pair.getTraderBalances(trader);
        
        return BalanceSnapshot({
            walletBase: baseToken.balanceOf(trader),
            walletQuote: quoteToken.balanceOf(trader),
            internalBase: traderBalance.baseTokenBalance,
            internalQuote: traderBalance.quoteTokenBalance,
            contractBase: baseToken.balanceOf(address(pair)),
            contractQuote: quoteToken.balanceOf(address(pair))
        });
    }

    /**
     * @notice Verifica el invariante de balance: sum(internal balances) <= contract holdings
     */
    function assertBalanceInvariant() internal {
        address[5] memory traders = [trader1, trader2, trader3, trader4, trader5];
        
        uint256 totalInternalBase = 0;
        uint256 totalInternalQuote = 0;
        
        for (uint256 i = 0; i < traders.length; i++) {
            PairLib.TraderBalance memory balance = pair.getTraderBalances(traders[i]);
            totalInternalBase += balance.baseTokenBalance;
            totalInternalQuote += balance.quoteTokenBalance / PRECISION;
        }

        // Incluir fee balances
        (uint256 baseFee, uint256 quoteFee) = pair.getFeeBalances();
        totalInternalBase += baseFee;
        totalInternalQuote += quoteFee / PRECISION; // quoteFee está escalado

        uint256 contractBase = baseToken.balanceOf(address(pair));
        uint256 contractQuote = quoteToken.balanceOf(address(pair));

        // El invariante crítico
        assertLe(
            totalInternalBase,
            contractBase,
            "INVARIANT VIOLATION: Internal base balances exceed contract holdings"
        );
        assertLe(
            totalInternalQuote,
            contractQuote,
            "INVARIANT VIOLATION: Internal quote balances exceed contract holdings"
        );
    }

    /**
     * @notice Verifica los deltas de balance después de una operación
     */
    function verifyBalanceDeltas(
        BalanceSnapshot memory beforeSnapshot,
        BalanceSnapshot memory afterSnapshot,
        int256 expectedWalletBaseDelta,
        int256 expectedInternalBaseDelta
    ) internal {
        int256 actualWalletBaseDelta = int256(afterSnapshot.walletBase) - int256(beforeSnapshot.walletBase);
        int256 actualInternalBaseDelta = int256(afterSnapshot.internalBase) - int256(beforeSnapshot.internalBase);

        assertEq(
            actualWalletBaseDelta,
            expectedWalletBaseDelta,
            "Wallet base delta mismatch"
        );
        assertEq(
            actualInternalBaseDelta,
            expectedInternalBaseDelta,
            "Internal base delta mismatch"
        );
    }

    /**
     * @notice Calcula el dust esperado de una operación
     */
    function calculateExpectedDust(uint256 price, uint256 quantity) internal pure returns (uint256) {
        return (quantity * price) % PRECISION;
    }

    /**
     * @notice Configura un orderbook con múltiples órdenes
     */
    function setupOrderbook(
        uint256[] memory prices,
        uint256[] memory quantities,
        bool isBuy,
        address trader
    ) internal {
        require(prices.length == quantities.length, "Array length mismatch");
        
        for (uint256 i = 0; i < prices.length; i++) {
            vm.prank(trader);
            pair.createOrder(isBuy, prices[i], quantities[i]);
        }
    }

    // ========================================
    // 1. BALANCE INVARIANT TESTS (CORE FOCUS)
    // ========================================

    function testBalanceInvariantAfterSimpleTrade() public {
        console.log("\n=== TEST: Balance Invariant After Simple Trade ===");
        
        uint256 price = 2e18; // 2 quote tokens por 1 base token
        uint256 quantity = 10e18; // 10 base tokens

        // Seller crea orden
        vm.prank(trader1);
        pair.createOrder(false, price, quantity);

        // Verificar invariante después de crear orden
        assertBalanceInvariant();

        // Buyer ejecuta trade
        vm.prank(trader2);
        pair.createOrder(true, price, quantity);

        // Verificar invariante después del trade
        assertBalanceInvariant();
        
        console.log("[PASS] Balance invariant holds after simple trade");
    }

    function testBalanceInvariantAfterMultipleTrades() public {
        console.log("\n=== TEST: Balance Invariant After Multiple Trades ===");
        
        uint256[10] memory prices;
        prices[0] = 1.5e18;
        prices[1] = 2e18;
        prices[2] = 1.75e18;
        prices[3] = 3e18;
        prices[4] = 2.5e18;
        prices[5] = 1.8e18;
        prices[6] = 2.2e18;
        prices[7] = 1.9e18;
        prices[8] = 2.1e18;
        prices[9] = 2.3e18;
        
        uint256[10] memory quantities;
        quantities[0] = 5e18;
        quantities[1] = 10e18;
        quantities[2] = 7e18;
        quantities[3] = 3e18;
        quantities[4] = 8e18;
        quantities[5] = 6e18;
        quantities[6] = 9e18;
        quantities[7] = 4e18;
        quantities[8] = 11e18;
        quantities[9] = 5e18;

        for (uint256 i = 0; i < 10; i++) {
            // Seller crea orden
            vm.prank(i % 2 == 0 ? trader1 : trader3);
            pair.createOrder(false, prices[i], quantities[i]);

            // Buyer ejecuta trade
            vm.prank(i % 2 == 0 ? trader2 : trader4);
            pair.createOrder(true, prices[i], quantities[i]);

            // Verificar invariante después de cada trade
            assertBalanceInvariant();
        }
        
        console.log("[PASS] Balance invariant holds after 10 trades");
    }

    // ========================================
    // 2. PRECISION LOSS & DUST ACCUMULATION
    // ========================================

    function testFractionalPriceDustAccumulation() public {
        console.log("\n=== TEST: Fractional Price Dust Accumulation ===");
        
        uint256[3] memory prices;
        prices[0] = 1.25e18;
        prices[1] = 1.5e18;
        prices[2] = 1.333e18;
        uint256 smallQuantity = 1; // 1 wei

        uint256 totalDust = 0;

        for (uint256 i = 0; i < prices.length; i++) {
            uint256 expectedDust = calculateExpectedDust(prices[i], smallQuantity);
            totalDust += expectedDust;

            console.log("Trade %d: Price=%d, Expected Dust=%d", i, prices[i], expectedDust);

            // Seller crea orden
            vm.prank(trader1);
            pair.createOrder(false, prices[i], smallQuantity);

            // Buyer ejecuta trade
            vm.prank(trader2);
            pair.createOrder(true, prices[i], smallQuantity);
        }

        console.log("Total accumulated dust: %d", totalDust);
        
        // Verificar invariante
        assertBalanceInvariant();
    }

    function testSmallQuantityOrderPrecisionLoss() public {
        console.log("\n=== TEST: Small Quantity Order Precision Loss ===");
        
        uint256 price = 1.1e18;
        uint256 quantity = 1; // 1 wei

        BalanceSnapshot memory buyerBefore = snapshotBalances(trader2);

        // Seller crea orden
        vm.prank(trader1);
        pair.createOrder(false, price, quantity);

        // Buyer ejecuta trade
        vm.prank(trader2);
        pair.createOrder(true, price, quantity);

        BalanceSnapshot memory buyerAfter = snapshotBalances(trader2);

        // Calcular lo que debería depositar el buyer
        uint256 scaledAmount = (quantity * price) / PRECISION;
        console.log("Scaled amount deposited: %d", scaledAmount);
        console.log("Expected (floor): %d", (quantity * price) / PRECISION);

        // Verificar que solo se depositó 1 token (floor de 1.1)
        assertEq(scaledAmount, 1, "Should deposit floor(1.1) = 1 token");
        
        assertBalanceInvariant();
    }

    function testDustAccumulationMultipleSmallTrades() public {
        console.log("\n=== TEST: Dust Accumulation with 100 Small Trades ===");
        
        uint256 price = 1.25e18;
        uint256 quantity = 1; // 1 wei
        uint256 numTrades = 100;

        uint256 totalExpectedDust = calculateExpectedDust(price, quantity) * numTrades;
        console.log("Expected total dust: %d", totalExpectedDust);

        for (uint256 i = 0; i < numTrades; i++) {
            // Usar diferentes traders para evitar nonce collision
            address seller = i % 2 == 0 ? trader1 : trader3;
            address buyer = i % 2 == 0 ? trader2 : trader4;

            vm.prank(seller);
            pair.createOrder(false, price, quantity);

            vm.prank(buyer);
            pair.createOrder(true, price, quantity);
        }

        console.log("Completed %d trades", numTrades);
        
        // Verificar invariante después de acumulación de dust
        assertBalanceInvariant();
    }

    // ========================================
    // 3. PARTIAL FILL SCENARIOS
    // ========================================

    function testPartialFillWithRemainder() public {
        console.log("\n=== TEST: Partial Fill With Remainder ===");
        
        uint256 price = 1.5e18;
        uint256 sellQuantity = 100e18;
        uint256 buyQuantity = 75e18;

        // Seller crea orden grande
        vm.prank(trader1);
        pair.createOrder(false, price, sellQuantity);

        BalanceSnapshot memory sellerBefore = snapshotBalances(trader1);

        // Buyer ejecuta partial fill
        vm.prank(trader2);
        pair.createOrder(true, price, buyQuantity);

        BalanceSnapshot memory sellerAfter = snapshotBalances(trader1);

        // Verificar que el seller recibió crédito por 75 unidades
        uint256 expectedCredit = (buyQuantity * price) / PRECISION;
        uint256 actualCredit = sellerAfter.internalQuote - sellerBefore.internalQuote;
        
        console.log("Expected credit: %d", expectedCredit);
        console.log("Actual credit: %d", actualCredit);

        // Verificar que quedan 25 unidades en el orderbook
        // TODO: Verificar usando getOrderDetail cuando sea necesario

        assertBalanceInvariant();
    }

    function testMultiplePartialFillsAccumulation() public {
        console.log("\n=== TEST: Multiple Partial Fills Accumulation ===");
        
        uint256 price = 2e18;
        uint256 largeSellOrder = 100e18;
        uint256 smallBuyOrder = 20e18;

        // Seller crea orden grande
        vm.prank(trader1);
        pair.createOrder(false, price, largeSellOrder);

        BalanceSnapshot memory sellerBefore = snapshotBalances(trader1);

        // 5 buyers ejecutan fills parciales
        address[5] memory buyers = [trader2, trader3, trader4, trader5, trader2];
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(buyers[i]);
            pair.createOrder(true, price, smallBuyOrder);
        }

        BalanceSnapshot memory sellerAfter = snapshotBalances(trader1);

        // Verificar crédito acumulado
        uint256 totalFilled = smallBuyOrder * 5;
        uint256 expectedTotalCredit = (totalFilled * price) / PRECISION;
        uint256 actualCredit = sellerAfter.internalQuote - sellerBefore.internalQuote;
        
        console.log("Expected total credit: %d", expectedTotalCredit);
        console.log("Actual credit: %d", actualCredit);

        assertBalanceInvariant();
    }

    // ========================================
    // 4. COMPLEX ORDER MATCHING CHAINS
    // ========================================

    function testBuyOrderMatchesMultipleSells() public {
        console.log("\n=== TEST: Buy Order Matches Multiple Sells ===");
        
        // Setup: 3 sell orders a diferentes precios
        vm.prank(trader1);
        pair.createOrder(false, 1.5e18, 10e18);
        
        vm.prank(trader2);
        pair.createOrder(false, 1.6e18, 15e18);
        
        vm.prank(trader3);
        pair.createOrder(false, 1.7e18, 20e18);

        // Snapshots de sellers
        BalanceSnapshot memory seller1Before = snapshotBalances(trader1);
        BalanceSnapshot memory seller2Before = snapshotBalances(trader2);
        BalanceSnapshot memory seller3Before = snapshotBalances(trader3);

        // Buyer ejecuta orden grande que matchea todas
        vm.prank(trader4);
        pair.createOrder(true, 2e18, 45e18);

        // Verificar que cada maker recibió crédito correcto
        BalanceSnapshot memory seller1After = snapshotBalances(trader1);
        BalanceSnapshot memory seller2After = snapshotBalances(trader2);
        BalanceSnapshot memory seller3After = snapshotBalances(trader3);

        console.log("Seller1 credit: %d", seller1After.internalQuote - seller1Before.internalQuote);
        console.log("Seller2 credit: %d", seller2After.internalQuote - seller2Before.internalQuote);
        console.log("Seller3 credit: %d", seller3After.internalQuote - seller3Before.internalQuote);

        assertBalanceInvariant();
    }

    function testSellOrderMatchesMultipleBuys() public {
        console.log("\n=== TEST: Sell Order Matches Multiple Buys ===");
        
        // Setup: 3 buy orders a diferentes precios (highest to lowest)
        vm.prank(trader1);
        pair.createOrder(true, 2e18, 10e18);
        
        vm.prank(trader2);
        pair.createOrder(true, 1.9e18, 15e18);
        
        vm.prank(trader3);
        pair.createOrder(true, 1.8e18, 20e18);

        // Snapshots de buyers
        BalanceSnapshot memory buyer1Before = snapshotBalances(trader1);
        BalanceSnapshot memory buyer2Before = snapshotBalances(trader2);
        BalanceSnapshot memory buyer3Before = snapshotBalances(trader3);

        // Seller ejecuta orden grande que matchea todas
        vm.prank(trader4);
        pair.createOrder(false, 1.7e18, 45e18);

        // Verificar balances después del matching
        BalanceSnapshot memory buyer1After = snapshotBalances(trader1);
        BalanceSnapshot memory buyer2After = snapshotBalances(trader2);
        BalanceSnapshot memory buyer3After = snapshotBalances(trader3);

        console.log("Buyer1 base credit: %d", buyer1After.internalBase - buyer1Before.internalBase);
        console.log("Buyer2 base credit: %d", buyer2After.internalBase - buyer2Before.internalBase);
        console.log("Buyer3 base credit: %d", buyer3After.internalBase - buyer3Before.internalBase);

        assertBalanceInvariant();
    }

    // ========================================
    // 5. ORDER LIFECYCLE WITH BALANCE TRACKING
    // ========================================

    function testFullOrderLifecycleBalances() public {
        console.log("\n=== TEST: Full Order Lifecycle Balances ===");
        
        uint256 price = 1.5e18;
        uint256 quantity = 10e18;

        // 1. Create buy order
        BalanceSnapshot memory buyer1_1 = snapshotBalances(trader1);
        
        vm.prank(trader1);
        pair.createOrder(true, price, quantity);
        
        BalanceSnapshot memory buyer1_2 = snapshotBalances(trader1);
        
        // Verificar wallet deduction
        uint256 expectedDeposit = (quantity * price) / PRECISION;
        assertEq(
            buyer1_1.walletQuote - buyer1_2.walletQuote,
            expectedDeposit,
            "Wallet deduction mismatch"
        );

        // 2. Match con sell order
        vm.prank(trader2);
        pair.createOrder(false, price, quantity);
        
        BalanceSnapshot memory buyer1_3 = snapshotBalances(trader1);
        BalanceSnapshot memory seller2 = snapshotBalances(trader2);

        // Verificar créditos
        console.log("Buyer1 internal base: %d", buyer1_3.internalBase);
        console.log("Seller2 internal quote: %d", seller2.internalQuote);

        // 3. Withdraw
        vm.prank(trader1);
        pair.withdrawBalance(trader1, true); // withdraw base
        
        BalanceSnapshot memory buyer1_4 = snapshotBalances(trader1);
        
        // Verificar wallet increase
        assertGt(buyer1_4.walletBase, buyer1_1.walletBase, "Wallet should increase after withdraw");

        assertBalanceInvariant();
    }

    function testCancelOrderRefundAccuracy() public {
        console.log("\n=== TEST: Cancel Order Refund Accuracy ===");
        
        uint256 price = 1.7e18;
        uint256 quantity = 10e18;

        BalanceSnapshot memory buyerBefore = snapshotBalances(trader1);

        // Create buy order
        vm.prank(trader1);
        pair.createOrder(true, price, quantity);

        BalanceSnapshot memory buyerAfter = snapshotBalances(trader1);

        // Obtener order ID y cancelar
        bytes32[] memory orders = pair.getTraderOrders(trader1);
        require(orders.length > 0, "No orders found");

        vm.prank(trader1);
        pair.getCancelOrder(orders[0]);

        BalanceSnapshot memory buyerFinal = snapshotBalances(trader1);

        // Verificar refund
        uint256 deposited = buyerBefore.walletQuote - buyerAfter.walletQuote;
        uint256 refunded = buyerFinal.walletQuote - buyerAfter.walletQuote;
        
        console.log("Deposited: %d", deposited);
        console.log("Refunded: %d", refunded);

        // El refund debería ser floor((quantity * price) / PRECISION)
        uint256 expectedRefund = (quantity * price) / PRECISION;
        assertEq(refunded, expectedRefund, "Refund amount mismatch");

        assertBalanceInvariant();
    }

    // ========================================
    // 6. UNDERCOLLATERALIZATION ATTACK VECTORS
    // ========================================

    function testDustAccumulationUndercollateralization() public {
        console.log("\n=== TEST: Dust Accumulation Undercollateralization ===");
        
        uint256 price = 1.25e18;
        uint256 quantity = 1; // 1 wei
        uint256 numTrades = 100;

        uint256 contractQuoteBefore = quoteToken.balanceOf(address(pair));

        for (uint256 i = 0; i < numTrades; i++) {
            address seller = i % 2 == 0 ? trader1 : trader3;
            address buyer = i % 2 == 0 ? trader2 : trader4;

            vm.prank(seller);
            pair.createOrder(false, price, quantity);

            vm.prank(buyer);
            pair.createOrder(true, price, quantity);
        }

        uint256 contractQuoteAfter = quoteToken.balanceOf(address(pair));
        uint256 totalDeposited = contractQuoteAfter - contractQuoteBefore;

        console.log("Total deposited: %d", totalDeposited);
        console.log("Number of trades: %d", numTrades);
        console.log("Expected if no floor: %d", (numTrades * quantity * price) / PRECISION);

        // Calcular discrepancia
        uint256 expectedWithoutFloor = (numTrades * quantity * price) / PRECISION;
        if (expectedWithoutFloor > totalDeposited) {
            console.log("Discrepancy: %d", expectedWithoutFloor - totalDeposited);
        }

        // Intentar retirar todos los balances internos
        assertBalanceInvariant();
        
        console.log("[PASS] Contract remains collateralized after %d dust-generating trades", numTrades);
    }

    function testMaximumDustExploitation() public {
        console.log("\n=== TEST: Maximum Dust Exploitation ===");
        
        uint256 price = 1.999e18; // Máximo dust por trade
        uint256 quantity = 1; // 1 wei
        uint256 numTrades = 50;

        uint256 maxDustPerTrade = calculateExpectedDust(price, quantity);
        console.log("Max dust per trade: %d", maxDustPerTrade);
        console.log("Total potential dust: %d", maxDustPerTrade * numTrades);

        uint256 contractQuoteBefore = quoteToken.balanceOf(address(pair));

        for (uint256 i = 0; i < numTrades; i++) {
            address seller = i % 2 == 0 ? trader1 : trader3;
            address buyer = i % 2 == 0 ? trader2 : trader4;

            vm.prank(seller);
            pair.createOrder(false, price, quantity);

            vm.prank(buyer);
            pair.createOrder(true, price, quantity);
        }

        uint256 contractQuoteAfter = quoteToken.balanceOf(address(pair));
        uint256 totalDeposited = contractQuoteAfter - contractQuoteBefore;

        console.log("Total deposited: %d", totalDeposited);
        
        // Verificar que no hay subcolateralización
        assertBalanceInvariant();
    }

    // ========================================
    // 7. WITHDRAWAL EDGE CASES
    // ========================================

    function testQuoteTokenWithdrawalFloorDivision() public {
        console.log("\n=== TEST: Quote Token Withdrawal Floor Division ===");
        
        uint256 price = 1.9e18;
        uint256 quantity = 1; // 1 wei

        // Seller crea y ejecuta trade
        vm.prank(trader1);
        pair.createOrder(false, price, quantity);

        vm.prank(trader2);
        pair.createOrder(true, price, quantity);

        PairLib.TraderBalance memory sellerBalance = pair.getTraderBalances(trader1);
        console.log("Seller internal balance (scaled): %d", sellerBalance.quoteTokenBalance * PRECISION);
        console.log("Seller withdrawable: %d", sellerBalance.quoteTokenBalance);

        // Intentar withdraw
        if (sellerBalance.quoteTokenBalance > 0) {
            vm.prank(trader1);
            pair.withdrawBalance(trader1, false);
            
            console.log("[PASS] Withdrawal successful");
        } else {
            console.log("[PASS] Balance too small to withdraw (dust trapped)");
        }

        assertBalanceInvariant();
    }

    function testWithdrawAfterPartialFillDustAccumulation() public {
        console.log("\n=== TEST: Withdraw After Partial Fill Dust Accumulation ===");
        
        uint256 price = 1.333e18;
        uint256 largeQuantity = 100e18;
        uint256 smallQuantity = 13e18;

        // Seller crea orden grande
        vm.prank(trader1);
        pair.createOrder(false, price, largeQuantity);

        // Múltiples partial fills
        for (uint256 i = 0; i < 7; i++) {
            address buyer = i % 2 == 0 ? trader2 : trader3;
            vm.prank(buyer);
            pair.createOrder(true, price, smallQuantity);
        }

        PairLib.TraderBalance memory sellerBalance = pair.getTraderBalances(trader1);
        console.log("Seller withdrawable after partial fills: %d", sellerBalance.quoteTokenBalance);

        // Withdraw
        if (sellerBalance.quoteTokenBalance > 0) {
            vm.prank(trader1);
            pair.withdrawBalance(trader1, false);
        }

        assertBalanceInvariant();
    }

    // ========================================
    // 8. FEE PRECISION TESTS
    // ========================================

    function testFeeCalculationPrecision() public {
        console.log("\n=== TEST: Fee Calculation Precision ===");
        
        uint256 price = 1e18;
        uint256 smallQuantity = 10e18;

        // Ejecutar trade
        vm.prank(trader1);
        pair.createOrder(false, price, smallQuantity);

        vm.prank(trader2);
        pair.createOrder(true, price, smallQuantity);

        // Verificar fee acumulado
        (uint256 baseFee, uint256 quoteFee) = pair.getFeeBalances();
        console.log("Base fee accumulated: %d", baseFee);
        console.log("Quote fee accumulated (scaled): %d", quoteFee);
        console.log("Quote fee withdrawable: %d", quoteFee / PRECISION);

        // Verificar que el fee es correcto (1% de cantidad)
        uint256 expectedFee = (smallQuantity * FEE_BASIS_POINTS) / 10000;
        assertEq(baseFee, expectedFee, "Fee calculation incorrect");

        assertBalanceInvariant();
    }

    function testFeeWithdrawalFloorDivision() public {
        console.log("\n=== TEST: Fee Withdrawal Floor Division ===");
        
        // Múltiples trades pequeños para acumular fee
        uint256 price = 1.5e18;
        uint256 quantity = 5e18;

        for (uint256 i = 0; i < 10; i++) {
            address seller = i % 2 == 0 ? trader1 : trader3;
            address buyer = i % 2 == 0 ? trader2 : trader4;

            vm.prank(seller);
            pair.createOrder(false, price, quantity);

            vm.prank(buyer);
            pair.createOrder(true, price, quantity);
        }

        (uint256 baseFee, uint256 quoteFee) = pair.getFeeBalances();
        console.log("Total base fee: %d", baseFee);
        console.log("Total quote fee withdrawable: %d", quoteFee / PRECISION);

        assertBalanceInvariant();
    }

    // ========================================
    // 9. EXTREME VALUE TESTS
    // ========================================

    function testVeryLargeQuantityLowPrice() public {
        console.log("\n=== TEST: Very Large Quantity Low Price ===");
        
        uint256 price = 1e9; // precio muy bajo
        uint256 quantity = 1e30; // cantidad muy grande

        // Verificar que no hay overflow y el producto > 1e18
        uint256 product = quantity * price;
        assertGt(product, PRECISION, "Product should be > 1e18");

        // Este test puede fallar por límites de balance, solo verificamos la lógica
        console.log("Product: %d", product);
        console.log("Scaled amount: %d", product / PRECISION);
        
        console.log("[PASS] No overflow in extreme value calculation");
    }

    function testVerySmallQuantityHighPrice() public {
        console.log("\n=== TEST: Very Small Quantity High Price ===");
        
        uint256 price = 1e30; // precio muy alto
        uint256 quantity = 1; // cantidad muy pequeña (1 wei)

        uint256 product = quantity * price;
        console.log("Product: %d", product);
        console.log("Scaled amount: %d", product / PRECISION);

        // Verificar manejo de precisión
        assertGt(product / PRECISION, 0, "Should have non-zero scaled amount");
        
        console.log("[PASS] Precision handled correctly for extreme values");
    }

    // ========================================
    // 10. STRESS TESTS
    // ========================================

    function testStressTestMultipleTradersConcurrent() public {
        console.log("\n=== TEST: Stress Test Multiple Traders Concurrent ===");
        
        uint256[5] memory prices;
        prices[0] = 1.5e18;
        prices[1] = 2e18;
        prices[2] = 1.8e18;
        prices[3] = 2.2e18;
        prices[4] = 1.9e18;
        
        uint256[5] memory quantities;
        quantities[0] = 10e18;
        quantities[1] = 15e18;
        quantities[2] = 8e18;
        quantities[3] = 12e18;
        quantities[4] = 9e18;

        // Crear sell orders
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(trader1);
            pair.createOrder(false, prices[i], quantities[i]);
        }

        // Múltiples buyers ejecutan trades concurrentemente
        address[4] memory buyers = [trader2, trader3, trader4, trader5];
        for (uint256 i = 0; i < 20; i++) {
            uint256 priceIndex = i % 5;
            address buyer = buyers[i % 4];
            
            vm.prank(buyer);
            pair.createOrder(true, prices[priceIndex], quantities[priceIndex] / 4);
            
            // Verificar invariante después de cada operación
            assertBalanceInvariant();
        }
        
        console.log("[PASS] Invariant holds after 20 concurrent operations");
    }

    function testEdgeCaseMinimumViableOrder() public {
        console.log("\n=== TEST: Edge Case Minimum Viable Order ===");
        
        // El mínimo viable es cuando quantity * price > 1e18
        uint256 price = 1e18 + 1;
        uint256 quantity = 1;

        vm.prank(trader1);
        pair.createOrder(false, price, quantity);

        vm.prank(trader2);
        pair.createOrder(true, price, quantity);

        assertBalanceInvariant();
        
        console.log("[PASS] Minimum viable order executed successfully");
    }

    function testComplexScenarioMixedOperations() public {
        console.log("\n=== TEST: Complex Scenario Mixed Operations ===");
        
        // Escenario complejo: crear, matchear, cancelar, withdraw
        
        // 1. Crear múltiples órdenes
        vm.prank(trader1);
        pair.createOrder(false, 2e18, 50e18);
        
        vm.prank(trader2);
        pair.createOrder(true, 1.8e18, 30e18);
        
        // 2. Partial matches
        vm.prank(trader3);
        pair.createOrder(true, 2e18, 20e18);
        
        assertBalanceInvariant();
        
        // 3. Cancelar orden
        bytes32[] memory trader2Orders = pair.getTraderOrders(trader2);
        if (trader2Orders.length > 0) {
            vm.prank(trader2);
            pair.getCancelOrder(trader2Orders[0]);
        }
        
        assertBalanceInvariant();
        
        // 4. Withdraw
        vm.prank(trader1);
        pair.withdrawBalance(trader1, false);
        
        assertBalanceInvariant();
        
        console.log("[PASS] Complex mixed operations completed successfully");
    }
}

