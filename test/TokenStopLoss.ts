import { ethers } from "hardhat";
import {
  MockERC20,
  MockUniswapV3Factory,
  MockV3Aggregator,
  TokenStopLossV2,
} from "../typechain-types";
import { expect } from "chai";

const VERIFIER_NAME = "Token Stop Loss Contract";
const VERIFIER_VERSION = "1";

describe("Token Stop Loss", function () {
  let mockV3Aggregator: MockV3Aggregator;
  let tokenStopLoss: TokenStopLossV2;
  let mockUniswapV3Factory: MockUniswapV3Factory;
  let stableCoin: MockERC20;
  const supportedTokens: MockERC20[] = [];

  this.beforeAll(async () => {
    const MockV3AggregatorFactory = await ethers.getContractFactory(
      "MockV3Aggregator"
    );
    mockV3Aggregator = await MockV3AggregatorFactory.deploy(
      8,
      ethers.utils.parseUnits("1885.22", 8)
    );
    await mockV3Aggregator.deployed();

    const StableCoinFactory = await ethers.getContractFactory("MockERC20");
    stableCoin = await StableCoinFactory.deploy("USDC", "USDC");
    await stableCoin.deployed();

    const MockUniswapV3FactoryFactory = await ethers.getContractFactory(
      "MockUniswapV3Factory"
    );
    mockUniswapV3Factory = await MockUniswapV3FactoryFactory.deploy();
    await mockUniswapV3Factory.deployed();

    const TokenStopLossFactory = await ethers.getContractFactory(
      "TokenStopLossV2"
    );
    tokenStopLoss = await TokenStopLossFactory.deploy(
      VERIFIER_NAME,
      VERIFIER_VERSION,
      mockV3Aggregator.address,
      mockUniswapV3Factory.address,
      mockUniswapV3Factory.address,
      stableCoin.address
    );
    await tokenStopLoss.deployed();
  });

  it("Should fetch the correct amount from the mock v3 aggregator", async () => {
    const data = await mockV3Aggregator.latestRoundData();
    expect(data.answer).to.be.equal(ethers.utils.parseUnits("1885.22", 8));
  });

  it("Should deploy some new tokens", async () => {
    const MockERC20Factory = await ethers.getContractFactory("MockERC20");
    for (let i = 0; i < 10; i++) {
      supportedTokens.push(
        await MockERC20Factory.deploy(`Supported Token ${i}`, `SPT${i}`)
      );
      await supportedTokens[i].deployed();
    }
  });

  it("Should add mock pools for all the tokens", async () => {
    const MockUniswapV3PoolFactory = await ethers.getContractFactory(
      "MockUniswapV3Pool"
    );

    for (const supportedToken of supportedTokens) {
      const pool = await MockUniswapV3PoolFactory.deploy();
      await mockUniswapV3Factory.setMockPool(
        supportedToken.address,
        stableCoin.address,
        3000,
        pool.address
      );

      console.log((Math.random() * 1000).toPrecision(5));

      await pool.setMockPrice(
        ethers.utils.parseEther((Math.random() * 1000).toPrecision(5))
      );
    }
  });

  it("Should fetch the correct price of the token", async () => {});
});
