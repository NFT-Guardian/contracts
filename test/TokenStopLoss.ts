import { ethers } from "hardhat";
import { MockV3Aggregator, TokenStopLoss } from "../typechain-types";
import { expect } from "chai";

const VERIFIER_NAME = "Token Stop Loss Contract";
const VERIFIER_VERSION = "1";

describe("Token Stop Loss", function () {
  let mockV3Aggregator: MockV3Aggregator;
  let tokenStopLoss: TokenStopLoss;

  this.beforeAll(async () => {
    const MockV3AggregatorFactory = await ethers.getContractFactory(
      "MockV3Aggregator"
    );
    mockV3Aggregator = await MockV3AggregatorFactory.deploy(
      8,
      ethers.utils.parseUnits("1885.22", 8)
    );

    const TokenStopLossFactory = await ethers.getContractFactory(
      "TokenStopLoss"
    );
    // tokenStopLoss = await TokenStopLossFactory.deploy(
    //   VERIFIER_NAME,
    //   VERIFIER_VERSION,
    //   mockV3Aggregator.address,

    // );
  });

  it("Should fetch the correct amount from the mock v3 aggregator", async () => {
    const data = await mockV3Aggregator.latestRoundData();
    expect(data.answer).to.be.equal(ethers.utils.parseUnits("1885.22", 8));
  });
});
