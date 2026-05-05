// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "../../../interfaces/IERC20.sol";
import {AaveV3Base} from "./AaveV3Base.sol";
import {IAToken} from "../interface/IAToken.sol";

/**
 * @title Supply
 * @notice Demonstrates how to supply assets to Aave V3
 * @dev Supply assets to earn interest. The user receives aTokens which represent their deposit.
 */
contract Supply is AaveV3Base {
    constructor(address _provider) AaveV3Base(_provider) {}

    /**
     * @notice Supply an asset to Aave V3 on behalf of the contract
     * @param asset Address of the token to supply
     * @param amount Amount of tokens to supply (in token decimals)
     *
     * @dev Requirements:
     * - msg.sender must have approved this contract for at least `amount`
     * - Asset must be listed on Aave V3
     * - Asset must be active (not frozen)
     */
    function supply(address asset, uint256 amount) external {
        _supply(asset, amount, address(this));
    }

    /**
     * @notice Supply an asset to Aave V3 on behalf of another address
     * @param asset Address of the token to supply
     * @param amount Amount of tokens to supply (in token decimals)
     * @param onBehalfOf Address that will receive the aTokens
     *
     * @dev Requirements:
     * - msg.sender must have approved this contract for at least `amount`
     * - onBehalfOf must have approved this contract to supply on their behalf (if different)
     */
    function supplyOnBehalfOf(address asset, uint256 amount, address onBehalfOf) external {
        _supply(asset, amount, onBehalfOf);
    }

    function _supply(address asset, uint256 amount, address onBehalfOf) internal {
        // Transfer tokens from user to this contract
        IERC20(asset).transferFrom(msg.sender, address(this), amount);

        // Approve Aave Pool to spend tokens
        IERC20(asset).approve(address(pool), amount);

        // Supply to Aave V3
        pool.supply({
            asset: asset,
            amount: amount,
            onBehalfOf: onBehalfOf,
            referralCode: 0
        });
    }

    /**
     * @notice Get the supply balance of this contract for a given asset
     * @param asset Address of the supplied asset
     * @return Balance in aTokens (growing due to accrued interest)
     */
    function getSupplyBalance(address asset) external view returns (uint256) {
        IAToken aToken = _getAToken(asset);
        return aToken.balanceOf(address(this));
    }

    /**
     * @notice Get the scaled supply balance (principal without interest accrued)
     * @param asset Address of the supplied asset
     * @return Scaled balance
     */
    function getScaledSupplyBalance(address asset) external view returns (uint256) {
        IAToken aToken = _getAToken(asset);
        return aToken.scaledBalanceOf(address(this));
    }

    /**
     * @notice Toggle whether a supplied asset is used as collateral
     * @param asset Address of the asset
     * @param useAsCollateral True to enable, false to disable
     *
     * @dev Required before borrowing. Assets must be collateral to borrow against them.
     */
    function setUseAsCollateral(address asset, bool useAsCollateral) external {
        pool.setUserUseReserveAsCollateral(asset, useAsCollateral);
    }

    /**
     * @notice Check if this contract has any supply in an asset
     * @param asset Address of the asset
     * @return True if there is any supply balance
     */
    function hasSupply(address asset) external view returns (bool) {
        return _getAToken(asset).balanceOf(address(this)) > 0;
    }
}
