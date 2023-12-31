// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./interfaces/UniswapV3Interfaces.sol";
import "./interfaces/TokenStopLossInterface.sol";

/// @title Token Stop Loss
/// @author Yash Goyal
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
/// @custom:security-contact contact@yashgoyal.dev
contract TokenStopLossV2 is TokenStopLossInterface, Ownable, EIP712 {
    using Math for uint256;

    // Instance of the Chainlink price feed contract
    AggregatorV3Interface internal priceFeed;
    IUniswapV3Router public uniswapV3Router;
    uint24 public feeTier = 3000;
    IUniswapV3Factory public uniswapV3Factory;

    address stableCoin;

    constructor(
        string memory _name,
        string memory _version,
        address _eth_usd_feed,
        address _uniswapV3Router,
        address _uniswapV3Factory,
        address _stableCoin
    ) EIP712(_name, _version) {
        priceFeed = AggregatorV3Interface(_eth_usd_feed);
        uniswapV3Router = IUniswapV3Router(_uniswapV3Router);
        uniswapV3Factory = IUniswapV3Factory(_uniswapV3Factory);
        stableCoin = _stableCoin;
    }

    function setUniswapRouter(address _uniswapV3Router) external onlyOwner {
        uniswapV3Router = IUniswapV3Router(_uniswapV3Router);
    }

    function sellTokens(
        address[] calldata tokenContracts,
        uint256[] memory tokenAmounts
    ) public {
        // sell tokens
        _sellToken(msg.sender, tokenContracts, tokenAmounts);
    }

    function sellTokens(
        address owner,
        address[] calldata tokenContracts,
        uint256[] memory tokenAmounts,
        int stopLoss,
        bytes memory userSignature
    ) public {
        // check the signature
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(
                        "SellToken(address owner,address[] tokenContracts,uint256[] tokenAmounts,int stopLoss)"
                    ),
                    msg.sender,
                    tokenContracts,
                    tokenAmounts,
                    stopLoss
                )
            )
        );

        address signer = ECDSA.recover(digest, userSignature);

        if (signer != msg.sender) revert InvalidSignature();

        // check if stop loss is hit using the chainlink price feed
        if (_getLatestETHPrice() < stopLoss) revert StopLossNotHit();

        // sell token
        _sellToken(owner, tokenContracts, tokenAmounts);
    }

    function _sellToken(
        address owner,
        address[] calldata tokenContracts,
        uint256[] memory tokenAmounts
    ) internal {
        require(
            tokenContracts.length == tokenAmounts.length,
            "Mismatched tokens and amounts array length"
        );

        // check if the contract is approved for all the tokens
        for (uint256 i = 0; i < tokenContracts.length; i++) {
            IERC20 tokenContract = IERC20(tokenContracts[i]);
            uint256 balance = tokenContract.balanceOf(owner);
            uint256 allowance = tokenContract.allowance(owner, msg.sender);

            if (balance < tokenAmounts[i]) {
                tokenAmounts[i] = balance;
            }

            if (allowance < tokenAmounts[i]) {
                tokenAmounts[i] = allowance;
            }
        }

        // sell the token against stablecoin
        for (uint i = 0; i < tokenContracts.length; i++) {
            address token = tokenContracts[i];
            uint256 amountToSell = tokenAmounts[i];
            uint256 minAmountOut = getExpectedOutputWithSlippage(
                token,
                amountToSell
            );

            require(
                IERC20(token).transferFrom(
                    msg.sender,
                    address(this),
                    amountToSell
                ),
                "Token transfer failed"
            );
            require(
                IERC20(token).approve(address(uniswapV3Router), amountToSell),
                "Approval failed"
            );

            uniswapV3Router.exactInputSingle({
                tokenIn: token,
                tokenOut: stableCoin,
                fee: feeTier, // For example, 3000 for 0.3% fee tier
                recipient: address(this),
                deadline: block.timestamp + 1 hours, // Assuming a deadline of 1 hour
                amountIn: amountToSell,
                amountOutMinimum: minAmountOut,
                sqrtPriceLimitX96: 0 // No specific limit. Adjust if necessary.
            });
        }

        // future: deduct a small fees from this trade
    }

    /**
     * Returns the latest ETH/USD price
     */
    function _getLatestETHPrice() internal view returns (int) {
        (, int price, , , ) = priceFeed.latestRoundData();
        return price;
    }

    function getExpectedOutputWithSlippage(
        address tokenIn,
        uint256 amountIn
    ) public view returns (uint256) {
        address poolAddress = uniswapV3Factory.getPool(
            tokenIn,
            stableCoin,
            feeTier
        );
        require(poolAddress != address(0), "Pair doesn't exist");

        (uint160 sqrtPriceX96, , , , , ) = IUniswapV3Pool(poolAddress).slot0();

        // Price formula: (sqrtPriceX96^2)/2^192
        // where sqrtPriceX96 is the price of tokenA in terms of tokenB
        uint256 price = amountIn *
            ((uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) >> 192);
        return (price * 95) / 100;
    }

    // function getExpectedOutputWithSlippage(
    //     address tokenIn,
    //     uint256 amountIn
    // ) public view returns (uint256) {
    //     address pair = uniswapV2Factory.getPair(tokenIn, stableCoin);
    //     require(pair != address(0), "Pair doesn't exist");

    //     (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair)
    //         .getReserves();

    //     uint256 tokenInReserve = tokenIn < stableCoin ? reserve0 : reserve1;
    //     uint256 stableCoinReserve = tokenIn < stableCoin ? reserve1 : reserve0;

    //     uint256 expectedOutput = (amountIn * stableCoinReserve) /
    //         tokenInReserve;
    //     return (expectedOutput * 95) / 100; // Deducting 5% slippage
    // }
}
