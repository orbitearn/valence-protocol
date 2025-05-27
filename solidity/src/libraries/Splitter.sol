// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Library} from "./Library.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDynamicRatioOracle} from "./interfaces/splitter/IDynamicRatioOracle.sol";

/**
 * @title Splitter
 * @dev A library for splitting funds from one input account to multiple output accounts
 * according to configured ratios. Supports both native ETH and ERC20 tokens.
 */
contract Splitter is Library {
    enum SplitType {
        FixedAmount,    
        FixedRatio,
        DynamicRatio
    }

    struct SplitConfig {
        address account;      
        uint256 amount;      
        SplitType splitType;
        address oracleContract;     
        bytes oracleParams;     
    }

    struct Config {
        address inputAccount;
        address token;
        SplitConfig[] splitConfigs;
    }

    Config private config;

    event SplitConfigUpdated(
        address indexed account, 
        uint256 amount, 
        SplitType splitType,
        address oracleContract
    );
    event SplitExecuted(uint256 totalAmount);

    constructor(
        address _owner,
        address _processor,
        bytes memory _config
    ) Library(_owner, _processor, _config) {}

    function _initConfig(bytes memory _config) internal override {
        Config memory newConfig = abi.decode(_config, (Config));
        require(newConfig.inputAccount != address(0), "Invalid input account");
        config = newConfig;
    }

    function updateConfig(bytes memory _config) public override onlyOwner {
        Config memory newConfig = abi.decode(_config, (Config));
        require(newConfig.inputAccount != address(0), "Invalid input account");
        config = newConfig;
    }

    function updateInputAccount(address _inputAccount) external onlyOwner {
        require(_inputAccount != address(0), "Invalid input account");
        config.inputAccount = _inputAccount;
    }

    function updateToken(address _token) external onlyOwner {
        config.token = _token;
    }

    function updateSplitConfig(
        address account,
        uint256 amount,
        SplitType splitType,
        address oracleContract,
        bytes calldata oracleParams
    ) external onlyOwner {
        require(account != address(0), "Invalid account address");
        require(amount > 0, "Amount must be greater than 0");
        
        if (splitType == SplitType.FixedAmount) {
            require(amount <= type(uint256).max, "Amount too large");
        } else if (splitType == SplitType.FixedRatio) {
            require(amount <= 10000, "Ratio must be <= 100%");
        } else if (splitType == SplitType.DynamicRatio) {
            require(oracleContract != address(0), "Oracle contract required for dynamic ratio");
        }

        for (uint256 i = 0; i < config.splitConfigs.length; i++) {
            if (config.splitConfigs[i].account == account) {
                config.splitConfigs[i].amount = amount;
                config.splitConfigs[i].splitType = splitType;
                config.splitConfigs[i].oracleContract = oracleContract;
                config.splitConfigs[i].oracleParams = oracleParams;
                emit SplitConfigUpdated(account, amount, splitType, oracleContract);
                return;
            }
        }

        config.splitConfigs.push(SplitConfig({
            account: account,
            amount: amount,
            splitType: splitType,
            oracleContract: oracleContract,
            oracleParams: oracleParams
        }));

        emit SplitConfigUpdated(account, amount, splitType, oracleContract);
    }

    function split() external onlyProcessor {
        require(config.splitConfigs.length > 0, "No split configurations found");

        uint256 totalAmount;
        if (config.token == address(0)) {
            totalAmount = address(this).balance;
        } else {
            totalAmount = IERC20(config.token).balanceOf(address(this));
        }
        require(totalAmount > 0, "No funds to split");

        uint256 totalRequiredAmount;
        for (uint256 i = 0; i < config.splitConfigs.length; i++) {
            SplitConfig storage splitConfig = config.splitConfigs[i];
            uint256 amount;

            if (splitConfig.splitType == SplitType.FixedAmount) {
                amount = splitConfig.amount;
            } else if (splitConfig.splitType == SplitType.FixedRatio) {
                amount = (totalAmount * splitConfig.amount) / 10000;
            } else if (splitConfig.splitType == SplitType.DynamicRatio) {
                string[] memory denoms = new string[](1);
                denoms[0] = config.token == address(0) ? "ETH" : IERC20(config.token).symbol();
                
                uint256 ratio = IDynamicRatioOracle(splitConfig.oracleContract).getDynamicRatio(
                    denoms,
                    string(splitConfig.oracleParams)
                );
                
                require(ratio <= 10000, "Invalid ratio from oracle");
                amount = (totalAmount * ratio) / 10000;
            }
            totalRequiredAmount += amount;
        }

        require(totalRequiredAmount <= totalAmount, "Insufficient balance for split config");

        uint256 remainingAmount = totalAmount;
        uint256 lastIndex = config.splitConfigs.length - 1;

        for (uint256 i = 0; i < config.splitConfigs.length; i++) {
            SplitConfig storage splitConfig = config.splitConfigs[i];
            uint256 amount;

            if (splitConfig.splitType == SplitType.FixedAmount) {
                amount = splitConfig.amount;
            } else if (splitConfig.splitType == SplitType.FixedRatio) {
                amount = (totalAmount * splitConfig.amount) / 10000;
            } else if (splitConfig.splitType == SplitType.DynamicRatio) {
                string[] memory denoms = new string[](1);
                denoms[0] = config.token == address(0) ? "ETH" : IERC20(config.token).symbol();
                
                uint256 ratio = IDynamicRatioOracle(splitConfig.oracleContract).getDynamicRatio(
                    denoms,
                    string(splitConfig.oracleParams)
                );
                
                require(ratio <= 10000, "Invalid ratio from oracle");
                amount = (totalAmount * ratio) / 10000;
            }

            if (i == lastIndex) {
                amount = remainingAmount;
            }

            if (amount > 0) {
                if (config.token == address(0)) {
                    (bool success, ) = splitConfig.account.call{value: amount}("");
                    require(success, "ETH transfer failed");
                } else {
                    require(
                        IERC20(config.token).transfer(splitConfig.account, amount),
                        "Token transfer failed"
                    );
                }
                remainingAmount -= amount;
            }
        }

        emit SplitExecuted(totalAmount);
    }

    receive() external payable {}
} 