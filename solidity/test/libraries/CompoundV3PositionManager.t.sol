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

    // GivenValidConfigwhenupdateconfig_ThenConfigIsUpdated
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

//     // ============== Supply Tests ==============

//     function testSupplyWithSpecificAmount() public {
//         // Mint tokens to input account
//         uint256 amount = 1000 * 10 ** 18;
//         vm.prank(owner);
//         supplyToken.mint(address(inputAccount), amount);

//         // Execute supply as processor
//         vm.prank(processor);
//         aavePositionManager.supply(amount);
//     }

//     function testSupplyWithZeroAmount() public {
//         // Mint tokens to input account
//         uint256 balance = 500 * 10 ** 18;
//         vm.prank(owner);
//         supplyToken.mint(address(inputAccount), balance);

//         // Execute supply with 0 (should use entire balance)
//         vm.prank(processor);
//         aavePositionManager.supply(0);
//     }

//     function testSupplyWithNoBalance() public {
//         // Don't mint any tokens (zero balance)

//         // Execute supply operation (should fail)
//         vm.prank(processor);
//         vm.expectRevert("No supply asset balance available");
//         aavePositionManager.supply(100 * 10 ** 18);
//     }

//     function testSupplyWithInsufficientBalance() public {
//         // Mint tokens to input account
//         uint256 balance = 100 * 10 ** 18;
//         vm.prank(owner);
//         supplyToken.mint(address(inputAccount), balance);

//         // Execute supply with amount larger than balance (should fail)
//         vm.prank(processor);
//         vm.expectRevert("Insufficient supply asset balance");
//         aavePositionManager.supply(200 * 10 ** 18);
//     }

//     function testUnauthorizedSupply() public {
//         address unauthorized = makeAddr("unauthorized");

//         // Mint tokens to input account
//         uint256 amount = 1000 * 10 ** 18;
//         vm.prank(owner);
//         supplyToken.mint(address(inputAccount), amount);

//         // Attempt to supply as unauthorized user
//         vm.prank(unauthorized);
//         vm.expectRevert();
//         aavePositionManager.supply(amount);
//     }

//     // ============== Borrow Tests ==============

//     function testBorrow() public {
//         // Execute borrow as processor
//         uint256 amount = 500 * 10 ** 18;
//         vm.prank(processor);
//         aavePositionManager.borrow(amount);
//     }

//     function testUnauthorizedBorrow() public {
//         address unauthorized = makeAddr("unauthorized");

//         // Attempt to borrow as unauthorized user
//         vm.prank(unauthorized);
//         vm.expectRevert();
//         aavePositionManager.borrow(100 * 10 ** 18);
//     }

//     // ============== Withdraw Tests ==============

//     function testWithdraw() public {
//         // Execute withdraw as processor
//         uint256 amount = 300 * 10 ** 18;
//         vm.prank(processor);
//         aavePositionManager.withdraw(amount);
//     }

//     function testUnauthorizedWithdraw() public {
//         address unauthorized = makeAddr("unauthorized");

//         // Attempt to withdraw as unauthorized user
//         vm.prank(unauthorized);
//         vm.expectRevert();
//         aavePositionManager.withdraw(100 * 10 ** 18);
//     }

//     // ============== Repay Tests ==============

//     function testRepayWithSpecificAmount() public {
//         // Mint tokens to input account
//         uint256 amount = 200 * 10 ** 18;
//         vm.prank(owner);
//         borrowToken.mint(address(inputAccount), amount);

//         // Execute repay as processor
//         vm.prank(processor);
//         aavePositionManager.repay(amount);
//     }

//     function testRepayWithZeroAmount() public {
//         // Mint tokens to input account
//         uint256 balance = 150 * 10 ** 18;
//         vm.prank(owner);
//         borrowToken.mint(address(inputAccount), balance);

//         // Execute repay with 0 (should use entire balance)
//         vm.prank(processor);
//         aavePositionManager.repay(0);
//     }

//     function testRepayWithNoBalance() public {
//         // Don't mint any tokens (zero balance)

//         // Execute repay operation (should fail)
//         vm.prank(processor);
//         vm.expectRevert("No borrow asset balance available");
//         aavePositionManager.repay(100 * 10 ** 18);
//     }

//     function testRepayWithInsufficientBalance() public {
//         // Mint tokens to input account
//         uint256 balance = 50 * 10 ** 18;
//         vm.prank(owner);
//         borrowToken.mint(address(inputAccount), balance);

//         // Execute repay with amount larger than balance (should fail)
//         vm.prank(processor);
//         vm.expectRevert("Insufficient borrow asset balance");
//         aavePositionManager.repay(100 * 10 ** 18);
//     }

//     function testUnauthorizedRepay() public {
//         address unauthorized = makeAddr("unauthorized");

//         // Mint tokens to input account
//         uint256 amount = 100 * 10 ** 18;
//         vm.prank(owner);
//         borrowToken.mint(address(inputAccount), amount);

//         // Attempt to repay as unauthorized user
//         vm.prank(unauthorized);
//         vm.expectRevert();
//         aavePositionManager.repay(amount);
//     }

//     // ============== Repay With Shares Tests ==============

//     function testRepayWithShares() public {
//         // Execute repayWithShares as processor
//         uint256 amount = 100 * 10 ** 18;
//         vm.prank(processor);
//         aavePositionManager.repayWithShares(amount);
//         (amount);
//     }

//     function testUnauthorizedRepayWithShares() public {
//         address unauthorized = makeAddr("unauthorized");

//         // Attempt to repayWithShares as unauthorized user
//         vm.prank(unauthorized);
//         vm.expectRevert();
//         aavePositionManager.repayWithShares(100 * 10 ** 18);
//     }
 }
