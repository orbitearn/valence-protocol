// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Test} from "forge-std/src/Test.sol";
import {PendlePositionManager} from "../../src/libraries/PendlePositionManager.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockPendleMarket} from "./mocks/MockPendleMarket.sol";

contract PendlePositionManagerTest is Test {
    address owner = address(0x1);
    address processor = address(0x2);
    address libraryAddress = address(0x3);
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
        underlying = new MockERC20("Underlying", "UND", 18);
        ptToken = new MockERC20("PT", "PT", 18);
        market = new MockPendleMarket(address(underlying));
        market.setPTToken(defaultMaturity, address(ptToken));
        market.setPTToken(otherMaturity, address(ptToken));
        manager = new PendlePositionManager(
            processor,
            libraryAddress,
            address(market),
            address(underlying),
            address(ptToken),
            maturities
        );
        underlying.mint(user, initialUnderlying);
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
        assertEq(ptToken.balanceOf(user), mintAmount, "PT minted");
        assertEq(underlying.balanceOf(user), initialUnderlying - mintAmount, "Underlying deducted");
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
        vm.expectRevert("Not processor or library");
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
        vm.expectRevert("Not processor or library");
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
        vm.expectRevert("Not owner");
        manager.addAllowedMaturity(notAllowedMaturity);
        vm.prank(user);
        // Then
        vm.expectRevert("Not owner");
        manager.removeAllowedMaturity(defaultMaturity);
    }

    function test_SetProcessorAndLibrary() public {
        // Given
        address newProcessor = address(0x5);
        address newLibrary = address(0x6);
        // Then
        vm.prank(user);
        vm.expectRevert("Not owner");
        manager.setProcessor(newProcessor);
        vm.prank(user);
        vm.expectRevert("Not owner");
        manager.setLibraryAddress(newLibrary);
        // When
        vm.prank(owner);
        manager.setProcessor(newProcessor);
        assertEq(manager.processor(), newProcessor);
        vm.prank(owner);
        manager.setLibraryAddress(newLibrary);
        assertEq(manager.libraryAddress(), newLibrary);
    }
} 