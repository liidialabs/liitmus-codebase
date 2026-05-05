// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "../../../interfaces/IERC20.sol";
import {AaveV3Base} from "./AaveV3Base.sol";
import {IAToken} from "../interface/IAToken.sol";

/**
 * @title Withdraw
 * @notice Demonstrates how to withdraw supplied assets from Aave V3
 * @dev Withdraw previously supplied assets plus accrued interest.
 */
contract Withdraw is AaveV3Base {
    constructor(address _provider) AaveV3Base(_provider) {}

    /**
     * @notice Withdraw an asset from Aave V3 to this contract
     * @param asset Address of the asset to withdraw
     * @param amount Amount to withdraw (in token decimals), or type(uint256).max for max
     * @return withdrawn Amount actually withdrawn
     *
     * @dev Requirements:
     * - This contract must have supplied the asset
     * - If withdrawing all, health factor must remain valid (can't withdraw all collateral if there's debt)
     * - Setting amount to type(uint256).max withdraws maximum available
     */
    function withdraw(address asset, uint256 amount) external returns (uint256 withdrawn) {
        return _withdraw(asset, amount, address(this));
    }

    /**
     * @notice Withdraw an asset from Aave V3 to a specific address
     * @param asset Address of the asset to withdraw
     * @param amount Amount to withdraw (in token decimals)
     * @param to Address to receive the withdrawn tokens
     * @return withdrawn Amount actually withdrawn
     */
    function withdrawTo(address asset, uint256 amount, address to) external returns (uint256 withdrawn) {
        return _withdraw(asset, amount, to);
    }

    function _withdraw(address asset, uint256 amount, address to) internal returns (uint256) {
        uint256 withdrawn = pool.withdraw({
            asset: asset,
            amount: amount,
            to: to
        });
        return withdrawn;
    }

    /**
     * @notice Calculate the maximum amount that can be withdrawn
     * @param asset Address of the asset
     * @return Maximum withdrawable amount
     *
     * @dev Returns the aToken balance, but actual withdrawal may be limited by health factor
     */
    function getMaxWithdraw(address asset) external view returns (uint256) {
        return _getAToken(asset).balanceOf(address(this));
    }

    /**
     * @notice Get the current supply balance for an asset
     * @param asset Address of the asset
     * @return Current aToken balance
     */
    function getSupplyBalance(address asset) external view returns (uint256) {
        return _getAToken(asset).balanceOf(address(this));
    }
}
