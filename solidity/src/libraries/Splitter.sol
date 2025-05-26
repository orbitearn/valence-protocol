// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Splitter
 * @dev A library for splitting funds from one input account to multiple output accounts
 * according to configured ratios. Supports both native ETH and ERC20 tokens.
 */
contract Splitter is Ownable, ReentrancyGuard {
    struct SplitConfig {
        address token;          
        address account;      
        uint256 amount;      
        bool isFixedAmount;  
    }

    struct DynamicRatioConfig {
        address oracleContract;  
        bytes params;           
    }

    address public inputAccount;
    
    mapping(address => SplitConfig[]) public splitConfigs;
    
    mapping(address => DynamicRatioConfig) public dynamicRatioConfigs;

    event SplitExecuted(address indexed token, uint256 totalAmount);
    event SplitConfigUpdated(address indexed token, address indexed account, uint256 amount, bool isFixedAmount);
    event DynamicRatioConfigUpdated(address indexed token, address indexed oracleContract);

    constructor(address _inputAccount) Ownable(msg.sender) {
        require(_inputAccount != address(0), "Invalid input account");
        inputAccount = _inputAccount;
    }

    /**
     * @dev Updates the input account address
     * @param _inputAccount New input account address
     */
    function updateInputAccount(address _inputAccount) external onlyOwner {
        require(_inputAccount != address(0), "Invalid input account");
        inputAccount = _inputAccount;
    }

    /**
     * @dev Adds or updates a split configuration
     * @param token Token address (address(0) for native ETH)
     * @param account Output account address
     * @param amount Fixed amount or ratio in basis points
     * @param isFixedAmount Whether the amount is fixed or a ratio
     */
    function updateSplitConfig(
        address token,
        address account,
        uint256 amount,
        bool isFixedAmount
    ) external onlyOwner {
        require(account != address(0), "Invalid account address");
        require(amount > 0, "Amount must be greater than 0");
        
        if (isFixedAmount) {
            require(amount <= type(uint256).max, "Amount too large");
        } else {
            require(amount <= 10000, "Ratio must be <= 100%");
        }

        SplitConfig[] storage configs = splitConfigs[token];
        
        for (uint256 i = 0; i < configs.length; i++) {
            if (configs[i].account == account) {
                configs[i].amount = amount;
                configs[i].isFixedAmount = isFixedAmount;
                emit SplitConfigUpdated(token, account, amount, isFixedAmount);
                return;
            }
        }

        configs.push(SplitConfig({
            token: token,
            account: account,
            amount: amount,
            isFixedAmount: isFixedAmount
        }));

        emit SplitConfigUpdated(token, account, amount, isFixedAmount);
    }

    /**
     * @dev Sets up dynamic ratio configuration for a token
     * @param token Token address
     * @param oracleContract Address of the oracle contract
     * @param params Additional parameters for the oracle
     */
    function setDynamicRatioConfig(
        address token,
        address oracleContract,
        bytes calldata params
    ) external onlyOwner {
        require(oracleContract != address(0), "Invalid oracle contract");
        dynamicRatioConfigs[token] = DynamicRatioConfig({
            oracleContract: oracleContract,
            params: params
        });
        emit DynamicRatioConfigUpdated(token, oracleContract);
    }

    /**
     * @dev Executes the split operation for a specific token
     * @param token Token address (address(0) for native ETH)
     */
    function split(address token) external nonReentrant {
        SplitConfig[] storage configs = splitConfigs[token];
        require(configs.length > 0, "No split configurations found");

        uint256 totalAmount;
        if (token == address(0)) {
            totalAmount = address(this).balance;
        } else {
            totalAmount = IERC20(token).balanceOf(address(this));
        }
        require(totalAmount > 0, "No funds to split");

        uint256 remainingAmount = totalAmount;
        uint256 lastIndex = configs.length - 1;

        for (uint256 i = 0; i < configs.length; i++) {
            SplitConfig storage config = configs[i];
            uint256 amount;

            if (config.isFixedAmount) {
                amount = config.amount;
            } else {
                amount = (totalAmount * config.amount) / 10000;
            }

            if (i == lastIndex) {
                amount = remainingAmount;
            }

            if (amount > 0) {
                if (token == address(0)) {
                    (bool success, ) = config.account.call{value: amount}("");
                    require(success, "ETH transfer failed");
                } else {
                    require(
                        IERC20(token).transfer(config.account, amount),
                        "Token transfer failed"
                    );
                }
                remainingAmount -= amount;
            }
        }

        emit SplitExecuted(token, totalAmount);
    }

    /**
     * @dev Executes split with dynamic ratio from oracle
     * @param token Token address
     */
    function splitWithDynamicRatio(address token) external nonReentrant {
        DynamicRatioConfig storage config = dynamicRatioConfigs[token];
        require(config.oracleContract != address(0), "No dynamic ratio config");

        (bool success, bytes memory result) = config.oracleContract.call(
            abi.encodeWithSignature(
                "getDynamicRatio(address,bytes)",
                token,
                config.params
            )
        );
        require(success, "Oracle call failed");

        uint256 ratio = abi.decode(result, (uint256));
        require(ratio <= 10000, "Invalid ratio from oracle");

        SplitConfig[] storage configs = splitConfigs[token];
        require(configs.length > 0, "No split configurations found");
        
        configs[0].amount = ratio;
        configs[0].isFixedAmount = false;

        split(token);
    }

    receive() external payable {}
} 