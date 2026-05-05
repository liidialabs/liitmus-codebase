// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "../../../interfaces/IERC20.sol";
import {IPool} from "../interface/IPool.sol";
import {IPoolDataProvider} from "../interface/IPoolDataProvider.sol";
import {IAToken} from "../interface/IAToken.sol";
import {IPoolAddressesProvider} from "../interface/IPoolAddressesProvider.sol";

// Base contract for Aave V3 interactions
// All usage contracts inherit from this to access common functionality
abstract contract AaveV3Base {
    IPool public immutable pool;
    IPoolDataProvider public immutable dataProvider;
    IPoolAddressesProvider public immutable provider;

    // Interest rate modes
    uint256 internal constant STABLE_RATE = 1;
    uint256 internal constant VARIABLE_RATE = 2;

    constructor(address _provider) {
        provider = IPoolAddressesProvider(_provider);
        pool = IPool(_provider);
        dataProvider = IPoolDataProvider(provider.getPoolDataProvider());
    }

    // Internal helper to get aToken for an asset
    function _getAToken(address asset) internal view returns (IAToken) {
        return IAToken(pool.getReserveData(asset).aTokenAddress);
    }

    // Internal helper to get variable debt token for an asset
    function _getVariableDebtToken(address asset) internal view returns (IERC20) {
        return IERC20(pool.getReserveData(asset).variableDebtTokenAddress);
    }

    // Internal helper to get stable debt token for an asset
    function _getStableDebtToken(address asset) internal view returns (IERC20) {
        return IERC20(pool.getReserveData(asset).stableDebtTokenAddress);
    }
}
