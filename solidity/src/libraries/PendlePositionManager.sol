// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {IPendleMarket} from "./interfaces/pendle/IPendleMarket.sol";
import {IPendlePT} from "./interfaces/pendle/IPendlePT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PendlePositionManager {
    address public owner;
    address public processor;
    address public libraryAddress;
    IPendleMarket public pendleMarket;
    IERC20 public underlyingAsset;
    IPendlePT public ptToken;
    mapping(uint256 => bool) public allowedMaturities;

    event AllowedMaturityAdded(uint256 maturity);
    event AllowedMaturityRemoved(uint256 maturity);
    event MintPT(address indexed account, uint256 amount, uint256 maturity);
    event RedeemPT(address indexed account, uint256 amount, uint256 maturity);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyProcessorOrLibrary() {
        require(msg.sender == processor || msg.sender == libraryAddress, "Not processor or library");
        _;
    }

    modifier onlyAllowedMaturity(uint256 maturity) {
        require(allowedMaturities[maturity], "Maturity not allowed");
        _;
    }

    constructor(
        address _processor,
        address _libraryAddress,
        address _pendleMarket,
        address _underlyingAsset,
        address _ptToken,
        uint256[] memory _allowedMaturities
    ) {
        owner = msg.sender;
        processor = _processor;
        libraryAddress = _libraryAddress;
        pendleMarket = IPendleMarket(_pendleMarket);
        underlyingAsset = IERC20(_underlyingAsset);
        ptToken = IPendlePT(_ptToken);
        for (uint256 i = 0; i < _allowedMaturities.length; i++) {
            allowedMaturities[_allowedMaturities[i]] = true;
            emit AllowedMaturityAdded(_allowedMaturities[i]);
        }
    }

    function addAllowedMaturity(uint256 maturity) external onlyOwner {
        allowedMaturities[maturity] = true;
        emit AllowedMaturityAdded(maturity);
    }

    function removeAllowedMaturity(uint256 maturity) external onlyOwner {
        allowedMaturities[maturity] = false;
        emit AllowedMaturityRemoved(maturity);
    }

    function mintPT(address account, uint256 amount, uint256 maturity) external onlyProcessorOrLibrary onlyAllowedMaturity(maturity) {
        require(amount > 0, "Amount must be > 0");
        require(underlyingAsset.balanceOf(account) >= amount, "Insufficient underlying balance");
        // Transfer underlying from account to this contract
        require(underlyingAsset.transferFrom(account, address(this), amount), "Transfer failed");
        // Approve Pendle market
        underlyingAsset.approve(address(pendleMarket), amount);
        // Mint PT
        uint256 ptAmount = pendleMarket.mintPT(address(underlyingAsset), amount, maturity, account);
        emit MintPT(account, ptAmount, maturity);
    }

    function redeemPT(address account, uint256 amount, uint256 maturity) external onlyProcessorOrLibrary onlyAllowedMaturity(maturity) {
        require(amount > 0, "Amount must be > 0");
        require(ptToken.balanceOf(account) >= amount, "Insufficient PT balance");
        // Transfer PT from account to this contract
        require(ptToken.transferFrom(account, address(this), amount), "PT transfer failed");
        // Approve Pendle market
        ptToken.approve(address(pendleMarket), amount);
        // Redeem PT
        uint256 underlyingAmount = pendleMarket.redeemPT(address(ptToken), amount, maturity, account);
        emit RedeemPT(account, amount, maturity);
    }

    function setProcessor(address _processor) external onlyOwner {
        processor = _processor;
    }

    function setLibraryAddress(address _libraryAddress) external onlyOwner {
        libraryAddress = _libraryAddress;
    }
} 