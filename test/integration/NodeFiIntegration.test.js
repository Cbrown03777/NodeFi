const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("NodeFi End-to-End Integration + Tokenomics", function () {
  let owner, user1, user2, treasury, burnAddr, relayer;
  let underlying, mockNode, uniToken, bridgeToken;
  let commissionMgr, coreVault, veToken, veUni, rewardsDist, bridgeAdapter;
  let timelock, governor, minDelay, proposers, executors;

  beforeEach(async function () {
    [owner, user1, user2, treasury, burnAddr, relayer] = await ethers.getSigners();

    // 1) Deploy mocks
    const MockToken = await ethers.getContractFactory("contracts/MockERC20.sol:MockERC20");
    underlying  = await MockToken.deploy("Underlying", "UND", 18, ethers.parseEther("1000000"));
    await underlying.waitForDeployment();
    mockNode    = await MockToken.deploy("Node",       "NODE",18, ethers.parseEther("1000000"));
    await mockNode.waitForDeployment();
    uniToken    = await MockToken.deploy("Uniswap",    "UNI", 18, ethers.parseEther("1000000"));
    await uniToken.waitForDeployment();
    bridgeToken = await MockToken.deploy("Bridge",     "BRG", 18, ethers.parseEther("1000000"));
    await bridgeToken.waitForDeployment();

    // Distribute
    await underlying.transfer(user1.address, ethers.parseEther("10000"));
    await underlying.transfer(user2.address, ethers.parseEther("10000"));
    await mockNode.transfer(owner.address,    ethers.parseEther("100000"));
    await uniToken.transfer(owner.address,    ethers.parseEther("100000"));
    await bridgeToken.transfer(relayer.address, ethers.parseEther("50000"));

    // 2) CommissionManager
    const CommissionManager = await ethers.getContractFactory("NodeFiCommissionManager");
    commissionMgr = await upgrades.deployProxy(
      CommissionManager,
      [1000, treasury.address],
      { initializer: "initialize" }
    );
    await commissionMgr.waitForDeployment();

    // 3) CoreVault
    const CoreVault = await ethers.getContractFactory("NodeFiCoreVault");
    coreVault = await upgrades.deployProxy(
      CoreVault,
      [underlying.target],
      { initializer: "initialize" }
    );
    await coreVault.waitForDeployment();

    // 4) veToken & veUNI
    const VeToken = await ethers.getContractFactory("NodeFiVeToken");
    veToken = await upgrades.deployProxy(VeToken, [mockNode.target], { initializer: "initialize" });
    await veToken.waitForDeployment();

    const VeUNI = await ethers.getContractFactory("NodeFiVeUNI");
    veUni  = await upgrades.deployProxy(VeUNI, [uniToken.target], { initializer: "initialize" });
    await veUni.waitForDeployment();

    // 5) RewardsDistributor
    const RewardsDistributor = await ethers.getContractFactory("NodeFiRewardsDistributor");
    rewardsDist = await upgrades.deployProxy(
      RewardsDistributor,
      [
        coreVault.target,
        mockNode.target,
        uniToken.target,
        veToken.target,
        veUni.target,
        5000,                       // 50% max NODE boost
        ethers.parseEther("10000"), // max veNODE supply
        commissionMgr.target,
        3000,                       // 30% max UNI boost
        ethers.parseEther("8000")   // max veUNI supply
      ],
      { initializer: "initialize" }
    );
    await rewardsDist.waitForDeployment();

    // 6) BridgeAdapter
    const BridgeAdapter = await ethers.getContractFactory("NodeFiBridgeAdapter");
    bridgeAdapter = await upgrades.deployProxy(
      BridgeAdapter,
      [bridgeToken.target, rewardsDist.target, relayer.address],
      { initializer: "initialize" }
    );
    await bridgeAdapter.waitForDeployment();

    // 7) Link vault → distributor
    await coreVault.connect(owner).setRewardsDistributor(rewardsDist.target);

    // 8) Approvals
    await underlying.connect(user1).approve(coreVault.target, ethers.parseEther("10000"));
    await underlying.connect(user2).approve(coreVault.target, ethers.parseEther("10000"));
    await mockNode.connect(owner).approve(veToken.target, ethers.parseEther("100000"));
    await uniToken.connect(owner).approve(veUni.target, ethers.parseEther("100000"));

    // --- governance/timelock setup ---
    minDelay  = 3600;                      // e.g. 1 hour
    proposers = [owner.address];
    executors = [ethers.constants.AddressZero];

    // Deploy a TimelockController
    const Timelock = await ethers.getContractFactory("TimelockController");
    timelock = await Timelock.deploy(minDelay, proposers, executors);
    await timelock.waitForDeployment();

    // Deploy our on-chain Governor
    const Governor = await ethers.getContractFactory("NodeFiGovernor");
    // constructor args: token (mockNode) & timelock
    governor = await Governor.deploy(mockNode.target, timelock.target);
    await governor.waitForDeployment();

    // Grant the Governor the proposer role on the Timelock
    const PROPOSER_ROLE = await timelock.PROPOSER_ROLE();
    await timelock.grantRole(PROPOSER_ROLE, governor.target);
  });

  it("A–G: stake, ve locks, bridge, forward, claim + commission", async function () {
    // … unchanged …
  });

  it("H) Share-based minting & dust handling", async function () {
    // … unchanged …
  });

  it("I) veUNI boost multiplier (reward > base)", async function () {
    // … unchanged …
  });

  it("J) Deflationary burn & commission & buyback", async function () {
    // … unchanged …
  });

  it("K) NODE totalSupply within [622M,690M]", async function () {
    // … unchanged …
  });
});
