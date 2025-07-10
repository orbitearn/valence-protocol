// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/src/Test.sol";
import {FluidPositionManager} from "../../src/libraries/FluidPositionManager.sol";
import {BaseAccount} from "../../src/accounts/BaseAccount.sol";
import {MockFluidLendingPool} from "./mocks/MockFluidLendingPool.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract FluidPositionManagerTest is Test {
    // Contract under test
    FluidPositionManager public fluidPositionManager;

    // Mock contracts
    BaseAccount public inputAccount;
    BaseAccount public outputAccount;
    MockFluidLendingPool public lendingPool;
    MockERC20 public underlyingToken;
    
    // Test addresses
    address public owner;
    address public processor;
    address public user;
    
    // Test parameters
    uint256 public constant INITIAL_BALANCE = 1000e18;
    uint256 public constant SUPPLY_AMOUNT = 100e18;
    uint256 public constant BORROW_AMOUNT = 50e18;
    uint16 public constant REFERRAL_CODE = 123;

    // Setup function to initialize test environment
    function setUp() public {
        // Setup test addresses
        owner = makeAddr("owner");
        processor = makeAddr("processor");
        user = makeAddr("user");

        // Deploy mock contracts
        underlyingToken = new MockERC20("Mock Token", "MOCK", 18);
        lendingPool = new MockFluidLendingPool();
        
        // Deploy accounts
        vm.startPrank(owner);
        inputAccount = new BaseAccount(owner, new address[](0));
        outputAccount = new BaseAccount(owner, new address[](0));
        vm.stopPrank();
        
        // Fund accounts
        underlyingToken.mint(address(inputAccount), INITIAL_BALANCE);
        underlyingToken.mint(address(outputAccount), INITIAL_BALANCE);
        
        // Create configuration
        FluidPositionManager.FluidPositionManagerConfig memory config = FluidPositionManager.FluidPositionManagerConfig({
            inputAccount: inputAccount,
            outputAccount: outputAccount,
            lendingPoolAddress: address(lendingPool),
            assetAddress: address(underlyingToken),
            referralCode: REFERRAL_CODE
        });
        
        bytes memory encodedConfig = abi.encode(config);
        
        // Deploy position manager
        vm.startPrank(owner);
        fluidPositionManager = new FluidPositionManager(owner, processor, encodedConfig);
        vm.stopPrank();
        
        // Set up permissions
        vm.startPrank(owner);
        inputAccount.approveLibrary(address(fluidPositionManager));
        outputAccount.approveLibrary(address(fluidPositionManager));
        vm.stopPrank();
        
        // Fund lending pool with underlying for operations
        underlyingToken.mint(address(lendingPool), INITIAL_BALANCE * 10);

        // Set outputAccount in the mock lending pool
        lendingPool.setOutputAccount(address(outputAccount));

        // Label contracts for better debugging
        vm.label(address(inputAccount), "inputAccount");
        vm.label(address(outputAccount), "outputAccount");
        vm.label(address(underlyingToken), "underlyingToken");
        vm.label(address(lendingPool), "lendingPool");
        vm.label(address(fluidPositionManager), "fluidPositionManager");
    }

    // ============== Configuration Tests ==============

    function test_GivenValidConfig_WhenContractIsDeployed_ThenConfigIsSet() public view {
        // given - contract is deployed with valid config in setUp()
        
        // when - config is retrieved
        
        // then - config should match the expected values
        assertEq(address(fluidPositionManager.inputAccount()), address(inputAccount));
        assertEq(address(fluidPositionManager.outputAccount()), address(outputAccount));
        assertEq(fluidPositionManager.lendingPoolAddress(), address(lendingPool));
        assertEq(fluidPositionManager.assetAddress(), address(underlyingToken));
        assertEq(fluidPositionManager.referralCode(), REFERRAL_CODE);
    }

    function test_GivenValidConfig_WhenUpdateConfigIsCalled_ThenConfigIsUpdated() public {
        // given
        BaseAccount newInputAccount = new BaseAccount(owner, new address[](0));
        BaseAccount newOutputAccount = new BaseAccount(owner, new address[](0));
        
        FluidPositionManager.FluidPositionManagerConfig memory newConfig = FluidPositionManager.FluidPositionManagerConfig({
            inputAccount: newInputAccount,
            outputAccount: newOutputAccount,
            lendingPoolAddress: address(lendingPool),
            assetAddress: address(underlyingToken),
            referralCode: 456
        });
        
        bytes memory encodedConfig = abi.encode(newConfig);
        
        // when
        vm.prank(owner);
        fluidPositionManager.updateConfig(encodedConfig);
        
        // then
        assertEq(address(fluidPositionManager.inputAccount()), address(newInputAccount));
        assertEq(address(fluidPositionManager.outputAccount()), address(newOutputAccount));
        assertEq(fluidPositionManager.referralCode(), 456);
    }

    function test_RevertUpdateConfig_WithInvalidConfig_WhenLendingPoolAddressIsZeroAddress() public {
        // given
        FluidPositionManager.FluidPositionManagerConfig memory newConfig = FluidPositionManager.FluidPositionManagerConfig({
            inputAccount: inputAccount,
            outputAccount: outputAccount,
            lendingPoolAddress: address(0),
            assetAddress: address(underlyingToken),
            referralCode: REFERRAL_CODE
        });
        
        bytes memory encodedConfig = abi.encode(newConfig);
        
        // expect
        vm.expectRevert("Lending pool address can't be zero address");
        
        // when
        vm.prank(owner);
        fluidPositionManager.updateConfig(encodedConfig);
    }

    function test_RevertUpdateConfig_WithInvalidConfig_WhenAssetAddressIsZeroAddress() public {
        // given
        FluidPositionManager.FluidPositionManagerConfig memory newConfig = FluidPositionManager.FluidPositionManagerConfig({
            inputAccount: inputAccount,
            outputAccount: outputAccount,
            lendingPoolAddress: address(lendingPool),
            assetAddress: address(0),
            referralCode: REFERRAL_CODE
        });
        
        bytes memory encodedConfig = abi.encode(newConfig);
        
        // expect
        vm.expectRevert("Asset address can't be zero address");
        
        // when
        vm.prank(owner);
        fluidPositionManager.updateConfig(encodedConfig);
    }

    function test_RevertUpdateConfig_WithInvalidConfig_WhenInputAccountIsZeroAddress() public {
        // given
        FluidPositionManager.FluidPositionManagerConfig memory newConfig = FluidPositionManager.FluidPositionManagerConfig({
            inputAccount: BaseAccount(payable(address(0))),
            outputAccount: outputAccount,
            lendingPoolAddress: address(lendingPool),
            assetAddress: address(underlyingToken),
            referralCode: REFERRAL_CODE
        });
        
        bytes memory encodedConfig = abi.encode(newConfig);
        
        // expect
        vm.expectRevert("Input account can't be zero address");
        
        // when
        vm.prank(owner);
        fluidPositionManager.updateConfig(encodedConfig);
    }

    function test_RevertUpdateConfig_WithInvalidConfig_WhenOutputAccountIsZeroAddress() public {
        // given
        FluidPositionManager.FluidPositionManagerConfig memory newConfig = FluidPositionManager.FluidPositionManagerConfig({
            inputAccount: inputAccount,
            outputAccount: BaseAccount(payable(address(0))),
            lendingPoolAddress: address(lendingPool),
            assetAddress: address(underlyingToken),
            referralCode: REFERRAL_CODE
        });
        
        bytes memory encodedConfig = abi.encode(newConfig);
        
        // expect
        vm.expectRevert("Output account can't be zero address");
        
        // when
        vm.prank(owner);
        fluidPositionManager.updateConfig(encodedConfig);
    }

    function test_RevertUpdateConfig_WithUnauthorized_WhenCallerIsNotOwner() public {
        // given
        FluidPositionManager.FluidPositionManagerConfig memory newConfig = FluidPositionManager.FluidPositionManagerConfig({
            inputAccount: inputAccount,
            outputAccount: outputAccount,
            lendingPoolAddress: address(lendingPool),
            assetAddress: address(underlyingToken),
            referralCode: REFERRAL_CODE
        });
        
        bytes memory encodedConfig = abi.encode(newConfig);
        
        // expect
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        
        // when
        vm.prank(user);
        fluidPositionManager.updateConfig(encodedConfig);
    }

    // ============== Constructor Tests ==============

    function test_RevertConstructor_WithInvalidConfig_WhenLendingPoolAddressIsZeroAddress() public {
        // given
        FluidPositionManager.FluidPositionManagerConfig memory config = FluidPositionManager.FluidPositionManagerConfig({
            inputAccount: inputAccount,
            outputAccount: outputAccount,
            lendingPoolAddress: address(0),
            assetAddress: address(underlyingToken),
            referralCode: REFERRAL_CODE
        });
        
        bytes memory encodedConfig = abi.encode(config);
        
        // expect
        vm.expectRevert("Lending pool address can't be zero address");
        
        // when
        new FluidPositionManager(owner, processor, encodedConfig);
    }

    function test_RevertConstructor_WithInvalidConfig_WhenAssetAddressIsZeroAddress() public {
        // given
        FluidPositionManager.FluidPositionManagerConfig memory config = FluidPositionManager.FluidPositionManagerConfig({
            inputAccount: inputAccount,
            outputAccount: outputAccount,
            lendingPoolAddress: address(lendingPool),
            assetAddress: address(0),
            referralCode: REFERRAL_CODE
        });
        
        bytes memory encodedConfig = abi.encode(config);
        
        // expect
        vm.expectRevert("Asset address can't be zero address");
        
        // when
        new FluidPositionManager(owner, processor, encodedConfig);
    }

    function test_RevertConstructor_WithInvalidConfig_WhenInputAccountIsZeroAddress() public {
        // given
        FluidPositionManager.FluidPositionManagerConfig memory config = FluidPositionManager.FluidPositionManagerConfig({
            inputAccount: BaseAccount(payable(address(0))),
            outputAccount: outputAccount,
            lendingPoolAddress: address(lendingPool),
            assetAddress: address(underlyingToken),
            referralCode: REFERRAL_CODE
        });
        
        bytes memory encodedConfig = abi.encode(config);
        
        // expect
        vm.expectRevert("Input account can't be zero address");
        
        // when
        new FluidPositionManager(owner, processor, encodedConfig);
    }

    function test_RevertConstructor_WithInvalidConfig_WhenOutputAccountIsZeroAddress() public {
        // given
        FluidPositionManager.FluidPositionManagerConfig memory config = FluidPositionManager.FluidPositionManagerConfig({
            inputAccount: inputAccount,
            outputAccount: BaseAccount(payable(address(0))),
            lendingPoolAddress: address(lendingPool),
            assetAddress: address(underlyingToken),
            referralCode: REFERRAL_CODE
        });
        
        bytes memory encodedConfig = abi.encode(config);
        
        // expect
        vm.expectRevert("Output account can't be zero address");
        
        // when
        new FluidPositionManager(owner, processor, encodedConfig);
    }

    // ============== Supply Tests ==============

    function test_GivenValidAmount_WhenSupplyIsCalled_ThenFTokensAreMinted() public {
        // given
        uint256 supplyAmount = SUPPLY_AMOUNT;
        uint256 initialFTokenBalance = fluidPositionManager.getFTokenBalance();
        uint256 initialUnderlyingBalance = underlyingToken.balanceOf(address(inputAccount));
        
        // when
        vm.prank(processor);
        fluidPositionManager.supply(supplyAmount);
        
        // then
        uint256 finalFTokenBalance = fluidPositionManager.getFTokenBalance();
        uint256 finalUnderlyingBalance = underlyingToken.balanceOf(address(inputAccount));
        
        assertGt(finalFTokenBalance, initialFTokenBalance, "Should have fTokens after supply");
        assertEq(finalUnderlyingBalance, initialUnderlyingBalance - supplyAmount, "Input account should have reduced underlying balance");
    }

    function test_GivenZeroAmount_WhenSupplyIsCalled_ThenAllUnderlyingIsSupplied() public {
        // given
        uint256 initialFTokenBalance = fluidPositionManager.getFTokenBalance();
        uint256 initialUnderlyingBalance = underlyingToken.balanceOf(address(inputAccount));
        
        // when
        vm.prank(processor);
        fluidPositionManager.supply(0);
        
        // then
        uint256 finalFTokenBalance = fluidPositionManager.getFTokenBalance();
        uint256 finalUnderlyingBalance = underlyingToken.balanceOf(address(inputAccount));
        
        assertGt(finalFTokenBalance, initialFTokenBalance, "Should have fTokens after supply");
        assertEq(finalUnderlyingBalance, 0, "Input account should have no underlying balance left");
    }

    function test_RevertSupply_WithUnauthorized_WhenCallerIsNotProcessor() public {
        // given
        uint256 supplyAmount = SUPPLY_AMOUNT;
        
        // expect
        vm.expectRevert();
        
        // when
        vm.prank(user);
        fluidPositionManager.supply(supplyAmount);
    }

    // ============== Withdraw Tests ==============

    function test_GivenValidAmount_WhenWithdrawIsCalled_ThenUnderlyingIsRedeemed() public {
        // given
        vm.prank(processor);
        fluidPositionManager.supply(SUPPLY_AMOUNT);
        
        uint256 withdrawAmount = SUPPLY_AMOUNT / 2;
        uint256 initialFTokenBalance = fluidPositionManager.getFTokenBalance();
        uint256 initialUnderlyingBalance = underlyingToken.balanceOf(address(inputAccount));
        
        // when
        vm.prank(processor);
        fluidPositionManager.withdraw(withdrawAmount);
        
        // then
        uint256 finalFTokenBalance = fluidPositionManager.getFTokenBalance();
        uint256 finalUnderlyingBalance = underlyingToken.balanceOf(address(inputAccount));
        
        assertLt(finalFTokenBalance, initialFTokenBalance, "fToken balance should decrease");
        assertGt(finalUnderlyingBalance, initialUnderlyingBalance, "Underlying balance should increase");
    }

    function test_GivenZeroAmount_WhenWithdrawIsCalled_ThenAllFTokensAreRedeemed() public {
        // given
        vm.prank(processor);
        fluidPositionManager.supply(SUPPLY_AMOUNT);
        
        uint256 fTokenBalance = fluidPositionManager.getFTokenBalance();
        
        // when
        vm.prank(processor);
        fluidPositionManager.withdraw(0);
        
        // then
        uint256 finalFTokenBalance = fluidPositionManager.getFTokenBalance();
        assertEq(finalFTokenBalance, 0, "Should have no fTokens after full withdrawal");
    }

    function test_RevertWithdraw_WithUnauthorized_WhenCallerIsNotProcessor() public {
        // given
        uint256 withdrawAmount = SUPPLY_AMOUNT;
        
        // expect
        vm.expectRevert();
        
        // when
        vm.prank(user);
        fluidPositionManager.withdraw(withdrawAmount);
    }

    // ============== Borrow Tests ==============

    function test_GivenValidAmount_WhenBorrowIsCalled_ThenUnderlyingIsBorrowed() public {
        // given
        uint256 borrowAmount = BORROW_AMOUNT;
        uint256 interestRateMode = 2; // Variable rate
        uint256 initialUnderlyingBalance = underlyingToken.balanceOf(address(inputAccount));
        
        // when
        vm.prank(processor);
        fluidPositionManager.borrow(borrowAmount, interestRateMode);
        
        // then
        uint256 borrowBalance = fluidPositionManager.getBorrowBalance();
        uint256 finalUnderlyingBalance = underlyingToken.balanceOf(address(inputAccount));
        
        assertEq(borrowBalance, borrowAmount, "Should have correct borrow balance");
        assertEq(finalUnderlyingBalance, initialUnderlyingBalance + borrowAmount, "Input account should have received borrowed tokens");
    }

    function test_GivenStableRateMode_WhenBorrowIsCalled_ThenBorrowSucceeds() public {
        // given
        uint256 borrowAmount = BORROW_AMOUNT;
        uint256 interestRateMode = 1; // Stable rate
        
        // when
        vm.prank(processor);
        fluidPositionManager.borrow(borrowAmount, interestRateMode);
        
        // then
        uint256 borrowBalance = fluidPositionManager.getBorrowBalance();
        assertEq(borrowBalance, borrowAmount, "Should have correct borrow balance");
    }

    function test_RevertBorrow_WithInvalidInterestRateMode_WhenModeIsNotValid() public {
        // given
        uint256 borrowAmount = BORROW_AMOUNT;
        uint256 invalidInterestRateMode = 3;
        
        // expect
        vm.expectRevert("Invalid interest rate mode");
        
        // when
        vm.prank(processor);
        fluidPositionManager.borrow(borrowAmount, invalidInterestRateMode);
    }

    function test_RevertBorrow_WithZeroAmount_WhenAmountIsZero() public {
        // given
        uint256 borrowAmount = 0;
        uint256 interestRateMode = 2;
        
        // expect
        vm.expectRevert("Borrow amount must be greater than 0");
        
        // when
        vm.prank(processor);
        fluidPositionManager.borrow(borrowAmount, interestRateMode);
    }

    function test_RevertBorrow_WithUnauthorized_WhenCallerIsNotProcessor() public {
        // given
        uint256 borrowAmount = BORROW_AMOUNT;
        uint256 interestRateMode = 2;
        
        // expect
        vm.expectRevert();
        
        // when
        vm.prank(user);
        fluidPositionManager.borrow(borrowAmount, interestRateMode);
    }

    // ============== Repay Tests ==============

    function test_GivenValidAmount_WhenRepayIsCalled_ThenBorrowBalanceDecreases() public {
        // given
        vm.prank(processor);
        fluidPositionManager.borrow(BORROW_AMOUNT, 2);
        
        uint256 repayAmount = BORROW_AMOUNT / 2;
        uint256 interestRateMode = 2;
        uint256 initialBorrowBalance = fluidPositionManager.getBorrowBalance();
        
        // when
        vm.prank(processor);
        fluidPositionManager.repay(repayAmount, interestRateMode);
        
        // then
        uint256 finalBorrowBalance = fluidPositionManager.getBorrowBalance();
        assertLt(finalBorrowBalance, initialBorrowBalance, "Borrow balance should decrease");
    }

    function test_GivenZeroAmount_WhenRepayIsCalled_ThenAllBorrowIsRepaid() public {
        // given
        vm.prank(processor);
        fluidPositionManager.borrow(BORROW_AMOUNT, 2);
        
        // when
        vm.prank(processor);
        fluidPositionManager.repay(0, 2);
        
        // then
        uint256 finalBorrowBalance = fluidPositionManager.getBorrowBalance();
        assertEq(finalBorrowBalance, 0, "Should have no borrow balance after full repayment");
    }

    function test_RevertRepay_WithInvalidInterestRateMode_WhenModeIsNotValid() public {
        // given
        uint256 repayAmount = BORROW_AMOUNT;
        uint256 invalidInterestRateMode = 3;
        
        // expect
        vm.expectRevert("Invalid interest rate mode");
        
        // when
        vm.prank(processor);
        fluidPositionManager.repay(repayAmount, invalidInterestRateMode);
    }

    function test_RevertRepay_WithUnauthorized_WhenCallerIsNotProcessor() public {
        // given
        uint256 repayAmount = BORROW_AMOUNT;
        uint256 interestRateMode = 2;
        
        // expect
        vm.expectRevert();
        
        // when
        vm.prank(user);
        fluidPositionManager.repay(repayAmount, interestRateMode);
    }

    // ============== View Function Tests ==============

    function test_GivenSupplyPosition_WhenGetFTokenBalanceIsCalled_ThenReturnsCorrectBalance() public {
        // given
        vm.prank(processor);
        fluidPositionManager.supply(SUPPLY_AMOUNT);
        
        // when
        uint256 fTokenBalance = fluidPositionManager.getFTokenBalance();
        
        // then
        assertEq(fTokenBalance, SUPPLY_AMOUNT, "Should return correct fToken balance");
    }

    function test_GivenBorrowPosition_WhenGetBorrowBalanceIsCalled_ThenReturnsCorrectBalance() public {
        // given
        vm.prank(processor);
        fluidPositionManager.borrow(BORROW_AMOUNT, 2);
        
        // when
        uint256 borrowBalance = fluidPositionManager.getBorrowBalance();
        
        // then
        assertEq(borrowBalance, BORROW_AMOUNT, "Should return correct borrow balance");
    }

    function test_GivenUnderlyingTokens_WhenGetUnderlyingBalanceIsCalled_ThenReturnsCorrectBalance() public {
        // given - input account has initial balance from setUp()
        
        // when
        uint256 underlyingBalance = fluidPositionManager.getUnderlyingBalance();
        
        // then
        assertEq(underlyingBalance, INITIAL_BALANCE, "Should return correct underlying balance");
    }

    function test_GivenUnderlyingTokens_WhenGetOutputAccountBalanceIsCalled_ThenReturnsCorrectBalance() public {
        // given - output account has initial balance from setUp()
        
        // when
        uint256 outputBalance = fluidPositionManager.getOutputAccountBalance();
        
        // then
        assertEq(outputBalance, INITIAL_BALANCE, "Should return correct output account balance");
    }

    function test_GivenSupplyPosition_WhenGetFTokenAddressIsCalled_ThenReturnsCorrectAddress() public {
        // given
        vm.prank(processor);
        fluidPositionManager.supply(SUPPLY_AMOUNT);
        
        // when
        address fTokenAddress = fluidPositionManager.getFTokenAddress();
        
        // then
        assertEq(fTokenAddress, address(lendingPool), "Should return correct fToken address");
    }

    function test_GivenNoDebt_WhenHasDebtIsCalled_ThenReturnsFalse() public {
        // given - no borrow position
        
        // when
        bool hasDebt = fluidPositionManager.hasDebt();
        
        // then
        assertEq(hasDebt, false, "Should return false when no debt");
    }

    function test_GivenBorrowPosition_WhenHasDebtIsCalled_ThenReturnsTrue() public {
        // given
        vm.prank(processor);
        fluidPositionManager.borrow(BORROW_AMOUNT, 2);
        
        // when
        bool hasDebt = fluidPositionManager.hasDebt();
        
        // then
        assertEq(hasDebt, true, "Should return true when has debt");
    }

    function test_GivenNoDebt_WhenGetTotalDebtIsCalled_ThenReturnsZero() public {
        // given - no borrow position
        
        // when
        uint256 totalDebt = fluidPositionManager.getTotalDebt();
        
        // then
        assertEq(totalDebt, 0, "Should return zero when no debt");
    }

    function test_GivenBorrowPosition_WhenGetTotalDebtIsCalled_ThenReturnsCorrectAmount() public {
        // given
        vm.prank(processor);
        fluidPositionManager.borrow(BORROW_AMOUNT, 2);
        
        // when
        uint256 totalDebt = fluidPositionManager.getTotalDebt();
        
        // then
        assertEq(totalDebt, BORROW_AMOUNT, "Should return correct total debt");
    }
} 