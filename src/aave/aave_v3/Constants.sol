// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Aave V3 Contract Addresses

// Pool Addresses Provider
address constant POOL_ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;

// Pool (same across all chains for v3)
address constant POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

// Pool Data Provider
address constant POOL_DATA_PROVIDER = address(1);

// Price Oracle
address constant ORACLE = 0x54586bE62E3c3580375aE3723C145253060Ca0C2;

// WETH (common across many chains)
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

// Chain-specific addresses
library AaveV3Addresses {
    // Mainnet
    address public constant MAINNET_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public constant MAINNET_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address public constant MAINNET_DATA_PROVIDER = address(1);
    address public constant MAINNET_ORACLE = 0x54586bE62E3c3580375aE3723C145253060Ca0C2;

    // Arbitrum
    address public constant ARBITRUM_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address public constant ARBITRUM_PROVIDER = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
    address public constant ARBITRUM_DATA_PROVIDER = address(1);
    address public constant ARBITRUM_ORACLE = address(1);

    // Optimism
    address public constant OPTIMISM_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address public constant OPTIMISM_PROVIDER = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
    address public constant OPTIMISM_DATA_PROVIDER = address(1);
    address public constant OPTIMISM_ORACLE = address(1);

    // Polygon
    address public constant POLYGON_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address public constant POLYGON_PROVIDER = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
    address public constant POLYGON_DATA_PROVIDER = address(1);
    address public constant POLYGON_ORACLE = address(1);

    // Base
    address public constant BASE_POOL = address(1);
    address public constant BASE_PROVIDER = address(1);
    address public constant BASE_DATA_PROVIDER = address(1);
    address public constant BASE_ORACLE = 0xFD2AB41e083c75085807c4A65C0A14FDD93d55A9;

    // Avalanche
    address public constant AVALANCHE_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address public constant AVALANCHE_PROVIDER = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
    address public constant AVALANCHE_DATA_PROVIDER = address(1);
    address public constant AVALANCHE_ORACLE = address(1);

    // Sepolia (testnet)
    address public constant SEPOLIA_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public constant SEPOLIA_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address public constant SEPOLIA_DATA_PROVIDER = address(1);
    address public constant SEPOLIA_ORACLE = 0x54586bE62E3c3580375aE3723C145253060Ca0C2;

    // Interest rate modes
    uint256 public constant STABLE_RATE = 1;
    uint256 public constant VARIABLE_RATE = 2;
}
