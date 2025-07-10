// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/src/Test.sol";
import {MoonwellPositionManager} from "../../src/libraries/MoonwellPositionManager.sol";
import {BaseAccount} from "../../src/accounts/BaseAccount.sol";
import {MockMoonwellComptroller} from "./mocks/MockMoonwellComptroller.sol";
import {MockMoonwellMToken} from "./mocks/MockMoonwellMToken.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MoonwellPositionManagerTest is Test {
    // Contract under test
    MoonwellPositionManager public moonwellPositionManager;

    // Mock contracts
    BaseAccount public inputAccount;
    BaseAccount public outputAccount;
    MockMoonwellComptroller public comptroller;
    MockMoonwellMToken public mToken;
    MockERC20 public underlyingToken;
    
    // Test addresses
    address public owner;
    address public processor;
    address public user;
    
    // Test parameters
    uint256 public constant INITIAL_BALANCE = 1000e18;
    uint256 public constant SUPPLY_AMOUNT = 100e18;
    uint256 public constant BORROW_AMOUNT = 50e18;

    // Setup function to initialize test environment
    function setUp() public {
        // Setup test addresses
        owner = makeAddr("owner");
        processor = makeAddr("processor");
        user = makeAddr("user");

        // Deploy mock contracts
        underlyingToken = new MockERC20("Mock Token", "MOCK", 18);
        comptroller = new MockMoonwellComptroller();
        mToken = new MockMoonwellMToken(address(underlyingToken), address(comptroller));
        
        // Deploy accounts
        vm.startPrank(owner);
        inputAccount = new BaseAccount(owner, new address[](0));
        outputAccount = new BaseAccount(owner, new address[](0));
        vm.stopPrank();
        
        // Fund accounts
        underlyingToken.mint(address(inputAccount), INITIAL_BALANCE);
        underlyingToken.mint(address(outputAccount), INITIAL_BALANCE);
        
        // Create configuration
        MoonwellPositionManager.MoonwellPositionManagerConfig memory config = MoonwellPositionManager.MoonwellPositionManagerConfig({
            inputAccount: inputAccount,
            outputAccount: outputAccount,
            comptrollerAddress: address(comptroller),
            mTokenAddress: address(mToken)
        });
        
        bytes memory encodedConfig = abi.encode(config);
        
        // Deploy position manager
        vm.startPrank(owner);
        moonwellPositionManager = new MoonwellPositionManager(owner, processor, encodedConfig);
        vm.stopPrank();
        
        // Set up permissions
        vm.startPrank(owner);
        inputAccount.approveLibrary(address(moonwellPositionManager));
        outputAccount.approveLibrary(address(moonwellPositionManager));
        vm.stopPrank();
        
        // Fund mToken with underlying for operations
        underlyingToken.mint(address(mToken), INITIAL_BALANCE * 10);

        // Label contracts for better debugging
        vm.label(address(inputAccount), "inputAccount");
        vm.label(address(outputAccount), "outputAccount");
        vm.label(address(underlyingToken), "underlyingToken");
        vm.label(address(comptroller), "comptroller");
        vm.label(address(mToken), "mToken");
        vm.label(address(moonwellPositionManager), "moonwellPositionManager");
    }

    // ============== Configuration Tests ==============

    function test_GivenValidConfig_WhenContractIsDeployed_ThenConfigIsSet() public view {
        // given - contract is deployed with valid config in setUp()
        
        // when - config is retrieved
        
        // then - config should match the expected values
        assertEq(address(moonwellPositionManager.inputAccount()), address(inputAccount));
        assertEq(address(moonwellPositionManager.outputAccount()), address(outputAccount));
        assertEq(moonwellPositionManager.comptrollerAddress(), address(comptroller));
        assertEq(moonwellPositionManager.mTokenAddress(), address(mToken));
    }

    function test_GivenValidConfig_WhenUpdateConfigIsCalled_ThenConfigIsUpdated() public {
        // given
        BaseAccount newInputAccount = new BaseAccount(owner, new address[](0));
        BaseAccount newOutputAccount = new BaseAccount(owner, new address[](0));
        
        MoonwellPositionManager.MoonwellPositionManagerConfig memory newConfig = MoonwellPositionManager.MoonwellPositionManagerConfig({
            inputAccount: newInputAccount,
            outputAccount: newOutputAccount,
            comptrollerAddress: address(comptroller),
            mTokenAddress: address(mToken)
        });
        
        bytes memory encodedConfig = abi.encode(newConfig);
        
        // when
        vm.prank(owner);
        moonwellPositionManager.updateConfig(encodedConfig);
        
        // then
        assertEq(address(moonwellPositionManager.inputAccount()), address(newInputAccount));
        assertEq(address(moonwellPositionManager.outputAccount()), address(newOutputAccount));
    }

    function test_RevertUpdateConfig_WithInvalidConfig_WhenComptrollerAddressIsZeroAddress() public {
        // given
        MoonwellPositionManager.MoonwellPositionManagerConfig memory newConfig = MoonwellPositionManager.MoonwellPositionManagerConfig({
            inputAccount: inputAccount,
            outputAccount: outputAccount,
            comptrollerAddress: address(0),
            mTokenAddress: address(mToken)
        });
        
        bytes memory encodedConfig = abi.encode(newConfig);
        
        // expect
        vm.expectRevert("Comptroller address can't be zero address");
        
        // when
        vm.prank(owner);
        moonwellPositionManager.updateConfig(encodedConfig);
    }

    function test_RevertUpdateConfig_WithInvalidConfig_WhenMTokenAddressIsZeroAddress() public {
        // given
        MoonwellPositionManager.MoonwellPositionManagerConfig memory newConfig = MoonwellPositionManager.MoonwellPositionManagerConfig({
            inputAccount: inputAccount,
            outputAccount: outputAccount,
            comptrollerAddress: address(comptroller),
            mTokenAddress: address(0)
        });
        
        bytes memory encodedConfig = abi.encode(newConfig);
        
        // expect
        vm.expectRevert("mToken address can't be zero address");
        
        // when
        vm.prank(owner);
        moonwellPositionManager.updateConfig(encodedConfig);
    }

    function test_RevertUpdateConfig_WithInvalidConfig_WhenInputAccountIsZeroAddress() public {
        // given
        MoonwellPositionManager.MoonwellPositionManagerConfig memory newConfig = MoonwellPositionManager.MoonwellPositionManagerConfig({
            inputAccount: BaseAccount(payable(address(0))),
            outputAccount: outputAccount,
            comptrollerAddress: address(comptroller),
            mTokenAddress: address(mToken)
        });
        
        bytes memory encodedConfig = abi.encode(newConfig);
        
        // expect
        vm.expectRevert("Input account can't be zero address");
        
        // when
        vm.prank(owner);
        moonwellPositionManager.updateConfig(encodedConfig);
    }

    function test_RevertUpdateConfig_WithInvalidConfig_WhenOutputAccountIsZeroAddress() public {
        // given
        MoonwellPositionManager.MoonwellPositionManagerConfig memory newConfig = MoonwellPositionManager.MoonwellPositionManagerConfig({
            inputAccount: inputAccount,
            outputAccount: BaseAccount(payable(address(0))),
            comptrollerAddress: address(comptroller),
            mTokenAddress: address(mToken)
        });
        
        bytes memory encodedConfig = abi.encode(newConfig);
        
        // expect
        vm.expectRevert("Output account can't be zero address");
        
        // when
        vm.prank(owner);
        moonwellPositionManager.updateConfig(encodedConfig);
    }

    function test_RevertUpdateConfig_WithUnauthorized_WhenCallerIsNotOwner() public {
        // given
        MoonwellPositionManager.MoonwellPositionManagerConfig memory newConfig = MoonwellPositionManager.MoonwellPositionManagerConfig({
            inputAccount: inputAccount,
            outputAccount: outputAccount,
            comptrollerAddress: address(comptroller),
            mTokenAddress: address(mToken)
        });
        
        bytes memory encodedConfig = abi.encode(newConfig);
        
        // expect
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        
        // when
        vm.prank(user);
        moonwellPositionManager.updateConfig(encodedConfig);
    }

    // ============== Constructor Tests ==============

    function test_RevertConstructor_WithInvalidConfig_WhenComptrollerAddressIsZeroAddress() public {
        // given
        MoonwellPositionManager.MoonwellPositionManagerConfig memory config = MoonwellPositionManager.MoonwellPositionManagerConfig({
            inputAccount: inputAccount,
            outputAccount: outputAccount,
            comptrollerAddress: address(0),
            mTokenAddress: address(mToken)
        });
        
        bytes memory encodedConfig = abi.encode(config);
        
        // expect
        vm.expectRevert("Comptroller address can't be zero address");
        
        // when
        new MoonwellPositionManager(owner, processor, encodedConfig);
    }

    function test_RevertConstructor_WithInvalidConfig_WhenMTokenAddressIsZeroAddress() public {
        // given
        MoonwellPositionManager.MoonwellPositionManagerConfig memory config = MoonwellPositionManager.MoonwellPositionManagerConfig({
            inputAccount: inputAccount,
            outputAccount: outputAccount,
            comptrollerAddress: address(comptroller),
            mTokenAddress: address(0)
        });
        
        bytes memory encodedConfig = abi.encode(config);
        
        // expect
        vm.expectRevert("mToken address can't be zero address");
        
        // when
        new MoonwellPositionManager(owner, processor, encodedConfig);
    }

    function test_RevertConstructor_WithInvalidConfig_WhenInputAccountIsZeroAddress() public {
        // given
        MoonwellPositionManager.MoonwellPositionManagerConfig memory config = MoonwellPositionManager.MoonwellPositionManagerConfig({
            inputAccount: BaseAccount(payable(address(0))),
            outputAccount: outputAccount,
            comptrollerAddress: address(comptroller),
            mTokenAddress: address(mToken)
        });
        
        bytes memory encodedConfig = abi.encode(config);
        
        // expect
        vm.expectRevert("Input account can't be zero address");
        
        // when
        new MoonwellPositionManager(owner, processor, encodedConfig);
    }

    function test_RevertConstructor_WithInvalidConfig_WhenOutputAccountIsZeroAddress() public {
        // given
        MoonwellPositionManager.MoonwellPositionManagerConfig memory config = MoonwellPositionManager.MoonwellPositionManagerConfig({
            inputAccount: inputAccount,
            outputAccount: BaseAccount(payable(address(0))),
            comptrollerAddress: address(comptroller),
            mTokenAddress: address(mToken)
        });
        
        bytes memory encodedConfig = abi.encode(config);
        
        // expect
        vm.expectRevert("Output account can't be zero address");
        
        // when
        new MoonwellPositionManager(owner, processor, encodedConfig);
    }

    // ============== Supply Tests ==============

    function test_GivenValidAmount_WhenSupplyIsCalled_ThenMTokensAreMinted() public {
        // given
        uint256 supplyAmount = SUPPLY_AMOUNT;
        uint256 initialMTokenBalance = moonwellPositionManager.getMTokenBalance();
        uint256 initialUnderlyingBalance = underlyingToken.balanceOf(address(inputAccount));
        
        // when
        vm.prank(processor);
        moonwellPositionManager.supply(supplyAmount);
        
        // then
        uint256 finalMTokenBalance = moonwellPositionManager.getMTokenBalance();
        uint256 finalUnderlyingBalance = underlyingToken.balanceOf(address(inputAccount));
        
        assertGt(finalMTokenBalance, initialMTokenBalance, "Should have mTokens after supply");
        assertEq(finalUnderlyingBalance, initialUnderlyingBalance - supplyAmount, "Input account should have reduced underlying balance");
    }

    function test_GivenZeroAmount_WhenSupplyIsCalled_ThenAllUnderlyingIsSupplied() public {
        // given
        uint256 initialMTokenBalance = moonwellPositionManager.getMTokenBalance();
        uint256 initialUnderlyingBalance = underlyingToken.balanceOf(address(inputAccount));
        
        // when
        vm.prank(processor);
        moonwellPositionManager.supply(0);
        
        // then
        uint256 finalMTokenBalance = moonwellPositionManager.getMTokenBalance();
        uint256 finalUnderlyingBalance = underlyingToken.balanceOf(address(inputAccount));
        
        assertGt(finalMTokenBalance, initialMTokenBalance, "Should have mTokens after supply");
        assertEq(finalUnderlyingBalance, 0, "Input account should have no underlying balance left");
    }

    function test_RevertSupply_WithUnauthorized_WhenCallerIsNotProcessor() public {
        // given
        uint256 supplyAmount = SUPPLY_AMOUNT;
        
        // expect
        vm.expectRevert();
        
        // when
        vm.prank(user);
        moonwellPositionManager.supply(supplyAmount);
    }

    // ============== Withdraw Tests ==============

    function test_GivenValidAmount_WhenWithdrawIsCalled_ThenUnderlyingIsRedeemed() public {
        // given
        vm.prank(processor);
        moonwellPositionManager.supply(SUPPLY_AMOUNT);
        
        uint256 withdrawAmount = SUPPLY_AMOUNT / 2;
        uint256 initialMTokenBalance = moonwellPositionManager.getMTokenBalance();
        uint256 initialUnderlyingBalance = underlyingToken.balanceOf(address(inputAccount));
        
        // when
        vm.prank(processor);
        moonwellPositionManager.withdraw(withdrawAmount);
        
        // then
        uint256 finalMTokenBalance = moonwellPositionManager.getMTokenBalance();
        uint256 finalUnderlyingBalance = underlyingToken.balanceOf(address(inputAccount));
        
        assertLt(finalMTokenBalance, initialMTokenBalance, "mToken balance should decrease");
        assertGt(finalUnderlyingBalance, initialUnderlyingBalance, "Underlying balance should increase");
    }

    function test_GivenFullAmount_WhenWithdrawIsCalled_ThenAllMTokensAreRedeemed() public {
        // given
        vm.prank(processor);
        moonwellPositionManager.supply(SUPPLY_AMOUNT);
        
        uint256 mTokenBalance = moonwellPositionManager.getMTokenBalance();
        
        // when
        vm.prank(processor);
        moonwellPositionManager.withdraw(mTokenBalance);
        
        // then
        uint256 finalMTokenBalance = moonwellPositionManager.getMTokenBalance();
        assertEq(finalMTokenBalance, 0, "Should have no mTokens after full withdrawal");
    }

    function test_RevertWithdraw_WithUnauthorized_WhenCallerIsNotProcessor() public {
        // given
        uint256 withdrawAmount = SUPPLY_AMOUNT;
        
        // expect
        vm.expectRevert();
        
        // when
        vm.prank(user);
        moonwellPositionManager.withdraw(withdrawAmount);
    }

    // ============== Borrow Tests ==============

    function test_GivenValidAmount_WhenBorrowIsCalled_ThenUnderlyingIsBorrowed() public {
        // given
        vm.prank(processor);
        moonwellPositionManager.enterMarket();
        
        uint256 borrowAmount = BORROW_AMOUNT;
        uint256 initialUnderlyingBalance = underlyingToken.balanceOf(address(inputAccount));
        
        // when
        vm.prank(processor);
        moonwellPositionManager.borrow(borrowAmount);
        
        // then
        uint256 borrowBalance = moonwellPositionManager.getBorrowBalance();
        uint256 finalUnderlyingBalance = underlyingToken.balanceOf(address(inputAccount));
        
        assertEq(borrowBalance, borrowAmount, "Should have correct borrow balance");
        assertEq(finalUnderlyingBalance, initialUnderlyingBalance + borrowAmount, "Input account should have received borrowed tokens");
    }

    function test_RevertBorrow_WithUnauthorized_WhenCallerIsNotProcessor() public {
        // given
        uint256 borrowAmount = BORROW_AMOUNT;
        
        // expect
        vm.expectRevert();
        
        // when
        vm.prank(user);
        moonwellPositionManager.borrow(borrowAmount);
    }

    // ============== Repay Tests ==============

    function test_GivenValidAmount_WhenRepayIsCalled_ThenBorrowBalanceDecreases() public {
        // given
        vm.prank(processor);
        moonwellPositionManager.enterMarket();
        
        vm.prank(processor);
        moonwellPositionManager.borrow(BORROW_AMOUNT);
        
        uint256 repayAmount = BORROW_AMOUNT / 2;
        uint256 initialBorrowBalance = moonwellPositionManager.getBorrowBalance();
        
        // when
        vm.prank(processor);
        moonwellPositionManager.repay(repayAmount);
        
        // then
        uint256 finalBorrowBalance = moonwellPositionManager.getBorrowBalance();
        assertLt(finalBorrowBalance, initialBorrowBalance, "Borrow balance should decrease");
    }

    function test_GivenZeroAmount_WhenRepayIsCalled_ThenAllBorrowIsRepaid() public {
        // given
        vm.prank(processor);
        moonwellPositionManager.enterMarket();
        
        vm.prank(processor);
        moonwellPositionManager.borrow(BORROW_AMOUNT);
        
        // when
        vm.prank(processor);
        moonwellPositionManager.repay(0);
        
        // then
        uint256 finalBorrowBalance = moonwellPositionManager.getBorrowBalance();
        assertEq(finalBorrowBalance, 0, "Should have no borrow balance after full repayment");
    }

    function test_RevertRepay_WithUnauthorized_WhenCallerIsNotProcessor() public {
        // given
        uint256 repayAmount = BORROW_AMOUNT;
        
        // expect
        vm.expectRevert();
        
        // when
        vm.prank(user);
        moonwellPositionManager.repay(repayAmount);
    }
} 