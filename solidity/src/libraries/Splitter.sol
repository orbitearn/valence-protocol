// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Library} from "./Library.sol";
import {Account} from "../accounts/Account.sol";
import {IERC20} from "forge-std/src/interfaces/IERC20.sol";

/**
 * @title IDynamicRatio
 * @notice Interface for dynamic ratio oracle contracts
 */
interface IDynamicRatio {
    /**
     * @notice Query the dynamic ratio for a given token and parameters
     * @param token The token address to get ratio for
     * @param params Encoded parameters for the oracle
     * @return ratio The dynamic ratio (scaled by 10^18)
     */
    function queryDynamicRatio(address token, bytes calldata params) external view returns (uint256 ratio);
}

/**
 * @title Splitter
 * @dev The Valence Splitter library allows to split funds from one input account to one or more output account(s), 
 * for one or more token denom(s) according to the configured ratio(s). 
 * It is typically used as part of a Valence Program. In that context, 
 * a Processor contract will be the main contract interacting with the Splitter library.
 */
contract Splitter is Library {
    uint256 public constant DECIMALS = 18;

    /**
     * @title SplitterConfig
     * @notice Configuration struct for Aave lending operations
     * @dev Defines splitting parameters 
     * @param inputAccount Address of the input account
     * @param splits Split configuration per token address
     */
    struct SplitterConfig {
        Account inputAccount;
        SplitConfig[] splits;
    }

    /**
     * @title SplitConfig
     * @notice Split config for specified account
     * @dev Used to define the split config for a token to an account
     * @param outputAccount Address of the output account
     * @param token Address of the output account
     * @param splitType type of the split
     * @param amount encoded configuration based on the type of split
     */
    struct SplitConfig {
        Account outputAccount;
        IERC20 token;
        SplitType splitType;
        bytes amount;
    }

    /**
     * @title SplitType
     * @notice enum defining allowed variants of split config
     */
    enum SplitType {
        FixedAmount,    
        FixedRatio,
        DynamicRatio
    }

    /**
     * @title DynamicRatioAmount
     * @notice Params for dynamic ratio split 
     * @dev Used to define the config when split type is DynamicRatio
     * @param contractAddress Address of the dynamic ratio oracle contract
     * @param params Encoded parameters for the oracle
     */
    struct DynamicRatioAmount {
        address contractAddress;
        bytes params;
    }

    /// @notice Holds the current configuration for the Splitter.
    SplitterConfig public config;

    /// @notice Holds the splitConfig against output account against split token.
    mapping(IERC20 => mapping(Account => SplitConfig)) splitConfigMapping;
    mapping(IERC20 => uint256) tokenRatioSplitSum;
    mapping(IERC20 => uint256) tokenAmountSplitSum;

    /// @notice Cache for dynamic ratios to avoid repeated queries within the same transaction
    /// @dev Maps keccak256(token, contractAddr, params) to cached ratio
    mapping(bytes32 => uint256) private dynamicRatioCache;
    
    /// @notice Tracks which dynamic ratios have been cached in current transaction
    mapping(bytes32 => bool) private dynamicRatioCached;

    event SplitExecuted(uint256 totalAmount);
    event DynamicRatioQueried(address indexed token, address indexed oracle, bytes32 indexed key, uint256 ratio);

    /**
     * @dev Constructor initializes the contract with the owner, processor, and initial configuration.
     * @param _owner Address of the contract owner.
     * @param _processor Address of the processor that can execute functions.
     * @param _config Encoded configuration parameters for the Splitter.
     */
    constructor(address _owner, address _processor, bytes memory _config) Library(_owner, _processor, _config) {}

    /**
     * @notice Validates the provided configuration parameters
     * @dev Checks for validity of input account, and splits
     * @param _config The encoded configuration bytes to validate
     * @return SplitterConfig A validated configuration struct
     */
    function validateConfig(bytes memory _config) internal returns (SplitterConfig memory) {
        // Decode the configuration bytes into the SplitterConfig struct.
        SplitterConfig memory decodedConfig = abi.decode(_config, (SplitterConfig));

        // Ensure the input account address is valid (non-zero).
        if (decodedConfig.inputAccount == Account(payable(address(0)))) {
            revert("Input account can't be zero address");
        }

        deleteSplitsInState();
        validateSplits(decodedConfig.splits);

        return decodedConfig;
    }

    /**
     * @notice Validates the provided splits configuration
     * @dev Checks for duplicate split, sum of ratios to 1 and dynamic ratio contract address to be valid smart contract
     * @param splits The array of SplitConfig to validate
     */
    function validateSplits(SplitConfig[] memory splits) internal {
        require(splits.length > 0, "No split configuration provided.");

        for (uint256 i = 0; i < splits.length; i++) {
            SplitConfig memory splitConfig = splits[i];
            
            if (address(splitConfigMapping[splitConfig.token][splitConfig.outputAccount].outputAccount) != address(0)) {
                revert("Duplicate split in split config.");
            }

            if(splitConfig.splitType == SplitType.FixedAmount) {
                uint256 decodedAmount = abi.decode(splitConfig.amount, (uint256));
                require(decodedAmount > 0, "Invalid split config: amount cannot be zero.");

                tokenAmountSplitSum[splitConfig.token] += decodedAmount;
            } else if(splitConfig.splitType == SplitType.FixedRatio) {
                uint256 decodedAmount = abi.decode(splitConfig.amount, (uint256));
                require(decodedAmount > 0, "Invalid split config: ratio cannot be zero.");

                tokenRatioSplitSum[splitConfig.token] += decodedAmount;
            } else {
                DynamicRatioAmount memory dynamicRatioAmount = abi.decode(splitConfig.amount, (DynamicRatioAmount));
                require(tokenAmountSplitSum[splitConfig.token] == 0 && tokenRatioSplitSum[splitConfig.token] == 0, "Invalid split config: cannot combine different split types for same token.");
                require(dynamicRatioAmount.contractAddress.code.length > 0, "Invalid split config: dynamic ratio contract address is not a contract");
            }

            splitConfigMapping[splitConfig.token][splitConfig.outputAccount] = splitConfig;
        }
        
        // checking if sum of all ratios is 1 and conflicting types are not provided
        for (uint256 i = 0; i < splits.length; i++) {
            SplitConfig memory splitConfig = splits[i];
            
            if(splitConfig.splitType == SplitType.FixedAmount) {
                require(tokenRatioSplitSum[splitConfig.token] == 0, "Invalid split config: cannot combine different split types for same token.");
            } else if(splitConfig.splitType == SplitType.FixedRatio) {
                require(tokenRatioSplitSum[splitConfig.token] == 10 ** DECIMALS, "Invalid split config: sum of ratios is not equal to 1.");
                require(tokenAmountSplitSum[splitConfig.token] == 0, "Invalid split config: cannot combine different split types for same token.");
            } else {
                require(tokenAmountSplitSum[splitConfig.token] == 0 && tokenRatioSplitSum[splitConfig.token] == 0, "Invalid split config: cannot combine different split types for same token.");
            }
        }
    }

    /**
     * @notice Checks if any split for a given token uses dynamic ratio
     * @param splits The array of splits to check
     * @param token The token to check for
     * @return true if any split for the token uses dynamic ratio
     */
    function hasDynamicRatioForToken(SplitConfig[] memory splits, IERC20 token) internal pure returns (bool) {
        for (uint256 i = 0; i < splits.length; i++) {
            if (splits[i].token == token && splits[i].splitType == SplitType.DynamicRatio) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice deletes the existing splits in state
     * @dev Useful to be used before updating config
     */
    function deleteSplitsInState() internal {
        for (uint256 i = 0; i < config.splits.length; i++) {
            SplitConfig memory splitConfig = config.splits[i];
            
            delete tokenRatioSplitSum[splitConfig.token];
            delete tokenAmountSplitSum[splitConfig.token];
            delete splitConfigMapping[splitConfig.token][splitConfig.outputAccount];
        }
    }

    /**
     * @dev Internal initialization function called during construction
     * @param _config New configuration
     */
    function _initConfig(bytes memory _config) internal override {
        config = validateConfig(_config);
    }

    /**
     * @dev Updates the Splitter configuration.
     * Only the contract owner is authorized to call this function.
     * @param _config New encoded configuration parameters.
     */
    function updateConfig(bytes memory _config) public override onlyOwner {
        config = validateConfig(_config);
    }

    /**
     * @notice Executes the split operation based on the configured splits
     * @dev Splits funds from the input account to output accounts according to configured ratios
     * Only the processor can call this function
     */
    function split() external onlyProcessor {
        require(config.splits.length > 0, "No split configurations found");

        uint256 totalAmountSplit = 0;
        // Get unique tokens and their balances
        IERC20[] memory uniqueTokens = getUniqueTokens();
        for (uint256 i = 0; i < uniqueTokens.length; i++) {
            IERC20 token = uniqueTokens[i];
            uint256 balance;
            
            if (address(token) == address(0)) {
                balance = address(config.inputAccount).balance;
            } else {
                balance = token.balanceOf(address(config.inputAccount));
            }
            
            if (balance == 0) continue;
            
            // Process all splits for this token
            totalAmountSplit += processSplitsForToken(token, balance);
        }

        emit SplitExecuted(totalAmountSplit); 
    }

    /**
     * @notice Processes all splits for a specific token
     * @param token The token to process splits for
     * @param totalBalance The total balance available for this token
     */
    function processSplitsForToken(IERC20 token, uint256 totalBalance) internal returns (uint256) {
        // Calculate amounts for each split - inspired by Rust implementation
        SplitConfig[] memory tokenSplits = getSplitsForToken(token);
        
        uint256 totalAmountSplit = 0;
        for (uint256 i = 0; i < tokenSplits.length; i++) {
            SplitConfig memory splitConfig = tokenSplits[i];
            uint256 amount = calculateSplitAmount(splitConfig, totalBalance);
            
            if (amount > 0) {
                transferFunds(config.inputAccount, splitConfig.outputAccount, token, amount);
                totalAmountSplit += amount;
            }
        }
        return totalAmountSplit;
    }

    /**
     * @notice Calculates the split amount based on the split configuration
     * @param splitConfig The split configuration
     * @param totalBalance The total balance available for splitting
     * @return The calculated split amount
     */
    function calculateSplitAmount(SplitConfig memory splitConfig, uint256 totalBalance) internal returns (uint256) {
        if (splitConfig.splitType == SplitType.FixedAmount) {
            return abi.decode(splitConfig.amount, (uint256));
        } else if (splitConfig.splitType == SplitType.FixedRatio) {
            uint256 ratio = abi.decode(splitConfig.amount, (uint256));
            // Using multiply_ratio equivalent: (balance * numerator) / denominator
            return (totalBalance * ratio) / (10 ** DECIMALS);
        } else if (splitConfig.splitType == SplitType.DynamicRatio) {
            DynamicRatioAmount memory dynamicRatioAmount = abi.decode(splitConfig.amount, (DynamicRatioAmount));
            // Get dynamic ratio from oracle contract
            uint256 ratio = getDynamicRatio(splitConfig.token, dynamicRatioAmount.contractAddress, dynamicRatioAmount.params);
            return (totalBalance * ratio) / (10 ** DECIMALS);
        }
        return 0;
    }

    /**
     * @notice Gets dynamic ratio from oracle contract with caching
     * @param token The token for which to get the ratio
     * @param contractAddr The oracle contract address
     * @param params The parameters for the oracle
     * @return The dynamic ratio (scaled by 10^18)
     */
    function getDynamicRatio(IERC20 token, address contractAddr, bytes memory params) internal returns (uint256) {
        bytes32 key = generateDynamicRatioKey(address(token), contractAddr, params);
        
        if (dynamicRatioCached[key]) {
            return dynamicRatioCache[key];
        }
        
        // Query the oracle contract
        uint256 ratio = queryDynamicRatioFromOracle(contractAddr, address(token), params);
        
        // Cache the result
        dynamicRatioCache[key] = ratio;
        dynamicRatioCached[key] = true;
        
        emit DynamicRatioQueried(address(token), contractAddr, key, ratio);
        
        return ratio;
    }

    /**
     * @notice Generates a unique key for dynamic ratio caching
     * @param token The token address
     * @param contractAddr The oracle contract address
     * @param params The oracle parameters
     * @return The generated cache key
     */
    function generateDynamicRatioKey(
        address token,
        address contractAddr,
        bytes memory params
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(token, contractAddr, params));
    }

    /**
     * @notice Queries dynamic ratio from oracle contract
     * @param contractAddr The oracle contract address
     * @param token The token address
     * @param params The oracle parameters
     * @return The dynamic ratio from oracle
     */
    function queryDynamicRatioFromOracle(
        address contractAddr,
        address token,
        bytes memory params
    ) internal view returns (uint256) {
        try IDynamicRatio(contractAddr).queryDynamicRatio(token, params) returns (uint256 ratio) {
            require(ratio <= 10 ** DECIMALS, "Dynamic ratio exceeds maximum (1.0)");
            return ratio;
        } catch {
            return 0;
        }
    }

    /**
     * @notice Transfers funds from input account to output account
     * @param from The input account
     * @param to The output account
     * @param token The token to transfer (address(0) for ETH)
     * @param amount The amount to transfer
     */
    function transferFunds(Account from, Account to, IERC20 token, uint256 amount) internal {
        if (address(token) == address(0)) {
            bytes memory data = "";
            from.execute(address(to), amount, data);
        } else { 
            bytes memory transferData = abi.encodeWithSelector(
                IERC20.transfer.selector,
                address(to),
                amount
            );
            from.execute(address(token), 0, transferData);
        }
    }

    /**
     * @notice Gets unique tokens from all split configurations
     * @return Array of unique tokens
     */
    function getUniqueTokens() internal view returns (IERC20[] memory) {
        IERC20[] memory tokens = new IERC20[](config.splits.length);
        uint256 uniqueCount = 0;
        
        for (uint256 i = 0; i < config.splits.length; i++) {
            IERC20 token = config.splits[i].token;
            bool exists = false;
            
            for (uint256 j = 0; j < uniqueCount; j++) {
                if (tokens[j] == token) {
                    exists = true;
                    break;
                }
            }
            
            if (!exists) {
                tokens[uniqueCount] = token;
                uniqueCount++;
            }
        }
        
        // Resize array to actual unique count
        IERC20[] memory uniqueTokens = new IERC20[](uniqueCount);
        for (uint256 i = 0; i < uniqueCount; i++) {
            uniqueTokens[i] = tokens[i];
        }
        
        return uniqueTokens;
    }

    /**
     * @notice Gets all splits for a specific token
     * @param token The token to get splits for
     * @return Array of split configurations for the token
     */
    function getSplitsForToken(IERC20 token) internal view returns (SplitConfig[] memory) {
        uint256 count = 0;
        
        // Count splits for this token
        for (uint256 i = 0; i < config.splits.length; i++) {
            if (config.splits[i].token == token) {
                count++;
            }
        }
        
        // Create array and populate
        SplitConfig[] memory tokenSplits = new SplitConfig[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < config.splits.length; i++) {
            if (config.splits[i].token == token) {
                tokenSplits[index] = config.splits[i];
                index++;
            }
        }
        
        return tokenSplits;
    }

    receive() external payable {}
} 
