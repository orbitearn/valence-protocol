// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Test} from "forge-std/src/Test.sol";
import {MorphonPositionManager} from "../../src/libraries/MorphonPositionManager.sol";
import {BaseAccount} from "../../src/accounts/BaseAccount.sol";
import {MockMorphonLendingPool} from "./mocks/MockMorphonLendingPool.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

/**
 * @title MorphonPositionManagerTest
 * @dev Comprehensive test suite for Morphon Finance Position Manager
 * @notice Tests all core functionality including supply, withdraw, borrow, and repay operations
 */
contract MorphonPositionManagerTest is Test {
    error NotOwnerOrLibrary(address _sender);
    MorphonPositionManager public positionManager;
    BaseAccount public inputAccount;
    BaseAccount public outputAccount;
    MockMorphonLendingPool public mockLendingPool;
    MockERC20 public mockAsset;
    
    address public owner;
    address public processor;
    address public user;
    
    uint256 public constant INITIAL_BALANCE = 1000e18;
    uint256 public constant SUPPLY_AMOUNT = 100e18;
    uint256 public constant BORROW_AMOUNT = 50e18;
    uint16 public constant REFERRAL_CODE = 123;

    event SupplyExecuted(uint256 amount, address asset, address onBehalfOf);
    event WithdrawExecuted(uint256 amount, address asset, address to);
    event BorrowExecuted(uint256 amount, address asset, uint256 interestRateMode);
    event RepayExecuted(uint256 amount, address asset, uint256 interestRateMode);

    function setUp() public {
        // Setup addresses
        owner = makeAddr("owner");
        processor = makeAddr("processor");
        user = makeAddr("user");
        
        // Deploy mock contracts
        mockAsset = new MockERC20("Mock Asset", "MOCK", 18);
        mockLendingPool = new MockMorphonLendingPool();
        
        // Deploy accounts
        inputAccount = new BaseAccount(owner, new address[](0));
        outputAccount = new BaseAccount(owner, new address[](0));
        
        // Set output account in mock lending pool
        mockLendingPool.setOutputAccount(address(outputAccount));
        
        // Create configuration
        MorphonPositionManager.MorphonPositionManagerConfig memory config = MorphonPositionManager.MorphonPositionManagerConfig({
            inputAccount: inputAccount,
            outputAccount: outputAccount,
            lendingPoolAddress: address(mockLendingPool),
            assetAddress: address(mockAsset),
            referralCode: REFERRAL_CODE
        });
        
        bytes memory configBytes = abi.encode(config);
        
        // Deploy position manager
        positionManager = new MorphonPositionManager(owner, processor, configBytes);
        
        // Setup initial balances
        mockAsset.mint(address(inputAccount), INITIAL_BALANCE);
        mockAsset.mint(address(mockLendingPool), INITIAL_BALANCE * 10); // Ensure lending pool has enough liquidity
        
        // Set up access control
        vm.startPrank(owner);
        inputAccount.approveLibrary(address(positionManager));
        outputAccount.approveLibrary(address(positionManager));
        vm.stopPrank();
    }

    // ============ SUPPLY TESTS ============


    function test_Supply_WithSpecificAmount() public {
        // Given    
        uint256 initialInputBalance = mockAsset.balanceOf(address(inputAccount));
        uint256 initialOutputMTokenBalance = mockLendingPool.balanceOf(address(mockAsset), address(outputAccount));
        
        // When
        vm.prank(processor);
        positionManager.supply(SUPPLY_AMOUNT);
        
        // Then
        assertEq(mockAsset.balanceOf(address(inputAccount)), initialInputBalance - SUPPLY_AMOUNT, "Input account balance should decrease");
        assertEq(mockLendingPool.balanceOf(address(mockAsset), address(outputAccount)), initialOutputMTokenBalance + SUPPLY_AMOUNT, "Output account mToken balance should increase");
    }

    function test_Supply_WithZeroAmount() public {
        // Given
        uint256 initialInputBalance = mockAsset.balanceOf(address(inputAccount));
        uint256 initialOutputMTokenBalance = mockLendingPool.balanceOf(address(mockAsset), address(outputAccount));
        
        // When
        vm.prank(processor);
        positionManager.supply(0);
        
        // Then
        assertEq(mockAsset.balanceOf(address(inputAccount)), 0, "Input account balance should be zero");
        assertEq(mockLendingPool.balanceOf(address(mockAsset), address(outputAccount)), initialOutputMTokenBalance + initialInputBalance, "Output account mToken balance should increase by full amount");
    }

    function test_Supply_WithInsufficientBalance() public {
        // Given
        uint256 largeAmount = INITIAL_BALANCE + 1;
        
        // Then
        vm.prank(processor);
        // ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed)
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientBalance(address,uint256,uint256)",
                address(inputAccount),
                INITIAL_BALANCE,
                largeAmount
            )
        );
        positionManager.supply(largeAmount);
    }

    function test_Supply_AccessControl() public {
        // Given
        address nonProcessor = makeAddr("nonProcessor");
        
        // Then
        vm.prank(nonProcessor);
        vm.expectRevert("Only the processor can call this function");
        positionManager.supply(SUPPLY_AMOUNT);
    }

    // ============ WITHDRAW TESTS ============

    function test_Withdraw_WithSpecificAmount() public {
        // Given
        vm.prank(processor);
        positionManager.supply(SUPPLY_AMOUNT);
        
        uint256 initialInputBalance = mockAsset.balanceOf(address(inputAccount));
        uint256 initialOutputMTokenBalance = mockLendingPool.balanceOf(address(mockAsset), address(outputAccount));
        uint256 withdrawAmount = SUPPLY_AMOUNT / 2;
        
        // When
        vm.prank(processor);
        positionManager.withdraw(withdrawAmount);
        
        // Then
        assertEq(mockAsset.balanceOf(address(inputAccount)), initialInputBalance + withdrawAmount, "Input account balance should increase");
        assertEq(mockLendingPool.balanceOf(address(mockAsset), address(outputAccount)), initialOutputMTokenBalance - withdrawAmount, "Output account mToken balance should decrease");
    }

    function test_Withdraw_WithZeroAmount() public {
        // Given
        vm.prank(processor);
        positionManager.supply(SUPPLY_AMOUNT);
        
        uint256 initialInputBalance = mockAsset.balanceOf(address(inputAccount));
        uint256 initialOutputMTokenBalance = mockLendingPool.balanceOf(address(mockAsset), address(outputAccount));
        
        // When
        vm.prank(processor);
        positionManager.withdraw(0);
        
        // Then
        assertEq(mockAsset.balanceOf(address(inputAccount)), initialInputBalance + initialOutputMTokenBalance, "Input account balance should increase by full amount");
        assertEq(mockLendingPool.balanceOf(address(mockAsset), address(outputAccount)), 0, "Output account mToken balance should be zero");
    }

    function test_Withdraw_WithNoMTokenBalance() public {
        // Given
        
        // Then
        vm.prank(processor);
        vm.expectRevert("Insufficient mToken balance");
        positionManager.withdraw(SUPPLY_AMOUNT);
    }

    function test_Withdraw_AccessControl() public {
        // Given
        address nonProcessor = makeAddr("nonProcessor");
        
        // Then
        vm.prank(nonProcessor);
        vm.expectRevert("Only the processor can call this function");
        positionManager.withdraw(SUPPLY_AMOUNT);
    }

    // ============ BORROW TESTS ============

    function test_Borrow_WithStableInterestRate() public {
        // Given
        uint256 initialInputBalance = mockAsset.balanceOf(address(inputAccount));
        uint256 initialBorrowBalance = mockLendingPool.borrowBalanceOf(address(mockAsset), address(inputAccount));
        
        // When
        vm.prank(processor);
        positionManager.borrow(BORROW_AMOUNT, 1); // 1 = stable rate
        
        // Then
        assertEq(mockAsset.balanceOf(address(inputAccount)), initialInputBalance + BORROW_AMOUNT, "Input account balance should increase");
        assertEq(mockLendingPool.borrowBalanceOf(address(mockAsset), address(inputAccount)), initialBorrowBalance + BORROW_AMOUNT, "Borrow balance should increase");
    }


    function test_Borrow_WithVariableInterestRate() public {
        // Given
        uint256 initialInputBalance = mockAsset.balanceOf(address(inputAccount));
        uint256 initialBorrowBalance = mockLendingPool.borrowBalanceOf(address(mockAsset), address(inputAccount));
        
        // When
        vm.prank(processor);
        positionManager.borrow(BORROW_AMOUNT, 2); // 2 = variable rate
        
        // Then
        assertEq(mockAsset.balanceOf(address(inputAccount)), initialInputBalance + BORROW_AMOUNT, "Input account balance should increase");
        assertEq(mockLendingPool.borrowBalanceOf(address(mockAsset), address(inputAccount)), initialBorrowBalance + BORROW_AMOUNT, "Borrow balance should increase");
    }


    function test_Borrow_WithZeroAmount() public {
        // Given
        
        // Then
        vm.prank(processor);
        vm.expectRevert("Borrow amount must be greater than 0");
        positionManager.borrow(0, 1);
    }


    function test_Borrow_WithInvalidInterestRateMode() public {
        // Given
        uint256 invalidMode = 3;
        
        // Then
        vm.prank(processor);
        vm.expectRevert("Invalid interest rate mode");
        positionManager.borrow(BORROW_AMOUNT, invalidMode);
    }


    function test_Borrow_AccessControl() public {
        // Given
        address nonProcessor = makeAddr("nonProcessor");
        
        // Then
        vm.prank(nonProcessor);
        vm.expectRevert("Only the processor can call this function");
        positionManager.borrow(BORROW_AMOUNT, 1);
    }

    // ============ REPAY TESTS ============


    function test_Repay_WithSpecificAmountAndStableRate() public {
        // Given
        vm.prank(processor);
        positionManager.borrow(BORROW_AMOUNT, 1);
        
        uint256 initialInputBalance = mockAsset.balanceOf(address(inputAccount));
        uint256 initialBorrowBalance = mockLendingPool.borrowBalanceOf(address(mockAsset), address(inputAccount));
        uint256 repayAmount = BORROW_AMOUNT / 2;
        
        // When
        vm.prank(processor);
        positionManager.repay(repayAmount, 1); // 1 = stable rate
        
        // Then
        assertEq(mockAsset.balanceOf(address(inputAccount)), initialInputBalance - repayAmount, "Input account balance should decrease");
        assertEq(mockLendingPool.borrowBalanceOf(address(mockAsset), address(inputAccount)), initialBorrowBalance - repayAmount, "Borrow balance should decrease");
    }


    function test_Repay_WithSpecificAmountAndVariableRate() public {
        // Given
        vm.prank(processor);
        positionManager.borrow(BORROW_AMOUNT, 2);
        
        uint256 initialInputBalance = mockAsset.balanceOf(address(inputAccount));
        uint256 initialBorrowBalance = mockLendingPool.borrowBalanceOf(address(mockAsset), address(inputAccount));
        uint256 repayAmount = BORROW_AMOUNT / 2;
        
        // When
        vm.prank(processor);
        positionManager.repay(repayAmount, 2); // 2 = variable rate
        
        // Then
        assertEq(mockAsset.balanceOf(address(inputAccount)), initialInputBalance - repayAmount, "Input account balance should decrease");
        assertEq(mockLendingPool.borrowBalanceOf(address(mockAsset), address(inputAccount)), initialBorrowBalance - repayAmount, "Borrow balance should decrease");
    }


    function test_Repay_WithZeroAmount() public {
        // Given
        vm.prank(processor);
        positionManager.borrow(BORROW_AMOUNT, 1);
        
        uint256 initialInputBalance = mockAsset.balanceOf(address(inputAccount));
        uint256 initialBorrowBalance = mockLendingPool.borrowBalanceOf(address(mockAsset), address(inputAccount));
        
        // When
        vm.prank(processor);
        positionManager.repay(0, 1);
        
        // Then
        assertEq(mockAsset.balanceOf(address(inputAccount)), initialInputBalance - initialBorrowBalance, "Input account balance should decrease by borrow amount");
        assertEq(mockLendingPool.borrowBalanceOf(address(mockAsset), address(inputAccount)), 0, "Borrow balance should be zero");
    }


    function test_Repay_WithNoBorrowBalance() public {
        // Given
        
        // Then
        vm.prank(processor);
        vm.expectRevert("Insufficient borrow balance");
        positionManager.repay(BORROW_AMOUNT, 1);
    }


    function test_Repay_WithInvalidInterestRateMode() public {
        // Given
        uint256 invalidMode = 3;
        
        // Then
        vm.prank(processor);
        vm.expectRevert("Invalid interest rate mode");
        positionManager.repay(BORROW_AMOUNT, invalidMode);
    }


    function test_Repay_AccessControl() public {
        // Given
        address nonProcessor = makeAddr("nonProcessor");
        
        // When & Then
        vm.prank(nonProcessor);
        vm.expectRevert("Only the processor can call this function");
        positionManager.repay(BORROW_AMOUNT, 1);
    }

    // ============ CONFIGURATION TESTS ============


    function test_UpdateConfig() public {
        // Given
        MorphonPositionManager.MorphonPositionManagerConfig memory newConfig = MorphonPositionManager.MorphonPositionManagerConfig({
            inputAccount: inputAccount,
            outputAccount: outputAccount,
            lendingPoolAddress: address(mockLendingPool),
            assetAddress: address(mockAsset),
            referralCode: 456 // Different referral code
        });
        
        bytes memory newConfigBytes = abi.encode(newConfig);
        
        // When
        vm.prank(owner);
        positionManager.updateConfig(newConfigBytes);
        
        // Then
        (BaseAccount inputAccountConfig, BaseAccount outputAccountConfig, address lendingPoolAddress, address assetAddress, uint16 referralCode) = positionManager.config();
        assertEq(referralCode, 456, "Referral code should be updated");
    }


    function test_UpdateConfig_AccessControl() public {
        // Given
        address nonOwner = makeAddr("nonOwner");
        
        // Then
        vm.prank(nonOwner);
        vm.expectRevert();
        positionManager.updateConfig("");
    }

    // ============ INTEGRATION TESTS ============


    function test_CompleteLendingCycle() public {
        // Given
        uint256 initialInputBalance = mockAsset.balanceOf(address(inputAccount));
        
        // When
        vm.prank(processor);
        positionManager.supply(SUPPLY_AMOUNT);
        
        vm.prank(processor);
        positionManager.borrow(BORROW_AMOUNT, 1);
        
        vm.prank(processor);
        positionManager.repay(BORROW_AMOUNT / 2, 1);
        
        vm.prank(processor);
        positionManager.withdraw(SUPPLY_AMOUNT / 2);
        
        // Then
        assertGt(mockAsset.balanceOf(address(inputAccount)), initialInputBalance - SUPPLY_AMOUNT, "Input account should have more than initial - supply");
        assertGt(mockLendingPool.balanceOf(address(mockAsset), address(outputAccount)), 0, "Output account should have remaining mTokens");
        assertGt(mockLendingPool.borrowBalanceOf(address(mockAsset), address(inputAccount)), 0, "Input account should have remaining debt");
    }


    function test_MultipleOperationsWithDifferentRates() public {
        // Given
        
        // When
        vm.prank(processor);
        positionManager.supply(SUPPLY_AMOUNT);
        
        vm.prank(processor);
        positionManager.borrow(BORROW_AMOUNT / 2, 1);
        
        vm.prank(processor);
        positionManager.borrow(BORROW_AMOUNT / 2, 2);
        
        vm.prank(processor);
        positionManager.repay(BORROW_AMOUNT / 2, 1);
        
        vm.prank(processor);
        positionManager.repay(BORROW_AMOUNT / 2, 2);
        
        // Then
        assertEq(mockLendingPool.borrowBalanceOf(address(mockAsset), address(inputAccount)), 0, "All debt should be repaid");
    }
} 