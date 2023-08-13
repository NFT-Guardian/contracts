// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockUniswapV3Factory {
    mapping(address => mapping(address => mapping(uint24 => address)))
        public getPool;

    function setMockPool(
        address tokenA,
        address tokenB,
        uint24 fees,
        address _mockPool
    ) external {
        getPool[tokenA][tokenB][fees] = _mockPool;
    }
}
