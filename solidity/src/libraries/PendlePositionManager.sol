// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {BaseAccount} from "../accounts/BaseAccount.sol";
import {Library} from "./Library.sol";
import {IPendleMarket} from "./interfaces/pendle/IPendleMarket.sol";
import {IPendlePT} from "./interfaces/pendle/IPendlePT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PendlePositionManager is Library {
    struct PendlePositionManagerConfig {
        BaseAccount inputAccount;
        BaseAccount outputAccount;
        address pendleMarket;
        address underlyingAsset;
        address ptToken;
        uint256[] allowedMaturities;
    }

    PendlePositionManagerConfig public config;
    mapping(uint256 => bool) public allowedMaturities;

    event AllowedMaturityAdded(uint256 maturity);
    event AllowedMaturityRemoved(uint256 maturity);
    event MintPT(address indexed account, uint256 amount, uint256 maturity);
    event RedeemPT(address indexed account, uint256 amount, uint256 maturity);

    constructor(address _owner, address _processor, bytes memory _config) Library(_owner, _processor, _config) {}

    function validateConfig(bytes memory _config) internal pure returns (PendlePositionManagerConfig memory) {
        PendlePositionManagerConfig memory decoded = abi.decode(_config, (PendlePositionManagerConfig));
        require(address(decoded.inputAccount) != address(0), "Input account can't be zero address");
        require(address(decoded.outputAccount) != address(0), "Output account can't be zero address");
        require(decoded.pendleMarket != address(0), "Pendle market can't be zero address");
        require(decoded.underlyingAsset != address(0), "Underlying asset can't be zero address");
        require(decoded.ptToken != address(0), "PT token can't be zero address");
        return decoded;
    }

    function _initConfig(bytes memory _config) internal override {
        config = validateConfig(_config);
        // Set allowed maturities
        for (uint256 i = 0; i < config.allowedMaturities.length; i++) {
            allowedMaturities[config.allowedMaturities[i]] = true;
            emit AllowedMaturityAdded(config.allowedMaturities[i]);
        }
    }

    function updateConfig(bytes memory _config) public override onlyOwner {
        config = validateConfig(_config);
        // Reset allowed maturities
        for (uint256 i = 0; i < config.allowedMaturities.length; i++) {
            allowedMaturities[config.allowedMaturities[i]] = true;
            emit AllowedMaturityAdded(config.allowedMaturities[i]);
        }
    }

    modifier onlyAllowedMaturity(uint256 maturity) {
        require(allowedMaturities[maturity], "Maturity not allowed");
        _;
    }

    function addAllowedMaturity(uint256 maturity) external onlyOwner {
        allowedMaturities[maturity] = true;
        emit AllowedMaturityAdded(maturity);
    }

    function removeAllowedMaturity(uint256 maturity) external onlyOwner {
        allowedMaturities[maturity] = false;
        emit AllowedMaturityRemoved(maturity);
    }

    function mintPT(address account, uint256 amount, uint256 maturity)
        external
        onlyProcessor
        onlyAllowedMaturity(maturity)
    {
        require(amount > 0, "Amount must be > 0");
        IERC20 underlying = IERC20(config.underlyingAsset);
        require(underlying.balanceOf(account) >= amount, "Insufficient underlying balance");
        // Transfer underlying from account to inputAccount
        require(underlying.transferFrom(account, address(config.inputAccount), amount), "Transfer failed");
        // Approve Pendle market from inputAccount
        bytes memory approveCall = abi.encodeCall(IERC20.approve, (config.pendleMarket, amount));
        config.inputAccount.execute(config.underlyingAsset, 0, approveCall);
        // Mint PT from inputAccount
        bytes memory mintCall =
            abi.encodeCall(IPendleMarket.mintPT, (config.underlyingAsset, amount, maturity, account));
        config.inputAccount.execute(config.pendleMarket, 0, mintCall);
        emit MintPT(account, amount, maturity);
    }

    function redeemPT(address account, uint256 amount, uint256 maturity)
        external
        onlyProcessor
        onlyAllowedMaturity(maturity)
    {
        require(amount > 0, "Amount must be > 0");
        IPendlePT pt = IPendlePT(config.ptToken);
        require(pt.balanceOf(account) >= amount, "Insufficient PT balance");
        // Transfer PT from account to inputAccount
        require(pt.transferFrom(account, address(config.inputAccount), amount), "PT transfer failed");
        // Approve Pendle market from inputAccount
        bytes memory approveCall = abi.encodeCall(IERC20.approve, (config.pendleMarket, amount));
        config.inputAccount.execute(config.ptToken, 0, approveCall);
        // Redeem PT from inputAccount
        bytes memory redeemCall = abi.encodeCall(IPendleMarket.redeemPT, (config.ptToken, amount, maturity, account));
        config.inputAccount.execute(config.pendleMarket, 0, redeemCall);
        emit RedeemPT(account, amount, maturity);
    }
}
