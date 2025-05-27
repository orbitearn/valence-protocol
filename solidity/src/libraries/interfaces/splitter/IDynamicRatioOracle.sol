// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IDynamicRatioOracle
 * @dev Interface for dynamic ratio oracle contracts used by the Splitter library
 */
interface IDynamicRatioOracle {
    /**
     * @dev Get dynamic ratio for specified denoms
     * @param denoms Array of denom strings to get ratios for
     * @param params Additional parameters for the oracle
     * @return DynamicRatioResponse containing ratios for each denom
     */
    function getDynamicRatio(
        string[] calldata denoms,
        string calldata params
    ) external view returns (uint256);
}