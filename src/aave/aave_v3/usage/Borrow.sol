// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata} from "../../../interfaces/IERC20.sol";
import {AaveV3Base} from "./AaveV3Base.sol";
import {IPriceOracle} from "../interface/IPriceOracle.sol";
import {IAToken} from "../interface/IAToken.sol";
import {IPool} from "../interface/IPool.sol";

/**
 * @title Borrow
 * @notice Demonstrates how to borrow assets against collateral in Aave V3
 * @dev Users must first supply collateral and enable it as collateral before borrowing.
 */
contract Borrow is AaveV3Base {
    IPriceOracle public immutable oracle;
    IPool public immutable pool;

    constructor(address _provider, address _pool, address _oracle) AaveV3Base(_provider) {
        oracle = IPriceOracle(_oracle);
        pool = IPool(_pool);
    }

    /**
     * @notice Borrow an asset from Aave V3
     * @param asset Address of the asset to borrow
     * @param amount Amount to borrow (in token decimals)
     *
     * @dev Requirements:
     * - This contract must have sufficient collateral enabled
     * - Health factor must remain above 1 after borrowing
     * - Asset must be borrowable (some assets are supply-only)
     * - Stable rate borrowing has size limits (typically 25% of reserve)
     */
    function borrow(address asset, uint256 amount) external {
        _borrow(asset, amount, VARIABLE_RATE, address(this));
    }

    /**
     * @notice Borrow an asset on behalf of another address
     * @param asset Address of the asset to borrow
     * @param amount Amount to borrow (in token decimals)
     * @param rateMode Interest rate mode (1 = stable, 2 = variable)
     * @param onBehalfOf Address that will owe the debt
     */
    function borrowOnBehalfOf(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external {
        _borrow(asset, amount, rateMode, onBehalfOf);
    }

    function _borrow(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) internal {
        pool.borrow({
            asset: asset,
            amount: amount,
            interestRateMode: rateMode,
            referralCode: 0,
            onBehalfOf: onBehalfOf
        });
    }

    /**
     * @notice Calculate approximate maximum borrowable amount for an asset
     * @param asset Address of the asset to check
     * @return Approximate maximum amount that can be borrowed
     *
     * @dev This is an approximation based on current prices. Actual max borrow may differ.
     */
    function approxMaxBorrow(address asset) external view returns (uint256) {
        uint256 price = oracle.getAssetPrice(asset);
        uint256 decimals = IERC20Metadata(asset).decimals();

        // availableBorrowsBase is in base currency (usually 1e8 = 1 USD)
        (,, uint256 availableToBorrowBase,,,) = pool.getUserAccountData(address(this));

        // Convert from base currency to asset amount
        return availableToBorrowBase * (10 ** decimals) / price;
    }

    /**
     * @notice Get the current health factor of this contract
     * @return Health factor (1e18 = 1.0). Below 1e18 means liquidatable.
     *
     * @dev Health factor = (total collateral * liquidation threshold) / total debt
     * HF < 1: position can be liquidated
     * HF = 1: at liquidation threshold
     * HF > 1: safe position
     */
    function getHealthFactor() external view returns (uint256) {
        (,,,,, uint256 healthFactor) = pool.getUserAccountData(address(this));
        return healthFactor;
    }

    /**
     * @notice Get full account data for this contract
     * @return totalCollateralBase Total collateral value in base currency
     * @return totalDebtBase Total debt value in base currency
     * @return availableBorrowsBase Available borrowing power in base currency
     * @return currentLiquidationThreshold Current weighted liquidation threshold
     * @return ltv Current weighted loan-to-value ratio
     * @return healthFactor Current health factor
     */
    function getAccountData() external view returns (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    ) {
        return pool.getUserAccountData(address(this));
    }

    /**
     * @notice Get the current variable debt for an asset
     * @param asset Address of the borrowed asset
     * @return Current variable debt balance
     */
    function getVariableDebt(address asset) external view returns (uint256) {
        return _getVariableDebtToken(asset).balanceOf(address(this));
    }

    /**
     * @notice Get the current stable debt for an asset
     * @param asset Address of the borrowed asset
     * @return Current stable debt balance
     */
    function getStableDebt(address asset) external view returns (uint256) {
        return _getStableDebtToken(asset).balanceOf(address(this));
    }

    /**
     * @notice Check if this contract has any debt for an asset
     * @param asset Address of the asset
     * @return True if there is any variable debt
     */
    function hasDebt(address asset) external view returns (bool) {
        return getVariableDebt(asset) > 0;
    }

    /**
     * @notice Get the current USD value of an asset
     * @param asset Address of the asset
     * @param amount Amount of the asset (in token decimals)
     * @return Value in base currency (1e8 = 1 USD)
     */
    function getAssetValue(address asset, uint256 amount) external view returns (uint256) {
        uint256 price = oracle.getAssetPrice(asset);
        uint256 decimals = IERC20Metadata(asset).decimals();
        return amount * price / (10 ** decimals);
    }

    /**
     * @notice Swap between stable and variable rate for a borrowed asset
     * @param asset Address of the borrowed asset
     * @param rateMode Current rate mode to swap from (1 = stable, 2 = variable)
     */
    function swapRateMode(address asset, uint256 rateMode) external {
        pool.swapBorrowRateMode(asset, rateMode);
    }

    /**
     * @notice Enable E-Mode for higher LTV on correlated assets
     * @param categoryId E-Mode category ID
     *
     * @dev E-Mode (Efficiency Mode) allows higher LTV when using correlated assets
     * as collateral and borrowing (e.g., all stablecoins). Use with caution.
     */
    function enableEMode(uint8 categoryId) external {
        pool.setUserEMode(categoryId);
    }
}

/// @title ExampleBorrowUsage
/// @notice This contract demonstrates how to use the Borrow contract to borrow assets from Aave V3. 
/// It is meant for testing and educational purposes and should not be used in production as-is.

contract ExampleBorrowUsage {
    IPool public immutable pool;

    constructor( address _pool, address _oracle) {
        oracle = IPriceOracle(_oracle);
        pool = IPool(_pool);
    }

    
}
