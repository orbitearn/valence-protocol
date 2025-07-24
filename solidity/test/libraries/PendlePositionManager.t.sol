// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Test} from "forge-std/src/Test.sol";
import {PendlePositionManager} from "../../src/libraries/PendlePositionManager.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockPendleMarket} from "./mocks/MockPendleMarket.sol";
import {BaseAccount} from "../../src/accounts/BaseAccount.sol";

contract PendlePositionManagerTest is Test {
    address owner = address(0x1);
    address processor = address(0x2);
    BaseAccount inputAccount;
    BaseAccount outputAccount;
    address user = address(0x4);
    uint256[] maturities = [1680000000, 1690000000];
    uint256 defaultMaturity = 1680000000;
    uint256 otherMaturity = 1690000000;
    uint256 notAllowedMaturity = 1700000000;
    uint256 initialUnderlying = 1_000_000e18;
    uint256 mintAmount = 1_000e18;

    MockERC20 underlying;
    MockERC20 ptToken;
    MockPendleMarket market;
    PendlePositionManager manager;

    function setUp() public {
        vm.startPrank(owner);
        inputAccount = new BaseAccount(owner, new address[](0));
        outputAccount = new BaseAccount(owner, new address[](0));
        underlying = new MockERC20("Underlying", "UND", 18);
        ptToken = new MockERC20("PT", "PT", 18);
        market = new MockPendleMarket(address(underlying));
        market.setPTToken(defaultMaturity, address(ptToken));
        market.setPTToken(otherMaturity, address(ptToken));
        // Prepare config struct
        PendlePositionManager.PendlePositionManagerConfig memory config = PendlePositionManager.PendlePositionManagerConfig({
            inputAccount: inputAccount,
            outputAccount: outputAccount,
            pendleMarket: address(market),
            underlyingAsset: address(underlying),
            ptToken: address(ptToken),
            allowedMaturities: maturities
        });
        bytes memory configBytes = abi.encode(config);
        manager = new PendlePositionManager(owner, processor, configBytes);
        underlying.mint(user, initialUnderlying);
        // Approve manager as library for input/output accounts
        vm.startPrank(owner);
        inputAccount.approveLibrary(address(manager));
        outputAccount.approveLibrary(address(manager));
        vm.stopPrank();
    }

    function test_MintPT() public {
        // Given
        vm.startPrank(user);
        underlying.approve(address(manager), mintAmount);
        vm.stopPrank();
        // When
        vm.prank(processor);
        manager.mintPT(user, mintAmount, defaultMaturity);
        // Then
        assertEq(underlying.balanceOf(user), initialUnderlying - mintAmount, "Underlying deducted");
        // PT minted to user via mock
        assertEq(ptToken.balanceOf(user), mintAmount, "PT minted");
    }

    function test_MintPT_InvalidMaturity() public {
        // Given
        vm.startPrank(user);
        underlying.approve(address(manager), mintAmount);
        vm.stopPrank();
        // Then
        vm.prank(processor);
        vm.expectRevert("Maturity not allowed");
        manager.mintPT(user, mintAmount, notAllowedMaturity);
    }

    function test_MintPT_InsufficientBalance() public {
        // Given
        vm.startPrank(user);
        underlying.approve(address(manager), initialUnderlying + 1);
        vm.stopPrank();
        // Then
        vm.prank(processor);
        vm.expectRevert("Insufficient underlying balance");
        manager.mintPT(user, initialUnderlying + 1, defaultMaturity);
    }

    function test_MintPT_AccessControl() public {
        // Given
        vm.startPrank(user);
        underlying.approve(address(manager), mintAmount);
        vm.stopPrank();
        // Then
        vm.prank(user);
        vm.expectRevert("Only the processor can call this function");
        manager.mintPT(user, mintAmount, defaultMaturity);
    }

    function test_RedeemPT() public {
        // Given
        vm.startPrank(user);
        underlying.approve(address(manager), mintAmount);
        vm.stopPrank();
        vm.prank(processor);
        manager.mintPT(user, mintAmount, defaultMaturity);
        vm.startPrank(user);
        ptToken.approve(address(manager), mintAmount);
        vm.stopPrank();
        // When
        vm.prank(processor);
        manager.redeemPT(user, mintAmount, defaultMaturity);
        // Then
        assertEq(ptToken.balanceOf(user), 0, "PT burned");
        assertEq(underlying.balanceOf(user), initialUnderlying, "Underlying returned");
    }

    function test_RedeemPT_InvalidMaturity() public {
        // Given
        vm.startPrank(user);
        underlying.approve(address(manager), mintAmount);
        vm.stopPrank();
        vm.prank(processor);
        manager.mintPT(user, mintAmount, defaultMaturity);
        vm.startPrank(user);
        ptToken.approve(address(manager), mintAmount);
        vm.stopPrank();
        // Then
        vm.prank(processor);
        vm.expectRevert("Maturity not allowed");
        manager.redeemPT(user, mintAmount, notAllowedMaturity);
    }

    function test_RedeemPT_InsufficientPT() public {
        // Given
        vm.startPrank(user);
        underlying.approve(address(manager), mintAmount);
        ptToken.approve(address(manager), mintAmount + 1);
        vm.stopPrank();
        vm.prank(processor);
        manager.mintPT(user, mintAmount, defaultMaturity);
        // Then
        vm.prank(processor);
        vm.expectRevert("Insufficient PT balance");
        manager.redeemPT(user, mintAmount + 1, defaultMaturity);
    }

    function test_RedeemPT_AccessControl() public {
        // Given
        vm.startPrank(user);
        underlying.approve(address(manager), mintAmount);
        ptToken.approve(address(manager), mintAmount);
        vm.stopPrank();
        vm.prank(processor);
        manager.mintPT(user, mintAmount, defaultMaturity);
        // Then
        vm.prank(user);
        vm.expectRevert("Only the processor can call this function");
        manager.redeemPT(user, mintAmount, defaultMaturity);
    }

    function test_AddRemoveAllowedMaturity() public {
        // Given
        vm.prank(owner);
        manager.addAllowedMaturity(notAllowedMaturity);
        vm.prank(owner);
        market.setPTToken(notAllowedMaturity, address(ptToken));
        vm.startPrank(user);
        underlying.approve(address(manager), mintAmount);
        vm.stopPrank();
        vm.prank(processor);
        manager.mintPT(user, mintAmount, notAllowedMaturity);
        assertEq(ptToken.balanceOf(user), mintAmount, "PT minted for new maturity");
        // When
        vm.prank(owner);
        manager.removeAllowedMaturity(notAllowedMaturity);
        // Then
        vm.startPrank(user);
        underlying.approve(address(manager), mintAmount);
        vm.stopPrank();
        vm.prank(processor);
        vm.expectRevert("Maturity not allowed");
        manager.mintPT(user, mintAmount, notAllowedMaturity);
    }

    function test_OnlyOwnerCanManageMaturities() public {
        // Given
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        manager.addAllowedMaturity(notAllowedMaturity);
        vm.prank(user);
        // Then
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        manager.removeAllowedMaturity(defaultMaturity);
    }
} 