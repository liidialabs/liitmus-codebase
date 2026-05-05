// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Aave V3 Price Oracle interface
// https://github.com/aave/aave-v3-core/blob/master/contracts/misc/PriceOracle.sol

interface IPriceOracle {
    // Returns USD price of asset (1 USD = 1e8)
    function getAssetPrice(address asset) external view returns (uint256);

    // Returns the source address for a given asset's price
    function getSourceOfAsset(address asset) external view returns (address);

    // Returns the fallback oracle address
    function fallbackOracle() external view returns (address);
}
