// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/src/Test.sol";
import {EulerPositionManager} from "../../src/libraries/EulerPositionManager.sol";
import {IERC20} from "forge-std/src/interfaces/IERC20.sol";
import {BaseAccount} from "../../src/accounts/BaseAccount.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockEulerMarkets} from "../mocks/MockEulerMarkets.sol";
import {MockBaseAccount} from "../mocks/MockBaseAccount.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IEulerMarkets} from "../../src/libraries/interfaces/euler/IEulerMarkets.sol";

contract EulerPositionManagerTest is Test {
    // Contract under test
    EulerPositionManager public eulerPositionManager;

    // Mock contracts
    MockBaseAccount public inputAccount;
    MockBaseAccount public outputAccount;
    MockERC20 public testToken;
    MockEulerMarkets public eulerMarkets;

    // Test addresses
    address public owner;
    address public processor;

    // Test parameters
    uint256 public subAccountId = 0; // Primary account
    address public testAsset;

    // Setup function to initialize test environment
    function setUp() public {
        // Setup test addresses
        owner = makeAddr("owner");
        processor = makeAddr("processor");

        // Deploy mock contracts
        testToken = new MockERC20("Test Token", "TT", 18);
        testAsset = address(testToken);
        eulerMarkets = new MockEulerMarkets();

        // Create mock accounts
        vm.startPrank(owner);
        inputAccount = new MockBaseAccount();
        outputAccount = new MockBaseAccount();
        vm.stopPrank();

        // Deploy EulerPositionManager contract
        vm.startPrank(owner);

        // Create and encode config directly
        EulerPositionManager.EulerPositionManagerConfig memory config = EulerPositionManager
            .EulerPositionManagerConfig({
            inputAccount: BaseAccount(payable(address(inputAccount))),
            outputAccount: BaseAccount(payable(address(outputAccount))),
            marketsAddress: address(eulerMarkets),
            subAccountId: subAccountId
        });

        eulerPositionManager = new EulerPositionManager(owner, processor, abi.encode(config));
        vm.stopPrank();

        vm.label(address(inputAccount), "inputAccount");
        vm.label(address(outputAccount), "outputAccount");
        vm.label(address(testToken), "testToken");
        vm.label(address(eulerMarkets), "eulerMarkets");
    }

    // ============== Configuration Tests ==============

    function test_GivenValidConfig_WhenContractIsDeployed_ThenConfigIsSet() public view {
        (
            BaseAccount actualInputAccount,
            BaseAccount actualOutputAccount,
            address actualMarketsAddress,
            uint256 actualSubAccountId
        ) = eulerPositionManager.config();

        assertEq(address(actualInputAccount), address(inputAccount));
        assertEq(address(actualOutputAccount), address(outputAccount));
        assertEq(actualMarketsAddress, address(eulerMarkets));
        assertEq(actualSubAccountId, subAccountId);
    }

    function test_GivenValidConfig_WhenUpdateConfigIsCalled_ThenConfigIsUpdated() public {
        // given
        MockERC20 newToken = new MockERC20("New Token", "NT", 18);
        MockEulerMarkets newMarkets = new MockEulerMarkets();
        EulerPositionManager.EulerPositionManagerConfig memory newConfig = EulerPositionManager
            .EulerPositionManagerConfig({
            inputAccount: new BaseAccount(owner, new address[](0)),
            outputAccount: new BaseAccount(owner, new address[](0)),
            marketsAddress: address(newMarkets),
            subAccountId: 1
        });

        // when
        vm.prank(owner);
        eulerPositionManager.updateConfig(abi.encode(newConfig));

        // then
        (
            BaseAccount actualInputAccount,
            BaseAccount actualOutputAccount,
            address actualMarketsAddress,
            uint256 actualSubAccountId
        ) = eulerPositionManager.config();
        assertEq(address(actualInputAccount), address(newConfig.inputAccount));
        assertEq(address(actualOutputAccount), address(newConfig.outputAccount));
        assertEq(actualMarketsAddress, newConfig.marketsAddress);
        assertEq(actualSubAccountId, newConfig.subAccountId);
    }

    function test_RevertUpdateConfig_WithInvalidConfig_WhenInputAccountIsZeroAddress() public {
        // given
        EulerPositionManager.EulerPositionManagerConfig memory newConfig = EulerPositionManager
            .EulerPositionManagerConfig({
            inputAccount: BaseAccount(payable(address(0))),
            outputAccount: new BaseAccount(owner, new address[](0)),
            marketsAddress: address(eulerMarkets),
            subAccountId: subAccountId
        });

        // expect
        vm.expectRevert("Input account can't be zero address");

        // when
        vm.prank(owner);
        eulerPositionManager.updateConfig(abi.encode(newConfig));
    }

    function test_RevertUpdateConfig_WithInvalidConfig_WhenOutputAccountIsZeroAddress() public {
        // given
        EulerPositionManager.EulerPositionManagerConfig memory newConfig = EulerPositionManager
            .EulerPositionManagerConfig({
            inputAccount: new BaseAccount(owner, new address[](0)),
            outputAccount: BaseAccount(payable(address(0))),
            marketsAddress: address(eulerMarkets),
            subAccountId: subAccountId
        });

        // expect
        vm.expectRevert("Output account can't be zero address");

        // when
        vm.prank(owner);
        eulerPositionManager.updateConfig(abi.encode(newConfig));
    }

    function test_RevertUpdateConfig_WithInvalidConfig_WhenMarketsAddressIsZeroAddress() public {
        // given
        EulerPositionManager.EulerPositionManagerConfig memory newConfig = EulerPositionManager
            .EulerPositionManagerConfig({
            inputAccount: new BaseAccount(owner, new address[](0)),
            outputAccount: new BaseAccount(owner, new address[](0)),
            marketsAddress: address(0),
            subAccountId: subAccountId
        });

        // expect
        vm.expectRevert("Markets address can't be zero address");

        // when
        vm.prank(owner);
        eulerPositionManager.updateConfig(abi.encode(newConfig));
    }

    function test_RevertUpdateConfig_WithUnauthorized_WhenCallerIsNotOwner() public {
        // given
        address unauthorized = makeAddr("unauthorized");
        MockEulerMarkets newMarkets = new MockEulerMarkets();
        EulerPositionManager.EulerPositionManagerConfig memory newConfig = EulerPositionManager
            .EulerPositionManagerConfig({
            inputAccount: new BaseAccount(owner, new address[](0)),
            outputAccount: new BaseAccount(owner, new address[](0)),
            marketsAddress: address(newMarkets),
            subAccountId: subAccountId
        });

        // expect
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, unauthorized));

        // when
        vm.prank(unauthorized);
        eulerPositionManager.updateConfig(abi.encode(newConfig));
    }

    // ============== Supply Tests ==============

    function test_GivenValidAmount_WhenSupplyIsCalled_ThenSupplyAmountIsEqual() public {
        // given
        uint256 exactAmount = 1000 * 10 ** 18;
        vm.prank(owner);
        testToken.mint(address(inputAccount), exactAmount * 2);

        // when
        vm.prank(processor);
        eulerPositionManager.supply(testAsset, exactAmount);

        // then
        vm.expectRevert();
        MockBaseAccount(inputAccount).executeParams(2);
        (address target, uint256 amount, bytes memory data) = MockBaseAccount(inputAccount).executeParams(1);
        assertEq(target, address(eulerMarkets), "Target should be the markets address");
        assertEq(amount, 0, "Value should be zero for supply call");
        bytes memory expectedData = abi.encodeWithSelector(
            IEulerMarkets.supplyFrom.selector, subAccountId, testAsset, exactAmount, address(inputAccount)
        );
        assertEq(data, expectedData, "Data should be the encoded supplyFrom call");
    }

    function test_GivenZeroAmount_WhenSupplyIsCalled_ThenSupplyAmountIsEntireBalance() public {
        // given
        uint256 balance = 500 * 10 ** 18;
        vm.prank(owner);
        testToken.mint(address(inputAccount), balance);

        // when
        vm.prank(processor);
        eulerPositionManager.supply(testAsset, 0);

        // then
        vm.expectRevert();
        MockBaseAccount(inputAccount).executeParams(2);
        (address target, uint256 amount, bytes memory data) = MockBaseAccount(inputAccount).executeParams(1);
        assertEq(target, address(eulerMarkets), "Target should be the markets address");
        assertEq(amount, 0, "Value should be zero for supply call");
        bytes memory expectedData = abi.encodeWithSelector(
            IEulerMarkets.supplyFrom.selector, subAccountId, testAsset, balance, address(inputAccount)
        );
        assertEq(data, expectedData, "Data should be the encoded supplyFrom call");
    }

    function test_GivenValidAmount_WhenSupplyIsCalled_ThenApproveAmountOnMarkets() public {
        // given
        uint256 balance = 500 * 10 ** 18;
        vm.prank(owner);
        testToken.mint(address(inputAccount), balance);

        // when
        vm.prank(processor);
        eulerPositionManager.supply(testAsset, 0);

        // then
        vm.expectRevert();
        MockBaseAccount(inputAccount).executeParams(2);
        (address target, uint256 value, bytes memory data) = MockBaseAccount(inputAccount).executeParams(0);
        assertEq(target, address(testToken), "Target should be the token address");
        assertEq(value, 0, "Value should be zero for approve call");
        bytes memory expectedData = abi.encodeWithSelector(IERC20.approve.selector, address(eulerMarkets), balance);
        assertEq(data, expectedData, "Data should be the encoded approve call");
    }

    function test_RevertSupply_WhenCallerIsNotProcessor() public {
        // given
        address unauthorized = makeAddr("unauthorized");
        uint256 amount = 1000 * 10 ** 18;

        // expect
        vm.expectRevert("Only the processor can call this function");

        // when
        vm.prank(unauthorized);
        eulerPositionManager.supply(testAsset, amount);
    }

    // ============== Withdraw Tests ==============

    function test_GivenValidAmount_WhenWithdrawIsCalled_ThenWithdrawAmountIsEqual() public {
        // given
        uint256 exactAmount = 250 ether;

        // when
        vm.prank(processor);
        eulerPositionManager.withdraw(testAsset, exactAmount);

        // then
        vm.expectRevert();
        MockBaseAccount(inputAccount).executeParams(1);
        (address target, uint256 value, bytes memory data) = MockBaseAccount(inputAccount).executeParams(0);
        assertEq(target, address(eulerMarkets), "Target should be the markets address");
        assertEq(value, 0, "Value should be zero for withdrawTo call");
        bytes memory expectedData = abi.encodeWithSelector(
            IEulerMarkets.withdrawTo.selector, subAccountId, testAsset, exactAmount, address(outputAccount)
        );
        assertEq(data, expectedData, "Data should be the encoded withdrawTo call");
    }

    function test_GivenZeroAmount_WhenWithdrawIsCalled_ThenWithdrawAmountIsUintMax() public {
        // given
        uint256 exactAmount = 0;

        // when
        vm.prank(processor);
        eulerPositionManager.withdraw(testAsset, exactAmount);

        // then
        vm.expectRevert();
        MockBaseAccount(inputAccount).executeParams(1);
        (address target, uint256 value, bytes memory data) = MockBaseAccount(inputAccount).executeParams(0);
        assertEq(target, address(eulerMarkets), "Target should be the markets address");
        assertEq(value, 0, "Value should be zero for withdrawTo call");
        bytes memory expectedData = abi.encodeWithSelector(
            IEulerMarkets.withdrawTo.selector, subAccountId, testAsset, type(uint256).max, address(outputAccount)
        );
        assertEq(data, expectedData, "Data should be the encoded withdrawTo call");
    }

    function test_RevertWithdraw_WhenCallerIsNotProcessor() public {
        // given
        address unauthorized = makeAddr("unauthorized");
        uint256 amount = 1000 * 10 ** 18;

        // expect
        vm.expectRevert("Only the processor can call this function");

        // when
        vm.prank(unauthorized);
        eulerPositionManager.withdraw(testAsset, amount);
    }

    // ============== Borrow Tests ==============

    function test_GivenValidAmount_WhenBorrowIsCalled_ThenBorrowAmountIsEqual() public {
        // given
        uint256 exactAmount = 100 ether;

        // when
        vm.prank(processor);
        eulerPositionManager.borrow(testAsset, exactAmount);

        // then
        vm.expectRevert();
        MockBaseAccount(inputAccount).executeParams(1);
        (address target, uint256 value, bytes memory data) = MockBaseAccount(inputAccount).executeParams(0);
        assertEq(target, address(eulerMarkets), "Target should be the markets address");
        assertEq(value, 0, "Value should be zero for borrow call");
        bytes memory expectedData = abi.encodeWithSelector(
            IEulerMarkets.borrow.selector, subAccountId, testAsset, exactAmount
        );
        assertEq(data, expectedData, "Data should be the encoded borrow call");
    }

    function test_RevertBorrow_WhenCallerIsNotProcessor() public {
        // given
        address unauthorized = makeAddr("unauthorized");
        uint256 amount = 1000 * 10 ** 18;

        // expect
        vm.expectRevert("Only the processor can call this function");

        // when
        vm.prank(unauthorized);
        eulerPositionManager.borrow(testAsset, amount);
    }

    // ============== Repay Tests ==============

    function test_GivenValidAmount_WhenRepayIsCalled_ThenRepayAmountIsEqual() public {
        // given
        uint256 exactAmount = 100 * 10 ** 18;
        vm.prank(owner);
        testToken.mint(address(inputAccount), exactAmount * 2);

        // when
        vm.prank(processor);
        eulerPositionManager.repay(testAsset, exactAmount);

        // then
        vm.expectRevert();
        MockBaseAccount(inputAccount).executeParams(2);
        (address target, uint256 amount, bytes memory data) = MockBaseAccount(inputAccount).executeParams(1);
        assertEq(target, address(eulerMarkets), "Target should be the markets address");
        assertEq(amount, 0, "Value should be zero for repay call");
        bytes memory expectedData = abi.encodeWithSelector(
            IEulerMarkets.repayFrom.selector, subAccountId, testAsset, exactAmount, address(inputAccount)
        );
        assertEq(data, expectedData, "Data should be the encoded repayFrom call");
    }

    function test_GivenZeroAmount_WhenRepayIsCalled_ThenRepayAmountIsEntireBalance() public {
        // given
        uint256 balance = 500 * 10 ** 18;
        vm.prank(owner);
        testToken.mint(address(inputAccount), balance);

        // when
        vm.prank(processor);
        eulerPositionManager.repay(testAsset, 0);

        // then
        vm.expectRevert();
        MockBaseAccount(inputAccount).executeParams(2);
        (address target, uint256 amount, bytes memory data) = MockBaseAccount(inputAccount).executeParams(1);
        assertEq(target, address(eulerMarkets), "Target should be the markets address");
        assertEq(amount, 0, "Value should be zero for repay call");
        bytes memory expectedData = abi.encodeWithSelector(
            IEulerMarkets.repayFrom.selector, subAccountId, testAsset, balance, address(inputAccount)
        );
        assertEq(data, expectedData, "Data should be the encoded repayFrom call");
    }

    function test_GivenValidAmount_WhenRepayIsCalled_ThenApproveAmountOnMarkets() public {
        // given
        uint256 balance = 500 * 10 ** 18;
        vm.prank(owner);
        testToken.mint(address(inputAccount), balance);

        // when
        vm.prank(processor);
        eulerPositionManager.repay(testAsset, balance);

        // then
        vm.expectRevert();
        MockBaseAccount(inputAccount).executeParams(2);
        (address target, uint256 value, bytes memory data) = MockBaseAccount(inputAccount).executeParams(0);
        assertEq(target, address(testToken), "Target should be the token address");
        assertEq(value, 0, "Value should be zero for approve call");
        bytes memory expectedData = abi.encodeWithSelector(IERC20.approve.selector, address(eulerMarkets), balance);
        assertEq(data, expectedData, "Data should be the encoded approve call");
    }

    function test_RevertRepay_WhenCallerIsNotProcessor() public {
        // given
        address unauthorized = makeAddr("unauthorized");
        uint256 amount = 1000 * 10 ** 18;

        // expect
        vm.expectRevert("Only the processor can call this function");

        // when
        vm.prank(unauthorized);
        eulerPositionManager.repay(testAsset, amount);
    }

    // ============== View Function Tests ==============

    function test_GetSupplyBalance() public {
        // given
        uint256 expectedBalance = 1000 * 10 ** 18;
        eulerMarkets.setBalance(address(inputAccount), subAccountId, testAsset, expectedBalance);

        // when
        uint256 actualBalance = eulerPositionManager.getSupplyBalance(testAsset);

        // then
        assertEq(actualBalance, expectedBalance, "Supply balance should match expected value");
    }

    function test_GetBorrowBalance() public {
        // given
        uint256 expectedBalance = 500 * 10 ** 18;
        eulerMarkets.setBorrowBalance(address(inputAccount), subAccountId, testAsset, expectedBalance);

        // when
        uint256 actualBalance = eulerPositionManager.getBorrowBalance(testAsset);

        // then
        assertEq(actualBalance, expectedBalance, "Borrow balance should match expected value");
    }

    function test_GetSupplyRate() public {
        // given
        uint256 expectedRate = 50000000000000000000000000; // 5% APY scaled by 1e27
        eulerMarkets.setSupplyRate(testAsset, expectedRate);

        // when
        uint256 actualRate = eulerPositionManager.getSupplyRate(testAsset);

        // then
        assertEq(actualRate, expectedRate, "Supply rate should match expected value");
    }

    function test_GetBorrowRate() public {
        // given
        uint256 expectedRate = 80000000000000000000000000; // 8% APY scaled by 1e27
        eulerMarkets.setBorrowRate(testAsset, expectedRate);

        // when
        uint256 actualRate = eulerPositionManager.getBorrowRate(testAsset);

        // then
        assertEq(actualRate, expectedRate, "Borrow rate should match expected value");
    }
} 