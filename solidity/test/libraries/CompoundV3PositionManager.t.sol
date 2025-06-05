// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/src/Test.sol";
import {CompoundV3PositionManager} from "../../src/libraries/CompoundV3PositionManager.sol";
import {IERC20} from "forge-std/src/interfaces/IERC20.sol";
import {BaseAccount} from "../../src/accounts/BaseAccount.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockCompoundV3Market} from "../mocks/MockCompoundV3Market.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CompoundV3PositionManagerTest is Test {
    // Contract under test
    CompoundV3PositionManager public compoundV3PositionManager;

    // Mock contracts
    BaseAccount public inputAccount;
    BaseAccount public outputAccount;
    MockERC20 public baseToken;
    address public marketProxyAddress;

    // Test addresses
    address public owner;
    address public processor;

    // Setup function to initialize test environment
    function setUp() public {
        // Setup test addresses
        owner = makeAddr("owner");
        processor = makeAddr("processor");

        // Deploy mock tokens
        baseToken = new MockERC20("Base Token", "BT", 18);
        marketProxyAddress = address(new MockCompoundV3Market(address(baseToken)));
        // Create mock accounts
        vm.startPrank(owner);
        inputAccount = new BaseAccount(owner, new address[](0));
        outputAccount = new BaseAccount(owner, new address[](0));
        vm.stopPrank();

        // Deploy CompoundV3PositionManager contract
        vm.startPrank(owner);

        // Create and encode config directly
        CompoundV3PositionManager.CompoundV3PositionManagerConfig memory config = CompoundV3PositionManager.CompoundV3PositionManagerConfig({
            inputAccount: inputAccount,
            outputAccount: outputAccount,
            baseAsset: address(baseToken),
            marketProxyAddress: marketProxyAddress
        });

        compoundV3PositionManager = new CompoundV3PositionManager(owner, processor, abi.encode(config));
        inputAccount.approveLibrary(address(compoundV3PositionManager));
        vm.stopPrank();
    }

    // ============== Configuration Tests ==============

    function test_GivenValidConfig_WhenContractIsDeployed_ThenConfigIsSet() public {
        (BaseAccount actualInputAccount, BaseAccount actualOutputAccount, address actualBaseAsset, address actualMarketProxyAddress) = compoundV3PositionManager.config();

        assertEq(address(actualInputAccount), address(inputAccount));
        assertEq(address(actualOutputAccount), address(outputAccount));
        assertEq(actualBaseAsset, address(baseToken));
        assertEq(actualMarketProxyAddress, marketProxyAddress);

    }

    function test_GivenValidConfig_WhenUpdateConfigIsCalled_ThenConfigIsUpdated() public {
        // given
        MockERC20 newBaseToken = new MockERC20("New Base Token", "NBT", 18);
        CompoundV3PositionManager.CompoundV3PositionManagerConfig memory newConfig = CompoundV3PositionManager.CompoundV3PositionManagerConfig({
            inputAccount: new BaseAccount(owner, new address[](0)),
            outputAccount: new BaseAccount(owner, new address[](0)),
            baseAsset: address(newBaseToken),
            marketProxyAddress: address(new MockCompoundV3Market(address(newBaseToken)))
        });

        // when
        vm.prank(owner);
        compoundV3PositionManager.updateConfig(abi.encode(newConfig));

        // then
        (BaseAccount actualInputAccount, BaseAccount actualOutputAccount, address actualBaseAsset, address actualMarketProxyAddress) = compoundV3PositionManager.config();
        assertEq(address(actualInputAccount), address(newConfig.inputAccount));
        assertEq(address(actualOutputAccount), address(newConfig.outputAccount));
        assertEq(actualBaseAsset, newConfig.baseAsset);
        assertEq(actualMarketProxyAddress, newConfig.marketProxyAddress);
    }

    function test_RevertUpdateConfig_WithInvalidConfig_WhenInputAccountIsZeroAddress() public {
        // given
        CompoundV3PositionManager.CompoundV3PositionManagerConfig memory newConfig = CompoundV3PositionManager.CompoundV3PositionManagerConfig({
            inputAccount: BaseAccount(payable(address(0))),
            outputAccount: new BaseAccount(owner, new address[](0)),
            baseAsset: vm.randomAddress(),
            marketProxyAddress: makeAddr("newMarketProxyAddress")
        });

        // expect
        vm.expectRevert("Input account can't be zero address");

        // when
        vm.prank(owner);
        compoundV3PositionManager.updateConfig(abi.encode(newConfig));
    }

    function test_RevertUpdateConfig_WithInvalidConfig_WhenOutputAccountIsZeroAddress() public {
        // given
        CompoundV3PositionManager.CompoundV3PositionManagerConfig memory newConfig = CompoundV3PositionManager.CompoundV3PositionManagerConfig({
            inputAccount: new BaseAccount(owner, new address[](0)),
            outputAccount: BaseAccount(payable(address(0))),
            baseAsset: vm.randomAddress(),
            marketProxyAddress: makeAddr("newMarketProxyAddress")
        });

        // expect
        vm.expectRevert("Output account can't be zero address");

        // when
        vm.prank(owner);
        compoundV3PositionManager.updateConfig(abi.encode(newConfig));
    }

    function test_RevertUpdateConfig_WithInvalidConfig_WhenMarketBaseAssetAndGivenBaseAssetAreNotSame() public {
        // given
        CompoundV3PositionManager.CompoundV3PositionManagerConfig memory newConfig = CompoundV3PositionManager.CompoundV3PositionManagerConfig({
            inputAccount: new BaseAccount(owner, new address[](0)),
            outputAccount: new BaseAccount(owner, new address[](0)),
            baseAsset: vm.randomAddress(),
            marketProxyAddress: marketProxyAddress
        });

        // expect
        vm.expectRevert("Market base asset and given base asset are not same");

        // when
        vm.prank(owner);
        compoundV3PositionManager.updateConfig(abi.encode(newConfig));
    }

    function test_RevertUpdateConfig_WithInvalidConfig_WhenMarketProxyAddressIsZeroAddress() public {
        // given
        CompoundV3PositionManager.CompoundV3PositionManagerConfig memory newConfig = CompoundV3PositionManager.CompoundV3PositionManagerConfig({
            inputAccount: new BaseAccount(owner, new address[](0)),
            outputAccount: new BaseAccount(owner, new address[](0)),
            baseAsset: address(baseToken),
            marketProxyAddress: address(0)
        });

        // expect
        vm.expectRevert("Market proxy address can't be zero address");

        // when
        vm.prank(owner);
        compoundV3PositionManager.updateConfig(abi.encode(newConfig));
    }

    function test_RevertUpdateConfig_WithUnauthorized_WhenCallerIsNotOwner() public {
         // given
        address unauthorized = makeAddr("unauthorized");
        MockERC20 newBaseToken = new MockERC20("New Base Token", "NBT", 18);
        CompoundV3PositionManager.CompoundV3PositionManagerConfig memory newConfig = CompoundV3PositionManager.CompoundV3PositionManagerConfig({
            inputAccount: new BaseAccount(owner, new address[](0)),
            outputAccount: new BaseAccount(owner, new address[](0)),
            baseAsset: address(newBaseToken),
            marketProxyAddress: address(new MockCompoundV3Market(address(newBaseToken)))
        });

        // expect
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, unauthorized));

        // when
        vm.prank(unauthorized);
        compoundV3PositionManager.updateConfig(abi.encode(newConfig));
    }

    // ============== Supply Tests ==============

    function test_GivenValidConfig_WhenSupplyIsCalled_ThenSupplyIsSuccessful() public {
        // given
        uint256 amount = 1000 * 10 ** 18;
        vm.prank(owner);
        baseToken.mint(address(inputAccount), amount);

        // when
        vm.prank(processor);
        compoundV3PositionManager.supply(amount);
        
        // then 
        uint256 remainingBalance = baseToken.balanceOf(address(inputAccount));
        assertEq(remainingBalance, 0, "Input account should have no remaining balance after supply");
    }

    function test_GivenValidConfigAndZeroAmount_WhenSupplyIsCalled_ThenEntireBalanceIsSupplied() public {
        // given
        uint256 balance = 500 * 10 ** 18;
        vm.prank(owner);
        baseToken.mint(address(inputAccount), balance);

        // when 
        vm.prank(processor);
        compoundV3PositionManager.supply(0);
        
        // then 
        uint256 remainingBalance = baseToken.balanceOf(address(inputAccount));
        assertEq(remainingBalance, 0, "Input account should have no remaining balance after supplying entire balance");
    }

    function test_RevertSupply_WhenNoBaseAssetBalanceAvailable() public {
        // given
        // don't mint any tokens (zero balance)
        
        // expect
        vm.expectRevert("No base asset balance available");

        // when
        vm.prank(processor);
        compoundV3PositionManager.supply(100 * 10 ** 18);
    }

    function test_RevertSupply_WhenInsufficientBaseAssetBalance() public {
        // given
        uint256 balance = 100 * 10 ** 18;
        uint256 requestedAmount = 200 * 10 ** 18;
        vm.prank(owner);
        baseToken.mint(address(inputAccount), balance);

        // expect
        vm.expectRevert("Insufficient base asset balance");

        // when
        vm.prank(processor);
        compoundV3PositionManager.supply(requestedAmount);
    }

    function test_RevertSupply_WhenCallerIsNotProcessor() public {
        // given
        address unauthorized = makeAddr("unauthorized");
        uint256 amount = 1000 * 10 ** 18;
        vm.prank(owner);
        baseToken.mint(address(inputAccount), amount);

        // expect 
        vm.expectRevert();

        // when
        vm.prank(unauthorized);
        compoundV3PositionManager.supply(amount);
    }

    function test_GivenExactBalance_WhenSupplyIsCalledWithSameAmount_ThenSupplyIsSuccessful() public {
        // given
        uint256 exactAmount = 250 * 10 ** 18;
        vm.prank(owner);
        baseToken.mint(address(inputAccount), exactAmount);

        // when
        vm.prank(processor);
        compoundV3PositionManager.supply(exactAmount);
        
        // then - verify supply was successful
        uint256 remainingBalance = baseToken.balanceOf(address(inputAccount));
        assertEq(remainingBalance, 0, "Input account should have no remaining balance after supplying exact amount");
    }

    function test_GivenPartialAmount_WhenSupplyIsCalled_ThenOnlyRequestedAmountIsSupplied() public {
        // given
        uint256 totalBalance = 1000 * 10 ** 18;
        uint256 supplyAmount = 300 * 10 ** 18;
        vm.prank(owner);
        baseToken.mint(address(inputAccount), totalBalance);

        // when
        vm.prank(processor);
        compoundV3PositionManager.supply(supplyAmount);
        
        // then - verify only the requested amount was supplied
        uint256 remainingBalance = baseToken.balanceOf(address(inputAccount));
        uint256 expectedRemaining = totalBalance - supplyAmount;
        assertEq(remainingBalance, expectedRemaining, "Input account should have correct remaining balance after partial supply");
    }

    // ============== Withdraw Tests ==============

    function test_GivenValidConfig_WhenWithdrawIsCalled_ThenWithdrawIsSuccessful() public {
        // given
        uint256 amount = 1000 * 10 ** 18;
        vm.prank(owner);
        baseToken.mint(address(inputAccount), amount);

        // when
        vm.prank(processor);
        compoundV3PositionManager.withdraw(amount);

        // then 
        uint256 remainingBalance = baseToken.balanceOf(address(inputAccount));
        assertEq(remainingBalance, 0, "Input account should have no remaining balance after withdraw");
    }

    function test_GivenValidConfigAndZeroAmount_WhenWithdrawIsCalled_ThenEntireBalanceIsWithdrawn() public {
        // given
        uint256 balance = 500 * 10 ** 18;
        vm.prank(owner);
        baseToken.mint(address(inputAccount), balance);

        // when
        vm.prank(processor);
        compoundV3PositionManager.withdraw(0);

        // then
        uint256 remainingBalance = baseToken.balanceOf(address(inputAccount));
        assertEq(remainingBalance, 0, "Input account should have no remaining balance after withdraw");
    }

    function test_RevertWithdraw_WhenNoBaseAssetBalanceAvailable() public {
        // given
        // don't mint any tokens (zero balance)

        // expect
        vm.expectRevert("No base asset balance available");

        // when
        vm.prank(processor);
        compoundV3PositionManager.withdraw(100 * 10 ** 18);
    }

    function test_RevertWithdraw_WhenInsufficientBaseAssetBalance() public {
        // given
        uint256 balance = 100 * 10 ** 18;
        uint256 requestedAmount = 200 * 10 ** 18;
        vm.prank(owner);
        baseToken.mint(address(inputAccount), balance);

        // expect
        vm.expectRevert("Insufficient base asset balance");

        // when
        vm.prank(processor);
        compoundV3PositionManager.withdraw(requestedAmount);
    }

 }
