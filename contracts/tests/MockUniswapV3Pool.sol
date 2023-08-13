// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockUniswapV3Pool {
    int24 public mockPrice;

    function setMockPrice(int24 _mockPrice) external {
        mockPrice = _mockPrice;
    }

    function slot0()
        external
        view
        returns (
            int24 price,
            uint16,
            uint8,
            uint16,
            uint16,
            uint16,
            uint16,
            uint128
        )
    {
        return (mockPrice, 0, 0, 0, 0, 0, 0, 0);
    }
}
