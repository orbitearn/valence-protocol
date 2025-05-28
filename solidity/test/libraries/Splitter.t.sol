// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import "../../src/accounts/Account.sol" as ValenceAccount;
import {Test, console} from "forge-std/src/Test.sol";
import {Splitter} from "../../src/libraries/Splitter.sol";
import {IERC20} from "forge-std/src/interfaces/IERC20.sol";
import {BaseAccount} from "../../src/accounts/BaseAccount.sol";

// Simple ERC20 mock for testing
contract MockERC20 is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    uint256 private _totalSupply;
    string public name = "Mock Token";
    string public symbol = "MOCK";
    uint8 public decimals = 18;
    
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }
    
    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        
        _transfer(from, to, amount);
        _approve(from, msg.sender, currentAllowance - amount);
        
        return true;
    }
    
    function mint(address to, uint256 amount) external {
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(_balances[from] >= amount, "ERC20: transfer amount exceeds balance");
        
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }
    
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}


contract MockDynamicRatioOracle {
    mapping(address => uint256) public tokenRatios;
    
    function setRatio(address token, uint256 ratio) external {
        tokenRatios[token] = ratio;
    }
    
    function queryDynamicRatio(address token, bytes calldata /*params*/) external view returns (uint256) {
        uint256 ratio = tokenRatios[token];
        return ratio > 0 ? ratio : 300_000_000_000_000_000; // Default 30% if not set
    }
}

contract SplitterTest is Test {
    // Contract under test
    Splitter public splitter;

    // config params
    Splitter.SplitConfig[] splits;

    // Mock contracts
    ValenceAccount.Account public inputAccount;
    ValenceAccount.Account public outputAccount;
    MockERC20 public token;

    // Test addresses
    address public owner;
    address public processor;
    uint16 public referralCode = 0;

    // Setup function to initialize test environment
    function setUp() public {
        // Setup test addresses
        owner = makeAddr("owner");
        processor = makeAddr("processor");

        // Deploy mock tokens
        token = new MockERC20();

        // Create mock accounts
        inputAccount = new BaseAccount(owner, new address[](0));
        outputAccount = new BaseAccount(owner, new address[](0));

        // Create sample splits
        splits = new Splitter.SplitConfig[](1);
        splits[0] = Splitter.SplitConfig({
            outputAccount: outputAccount,
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedAmount,
            amount: abi.encode(1)
        });

        // Deploy Splitter contract
        // Create and encode config directly
        Splitter.SplitterConfig memory config = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: splits
        });

        splitter = new Splitter(owner, processor, abi.encode(config));

        vm.prank(owner);
        inputAccount.approveLibrary(address(splitter));
    }

    // ============== Configuration Tests ==============

    // Test configuration validation
    function test_GivenConfigIsValid_WhenOwnerUpdateConfig_ThenUpdateInputAccount() public {
        // given
        ValenceAccount.Account newInputAccount = new BaseAccount(owner, new address[](0));
        Splitter.SplitterConfig memory newConfig = Splitter.SplitterConfig({
            inputAccount: newInputAccount,
            splits: splits
        });

        // when
        vm.prank(owner);
        splitter.updateConfig(abi.encode(newConfig));

        // then
        (ValenceAccount.Account actualInputAccount) = splitter.config();
        assertEq(address(actualInputAccount), address(newInputAccount));
    }

    function test_RevertUpdateConfig_WithUnauthorized_WhenNotOwnerUpdateConfig() public {
        // given
        address unauthorized = makeAddr("unauthorized");
        Splitter.SplitterConfig memory config = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: new Splitter.SplitConfig[](0)
        });

        // expect
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", unauthorized));
        
        // when
        vm.prank(unauthorized);
        splitter.updateConfig(abi.encode(config));
    }

    function test_RevertUpdateConfig_WithEmptySplitsConfig_WhenSplitsArrayIsEmpty() public {
        // given
        Splitter.SplitterConfig memory newConfig = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: new Splitter.SplitConfig[](0)
        });

        // expect
        vm.expectRevert("No split configuration provided.");
        
        // when
        vm.prank(owner);
        splitter.updateConfig(abi.encode(newConfig));
    }

    function test_RevertUpdateConfig_WithDuplicateSplit_WhenSplitsArrayHasTwoIdenticalEntries() public {
        // given
        Splitter.SplitConfig[] memory duplicateSplits = new Splitter.SplitConfig[](2);
        duplicateSplits[0] = Splitter.SplitConfig({
            outputAccount: outputAccount,
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedAmount,
            amount: abi.encode(1)
        });
        duplicateSplits[1] = Splitter.SplitConfig({
            outputAccount: outputAccount,
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedAmount,
            amount: abi.encode(1)
        });
        Splitter.SplitterConfig memory newConfig = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: duplicateSplits
        });

        // expect
        vm.expectRevert("Duplicate split in split config.");
        
        // when
        vm.prank(owner);
        splitter.updateConfig(abi.encode(newConfig));
    }

    function test_RevertUpdateConfig_WithInvalidAmount_WhenFixedAmountSplitHasZeroAmount() public {
        // given
        Splitter.SplitConfig[] memory zeroAmountSplit = new Splitter.SplitConfig[](1);
        zeroAmountSplit[0] = Splitter.SplitConfig({
            outputAccount: outputAccount,
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedAmount,
            amount: abi.encode(0)
        });
        Splitter.SplitterConfig memory newConfig = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: zeroAmountSplit
        });

        // expect
        vm.expectRevert("Invalid split config: amount cannot be zero.");
        
        // when
        vm.prank(owner);
        splitter.updateConfig(abi.encode(newConfig));
    }

    function test_RevertUpdateConfig_WithInvalidRatio_WhenFixedRatioSplitHasZeroRatio() public {
        // given
        Splitter.SplitConfig[] memory zeroRatioSplit = new Splitter.SplitConfig[](1);
        zeroRatioSplit[0] = Splitter.SplitConfig({
            outputAccount: outputAccount,
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedRatio,
            amount: abi.encode(0)
        });
        Splitter.SplitterConfig memory newConfig = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: zeroRatioSplit
        });

        // expect
        vm.expectRevert("Invalid split config: ratio cannot be zero.");
        
        // when
        vm.prank(owner);
        splitter.updateConfig(abi.encode(newConfig));
    }

    function test_RevertUpdateConfig_WithInvalidRatio_WhenFixedRatioSplitsSumIsGreaterThanOne() public {
        // given
        Splitter.SplitConfig[] memory gt1RatioSplit = new Splitter.SplitConfig[](3);
        gt1RatioSplit[0] = Splitter.SplitConfig({
            outputAccount: new BaseAccount(owner, new address[](0)),
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedRatio,
            amount: abi.encode(1_000_000_000_000_000_000)
        });
        gt1RatioSplit[1] = Splitter.SplitConfig({
            outputAccount: new BaseAccount(owner, new address[](0)),
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedRatio,
            amount: abi.encode(1_000_000_000_000_000_000)
        });
        gt1RatioSplit[2] = Splitter.SplitConfig({
            outputAccount: new BaseAccount(owner, new address[](0)),
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedRatio,
            amount: abi.encode(1_000_000_000_000_000_000)
        });
        Splitter.SplitterConfig memory newConfig = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: gt1RatioSplit
        });

        // expect
        vm.expectRevert("Invalid split config: sum of ratios is not equal to 1.");
        
        // when
        vm.prank(owner);
        splitter.updateConfig(abi.encode(newConfig));
    }

    function test_RevertUpdateConfig_WithInvalidRatio_WhenFixedRatioSplitsSumIsLessThanOne() public {
        // given
        Splitter.SplitConfig[] memory lt1RatioSplit = new Splitter.SplitConfig[](3);
        lt1RatioSplit[0] = Splitter.SplitConfig({
            outputAccount: new BaseAccount(owner, new address[](0)),
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedRatio,
            amount: abi.encode(333_000_000_000_000_000)
        });
        lt1RatioSplit[1] = Splitter.SplitConfig({
            outputAccount: new BaseAccount(owner, new address[](0)),
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedRatio,
            amount: abi.encode(333_000_000_000_000_000)
        });
        lt1RatioSplit[2] = Splitter.SplitConfig({
            outputAccount: new BaseAccount(owner, new address[](0)),
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedRatio,
            amount: abi.encode(333_000_000_000_000_000)
        });
        Splitter.SplitterConfig memory newConfig = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: lt1RatioSplit
        });

        // expect
        vm.expectRevert("Invalid split config: sum of ratios is not equal to 1.");
        
        // when
        vm.prank(owner);
        splitter.updateConfig(abi.encode(newConfig));
    }

    function test_RevertUpdateConfig_WithConflictingSplitType_WhenSplitsHasAmountAndRatioTypesCombined() public {
        // given
        Splitter.SplitConfig[] memory conflictingSplits = new Splitter.SplitConfig[](2);
        conflictingSplits[0] = Splitter.SplitConfig({
            outputAccount: new BaseAccount(owner, new address[](0)),
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedRatio,
            amount: abi.encode(1_000_000_000_000_000_000)
        });
        conflictingSplits[1] = Splitter.SplitConfig({
            outputAccount: new BaseAccount(owner, new address[](0)),
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedAmount,
            amount: abi.encode(1_000_000_000_000_000_000)
        });
        Splitter.SplitterConfig memory newConfig = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: conflictingSplits
        });

        // expect
        vm.expectRevert("Invalid split config: cannot combine different split types for same token.");
        
        // when
        vm.prank(owner);
        splitter.updateConfig(abi.encode(newConfig));
    }

    function test_RevertUpdateConfig_WithConflictingSplitType_WhenSplitsHasFixedAndDynamicRatioTypesCombined() public {
        // given
        Splitter.SplitConfig[] memory conflictingSplits = new Splitter.SplitConfig[](2);
        Splitter.DynamicRatioAmount memory dynamicRatioAmount = Splitter.DynamicRatioAmount({
            contractAddress: address(this),
            params: ""
        });
        conflictingSplits[0] = Splitter.SplitConfig({
            outputAccount: new BaseAccount(owner, new address[](0)),
            token: IERC20(token),
            splitType: Splitter.SplitType.DynamicRatio,
            amount: abi.encode(dynamicRatioAmount)
        });
        conflictingSplits[1] = Splitter.SplitConfig({
            outputAccount: new BaseAccount(owner, new address[](0)),
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedRatio,
            amount: abi.encode(1_000_000_000_000_000_000)
        });

        Splitter.SplitterConfig memory newConfig = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: conflictingSplits
        });

        // expect
        vm.expectRevert("Invalid split config: cannot combine different split types for same token.");
        
        // when
        vm.prank(owner);
        splitter.updateConfig(abi.encode(newConfig));
    }

    function test_RevertUpdateConfig_WithInvalidSplitConfig_WhenDynamicRatioSplitHasNonContractAddress() public {
        // given
        Splitter.DynamicRatioAmount memory dynamicRatioAmount = Splitter.DynamicRatioAmount({
            contractAddress: makeAddr("randomEOA"),
            params: ""
        });
        Splitter.SplitConfig[] memory amountAndRatioSplit = new Splitter.SplitConfig[](1);
        amountAndRatioSplit[0] = Splitter.SplitConfig({
            outputAccount: new BaseAccount(owner, new address[](0)),
            token: IERC20(token),
            splitType: Splitter.SplitType.DynamicRatio,
            amount: abi.encode(dynamicRatioAmount)
        });
        Splitter.SplitterConfig memory newConfig = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: amountAndRatioSplit
        });

        // expect
        vm.expectRevert("Invalid split config: dynamic ratio contract address is not a contract");
        
        // when
        vm.prank(owner);
        splitter.updateConfig(abi.encode(newConfig));
    }

    // ============== Split Execution Tests ==============

    function test_GivenFixedAmountSplit_WhenProcessorCallsSplit_ThenTransferCorrectAmount() public {
        // given
        uint256 transferAmount = 1000;
        uint256 initialBalance = 2000;
        
        // Setup split config for fixed amount
        Splitter.SplitConfig[] memory fixedAmountSplits = new Splitter.SplitConfig[](1);
        fixedAmountSplits[0] = Splitter.SplitConfig({
            outputAccount: outputAccount,
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedAmount,
            amount: abi.encode(transferAmount)
        });
        
        Splitter.SplitterConfig memory newConfig = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: fixedAmountSplits
        });
        
        // Update config
        vm.prank(owner);
        splitter.updateConfig(abi.encode(newConfig));
        
        // Mint tokens to input account
        token.mint(address(inputAccount), initialBalance);
        
        // when
        vm.prank(processor);
        splitter.split();
        
        // then
        assertEq(token.balanceOf(address(outputAccount)), transferAmount);
        assertEq(token.balanceOf(address(inputAccount)), initialBalance - transferAmount);
    }

    function test_GivenFixedRatioSplit_WhenProcessorCallsSplit_ThenTransferCorrectRatio() public {
        // given
        uint256 initialBalance = 1000;
        uint256 ratio = 500_000_000_000_000_000; // 50% (0.5 * 10^18)
        uint256 expectedTransfer = (initialBalance * ratio) / (10 ** 18);
        
        // Setup split config for fixed ratio
        Splitter.SplitConfig[] memory fixedRatioSplits = new Splitter.SplitConfig[](1);
        fixedRatioSplits[0] = Splitter.SplitConfig({
            outputAccount: outputAccount,
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedRatio,
            amount: abi.encode(ratio)
        });
        
        Splitter.SplitterConfig memory newConfig = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: fixedRatioSplits
        });
        
        // Update config
        vm.prank(owner);
        splitter.updateConfig(abi.encode(newConfig));
        
        // Mint tokens to input account
        token.mint(address(inputAccount), initialBalance);
        
        // when
        vm.prank(processor);
        splitter.split();
        
        // then
        assertEq(token.balanceOf(address(outputAccount)), expectedTransfer);
        assertEq(token.balanceOf(address(inputAccount)), initialBalance - expectedTransfer);
    }

    function test_GivenFixedRatioSplit_WhenProcessorCallsSplit_ThenTransfer50PercentToEachAccount() public {
        // given
        uint256 initialBalance = 1000;
        uint256 ratio1 = 500_000_000_000_000_000; // 50% (0.5 * 10^18)
        uint256 ratio2 = 500_000_000_000_000_000; // 50% (0.5 * 10^18)
        uint256 expectedTransfer1 = (initialBalance * ratio1) / (10 ** 18);
        uint256 expectedTransfer2 = (initialBalance * ratio2) / (10 ** 18);
        
        // Create second output account
        ValenceAccount.Account outputAccount2 = new BaseAccount(owner, new address[](0));
        
        // Setup split config for 50-50 split
        Splitter.SplitConfig[] memory fixedRatioSplits = new Splitter.SplitConfig[](2);
        fixedRatioSplits[0] = Splitter.SplitConfig({
            outputAccount: outputAccount,
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedRatio,
            amount: abi.encode(ratio1)
        });
        fixedRatioSplits[1] = Splitter.SplitConfig({
            outputAccount: outputAccount2,
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedRatio,
            amount: abi.encode(ratio2)
        });
        
        Splitter.SplitterConfig memory newConfig = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: fixedRatioSplits
        });
        
        // Update config
        vm.prank(owner);
        splitter.updateConfig(abi.encode(newConfig));
        
        // Mint tokens to input account
        token.mint(address(inputAccount), initialBalance);
        
        // when
        vm.prank(processor);
        splitter.split();
        
        // then
        assertEq(token.balanceOf(address(outputAccount)), expectedTransfer1);
        assertEq(token.balanceOf(address(outputAccount2)), expectedTransfer2);
        assertEq(token.balanceOf(address(inputAccount)), 0); // All funds should be split
    }

    function test_GivenMultipleFixedRatioSplits_WhenProcessorCallsSplit_ThenTransferCorrectRatios() public {
        // given
        uint256 initialBalance = 1000;
        ValenceAccount.Account outputAccount2 = new BaseAccount(owner, new address[](0));
        ValenceAccount.Account outputAccount3 = new BaseAccount(owner, new address[](0));
        
        // 30%, 30%, 40% splits (must sum to 100%)
        uint256 ratio1 = 300_000_000_000_000_000; // 30%
        uint256 ratio2 = 300_000_000_000_000_000; // 30%
        uint256 ratio3 = 400_000_000_000_000_000; // 40%
        
        Splitter.SplitConfig[] memory multiRatioSplits = new Splitter.SplitConfig[](3);
        multiRatioSplits[0] = Splitter.SplitConfig({
            outputAccount: outputAccount,
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedRatio,
            amount: abi.encode(ratio1)
        });
        multiRatioSplits[1] = Splitter.SplitConfig({
            outputAccount: outputAccount2,
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedRatio,
            amount: abi.encode(ratio2)
        });
        multiRatioSplits[2] = Splitter.SplitConfig({
            outputAccount: outputAccount3,
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedRatio,
            amount: abi.encode(ratio3)
        });
        
        Splitter.SplitterConfig memory newConfig = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: multiRatioSplits
        });
        
        // Update config
        vm.prank(owner);
        splitter.updateConfig(abi.encode(newConfig));
        
        // Mint tokens to input account
        token.mint(address(inputAccount), initialBalance);
        
        // when
        vm.prank(processor);
        splitter.split();
        
        // then
        uint256 expectedTransfer1 = (initialBalance * ratio1) / (10 ** 18);
        uint256 expectedTransfer2 = (initialBalance * ratio2) / (10 ** 18);
        uint256 expectedTransfer3 = (initialBalance * ratio3) / (10 ** 18);
        
        assertEq(token.balanceOf(address(outputAccount)), expectedTransfer1);
        assertEq(token.balanceOf(address(outputAccount2)), expectedTransfer2);
        assertEq(token.balanceOf(address(outputAccount3)), expectedTransfer3);
    }

    function test_GivenETHSplit_WhenProcessorCallsSplit_ThenTransferETHCorrectly() public {
        // given
        uint256 initialBalance = 1 ether;
        uint256 transferAmount = 0.5 ether;
        
        // Setup split config for ETH (address(0))
        Splitter.SplitConfig[] memory ethSplits = new Splitter.SplitConfig[](1);
        ethSplits[0] = Splitter.SplitConfig({
            outputAccount: outputAccount,
            token: IERC20(address(0)),
            splitType: Splitter.SplitType.FixedAmount,
            amount: abi.encode(transferAmount)
        });
        
        Splitter.SplitterConfig memory newConfig = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: ethSplits
        });
        
        // Update config
        vm.prank(owner);
        splitter.updateConfig(abi.encode(newConfig));
        
        // Send ETH to input account
        vm.deal(address(inputAccount), initialBalance);
        
        // when
        vm.prank(processor);
        splitter.split();
        
        // then
        assertEq(address(outputAccount).balance, transferAmount);
        assertEq(address(inputAccount).balance, initialBalance - transferAmount);
    }

    function test_GivenZeroBalance_WhenProcessorCallsSplit_ThenNoTransfer() public {
        // given - input account has zero balance
        // token balance is already 0 by default
        
        // when
        vm.prank(processor);
        splitter.split();
        
        // then - no transfers should occur
        assertEq(token.balanceOf(address(outputAccount)), 0);
        assertEq(token.balanceOf(address(inputAccount)), 0);
    }

    function test_RevertSplit_WithUnauthorized_WhenNotProcessorCallsSplit() public {
        // given
        address unauthorized = makeAddr("unauthorized");
        
        // expect
        vm.expectRevert("Only the processor can call this function");
        
        // when
        vm.prank(unauthorized);
        splitter.split();
    }


    function test_GivenMultipleTokens_WhenProcessorCallsSplit_ThenSplitEachTokenCorrectly() public {
        // given
        MockERC20 token2 = new MockERC20();
        uint256 initialBalance1 = 1000;
        uint256 initialBalance2 = 2000;
        uint256 transferAmount1 = 300;
        uint256 transferAmount2 = 800;
        
        ValenceAccount.Account outputAccount2 = new BaseAccount(owner, new address[](0));
        
        // Setup split config for multiple tokens
        Splitter.SplitConfig[] memory multiTokenSplits = new Splitter.SplitConfig[](2);
        multiTokenSplits[0] = Splitter.SplitConfig({
            outputAccount: outputAccount,
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedAmount,
            amount: abi.encode(transferAmount1)
        });
        multiTokenSplits[1] = Splitter.SplitConfig({
            outputAccount: outputAccount2,
            token: IERC20(token2),
            splitType: Splitter.SplitType.FixedAmount,
            amount: abi.encode(transferAmount2)
        });
        
        Splitter.SplitterConfig memory newConfig = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: multiTokenSplits
        });
        
        // Update config
        vm.prank(owner);
        splitter.updateConfig(abi.encode(newConfig));
        
        // Mint tokens to input account
        token.mint(address(inputAccount), initialBalance1);
        token2.mint(address(inputAccount), initialBalance2);
        
        // when
        vm.prank(processor);
        splitter.split();
        
        // then
        assertEq(token.balanceOf(address(outputAccount)), transferAmount1);
        assertEq(token.balanceOf(address(inputAccount)), initialBalance1 - transferAmount1);
        assertEq(token2.balanceOf(address(outputAccount2)), transferAmount2);
        assertEq(token2.balanceOf(address(inputAccount)), initialBalance2 - transferAmount2);
    }

    // ============== Dynamic Ratio Tests ==============

    function test_GivenDynamicRatioSplit_WhenProcessorCallsSplit_ThenTransferCorrectDynamicAmount() public {
        // given
        uint256 initialBalance = 1000;
        MockDynamicRatioOracle oracle = new MockDynamicRatioOracle();
        uint256 expectedRatio = 400_000_000_000_000_000; // 40%
        
        // Set the ratio in the oracle
        oracle.setRatio(address(token), expectedRatio);
        
        // Setup dynamic ratio split config
        Splitter.DynamicRatioAmount memory dynamicRatioAmount = Splitter.DynamicRatioAmount({
            contractAddress: address(oracle),
            params: ""
        });
        
        Splitter.SplitConfig[] memory dynamicRatioSplits = new Splitter.SplitConfig[](1);
        dynamicRatioSplits[0] = Splitter.SplitConfig({
            outputAccount: outputAccount,
            token: IERC20(token),
            splitType: Splitter.SplitType.DynamicRatio,
            amount: abi.encode(dynamicRatioAmount)
        });
        
        Splitter.SplitterConfig memory newConfig = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: dynamicRatioSplits
        });
        
        // Update config
        vm.prank(owner);
        splitter.updateConfig(abi.encode(newConfig));
        
        // Mint tokens to input account
        token.mint(address(inputAccount), initialBalance);
        
        // when
        vm.prank(processor);
        splitter.split();
        
        // then
        uint256 expectedTransfer = (initialBalance * expectedRatio) / (10 ** 18);
        assertEq(token.balanceOf(address(outputAccount)), expectedTransfer);
        assertEq(token.balanceOf(address(inputAccount)), initialBalance - expectedTransfer);
    }

    function test_GivenMultipleDynamicRatioSplits_WhenProcessorCallsSplit_ThenTransferCorrectAmounts() public {
        // given
        uint256 initialBalance = 1000;
        MockDynamicRatioOracle oracle = new MockDynamicRatioOracle();
        ValenceAccount.Account outputAccount2 = new BaseAccount(owner, new address[](0));
        
        uint256 ratio1 = 300_000_000_000_000_000; // 30%
        uint256 ratio2 = 250_000_000_000_000_000; // 25%
        
        // Set ratios in the oracle (using different params to distinguish)
        oracle.setRatio(address(token), ratio1); // Default ratio for empty params
        
        // Setup dynamic ratio split configs
        Splitter.DynamicRatioAmount memory dynamicRatioAmount1 = Splitter.DynamicRatioAmount({
            contractAddress: address(oracle),
            params: ""
        });
        
        Splitter.DynamicRatioAmount memory dynamicRatioAmount2 = Splitter.DynamicRatioAmount({
            contractAddress: address(oracle),
            params: abi.encode("different_params")
        });
        
        Splitter.SplitConfig[] memory dynamicRatioSplits = new Splitter.SplitConfig[](2);
        dynamicRatioSplits[0] = Splitter.SplitConfig({
            outputAccount: outputAccount,
            token: IERC20(token),
            splitType: Splitter.SplitType.DynamicRatio,
            amount: abi.encode(dynamicRatioAmount1)
        });
        dynamicRatioSplits[1] = Splitter.SplitConfig({
            outputAccount: outputAccount2,
            token: IERC20(token),
            splitType: Splitter.SplitType.DynamicRatio,
            amount: abi.encode(dynamicRatioAmount2)
        });
        
        Splitter.SplitterConfig memory newConfig = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: dynamicRatioSplits
        });
        
        // Update config
        vm.prank(owner);
        splitter.updateConfig(abi.encode(newConfig));
        
        // Mint tokens to input account
        token.mint(address(inputAccount), initialBalance);
        
        // when
        vm.prank(processor);
        splitter.split();
        
        // then
        uint256 expectedTransfer1 = (initialBalance * ratio1) / (10 ** 18);
        uint256 expectedTransfer2 = (initialBalance * ratio1) / (10 ** 18); // Both use default ratio
        
        assertEq(token.balanceOf(address(outputAccount)), expectedTransfer1);
        assertEq(token.balanceOf(address(outputAccount2)), expectedTransfer2);
    }

    function test_RevertUpdateConfig_WithDynamicRatioAndFixedRatio_WhenMixingDynamicWithOtherTypes() public {
        // given
        MockDynamicRatioOracle oracle = new MockDynamicRatioOracle();
        
        Splitter.DynamicRatioAmount memory dynamicRatioAmount = Splitter.DynamicRatioAmount({
            contractAddress: address(oracle),
            params: ""
        });
        
        Splitter.SplitConfig[] memory mixedSplits = new Splitter.SplitConfig[](2);
        mixedSplits[0] = Splitter.SplitConfig({
            outputAccount: outputAccount,
            token: IERC20(token),
            splitType: Splitter.SplitType.DynamicRatio,
            amount: abi.encode(dynamicRatioAmount)
        });
        mixedSplits[1] = Splitter.SplitConfig({
            outputAccount: new BaseAccount(owner, new address[](0)),
            token: IERC20(token),
            splitType: Splitter.SplitType.FixedRatio,
            amount: abi.encode(500_000_000_000_000_000) // 50%
        });
        
        Splitter.SplitterConfig memory newConfig = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: mixedSplits
        });
        
        // expect
        vm.expectRevert("Invalid split config: cannot combine different split types for same token.");
        
        // when
        vm.prank(owner);
        splitter.updateConfig(abi.encode(newConfig));
    }
}