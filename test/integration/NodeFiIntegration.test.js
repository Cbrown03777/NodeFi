const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("NodeFi End-to-End Integration + Tokenomics", function () {
  let owner, user1, user2, treasury, burnAddr, relayer;
  let underlying, mockNode, uniToken, bridgeToken;
  let commissionMgr, coreVault, veToken, veUni, rewardsDist, bridgeAdapter;

  beforeEach(async function () {
    [owner, user1, user2, treasury, burnAddr, relayer] = await ethers.getSigners();

    // 1) Deploy mocks
    const MockToken = await ethers.getContractFactory("contracts/MockERC20.sol:MockERC20");
    underlying = await MockToken.deploy("Underlying", "UND", 18, ethers.parseEther("1000000"));
    await underlying.waitForDeployment();
    mockNode = await MockToken.deploy("Node", "NODE", 18, ethers.parseEther("1000000"));
    await mockNode.waitForDeployment();
    uniToken = await MockToken.deploy("Uniswap", "UNI", 18, ethers.parseEther("1000000"));
    await uniToken.waitForDeployment();
    bridgeToken = await MockToken.deploy("Bridge", "BRG", 18, ethers.parseEther("1000000"));
    await bridgeToken.waitForDeployment();

    // Distribute
    await underlying.transfer(user1.address, ethers.parseEther("10000"));
    await underlying.transfer(user2.address, ethers.parseEther("10000"));
    await mockNode.transfer(owner.address, ethers.parseEther("100000"));
    await uniToken.transfer(owner.address, ethers.parseEther("100000"));
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
  });

  it("A–G: stake, ve locks, bridge, forward, claim + commission", async function () {
    // A: user1 stakes 1000 UND
    await coreVault.connect(user1).stake(ethers.parseEther("1000"));
    expect(await coreVault.balanceOf(user1.address)).to.equal(ethers.parseEther("1000"));

    // B: owner locks
    const unlockNode = Math.floor(Date.now()/1000) + 365*24*3600;
    await veToken.connect(owner).createLock(ethers.parseEther("50000"), unlockNode);
    const unlockUni  = Math.floor(Date.now()/1000) + 180*24*3600;
    await veUni.connect(owner).createLock(ethers.parseEther("30000"), unlockUni);

    // C+D: deposit & forward
    await bridgeToken.connect(relayer).approve(bridgeAdapter.target, ethers.parseEther("1000"));
    await bridgeAdapter.connect(relayer).depositYield(ethers.parseEther("1000"));
    await bridgeAdapter.connect(owner).forwardYield(
      [user1.address],
      [ethers.parseEther("200")],
      [ethers.parseEther("100")]
    );

    // seed distributor balances
    await mockNode.connect(owner).transfer(rewardsDist.target, ethers.parseEther("500"));
    await uniToken.connect(owner).transfer(rewardsDist.target, ethers.parseEther("500"));

    // E: user1 claims
    const prevNode = await mockNode.balanceOf(user1.address);
    const prevUni  = await uniToken.balanceOf(user1.address);
    await rewardsDist.connect(user1).claim();
    const newNode = await mockNode.balanceOf(user1.address);
    const newUni  = await uniToken.balanceOf(user1.address);

    const nodeGain = newNode - prevNode;
    const uniGain  = newUni  - prevUni;
    expect(nodeGain).to.be.gte(ethers.parseEther("180"));
    expect(uniGain ).to.be.gte(ethers.parseEther("100"));

    // F: commission ≈10% of 200 = 20 NODE
    const treas = await mockNode.balanceOf(treasury.address);
    expect(treas).to.be.closeTo(ethers.parseEther("20"), ethers.parseEther("1"));

    // G: veNODE supply epoch advanced
    expect(await veToken.supplyEpoch()).to.be.gt(0);
  });

  it("H) Share-based minting & dust handling", async function () {
    const tu0   = await coreVault.totalUnderlying();
    const ts0   = await coreVault.totalSupply();
    const dust0 = await coreVault.shareDust();

    // user2 stakes 500 UND
    await coreVault.connect(user2).stake(ethers.parseEther("500"));

    const tu1   = await coreVault.totalUnderlying();
    const ts1   = await coreVault.totalSupply();
    const dust1 = await coreVault.shareDust();

    const expected = ts0 === 0n
      ? ethers.parseEther("500")
      : (ts0 * ethers.parseEther("500")) / tu0;
    const minted  = ts1 - ts0;
    const diff    = minted > expected ? minted - expected : expected - minted;

    expect(diff).to.be.lte(1n);
    expect(dust1).to.be.lt(ethers.parseEther("1"));
  });

  it("I) veUNI boost multiplier (reward > base)", async function () {
    // create UNI rewards
    await bridgeToken.connect(relayer).approve(bridgeAdapter.target, ethers.parseEther("100"));
    await bridgeAdapter.connect(relayer).depositYield(ethers.parseEther("100"));
    await bridgeAdapter.connect(owner).forwardYield(
      [owner.address],
      [0],
      [ethers.parseEther("100")]
    );
    await uniToken.connect(owner).transfer(rewardsDist.target, ethers.parseEther("2000"));

    const baseUNI = ethers.parseEther("100");
    const prevUNI = await uniToken.balanceOf(owner.address);
    await rewardsDist.connect(owner).claim();
    const newUNI  = await uniToken.balanceOf(owner.address);
    const pulled  = newUNI - prevUNI;

    expect(pulled).to.be.gte(baseUNI);
  });

  it("J) Deflationary burn & commission & buyback", async function () {
    // deploy and mint into user1 instead
   const Token     = await ethers.getContractFactory("NodeFiToken");
    const nodeToken = await Token.deploy(owner.address, treasury.address, 50, 50);
    await nodeToken.waitForDeployment();

    // seed user1 so they can trigger the fee logic
    await nodeToken.mint(user1.address, ethers.parseEther("1000"));
    const prev2      = await nodeToken.balanceOf(user2.address);
    const prevTreas  = await nodeToken.balanceOf(treasury.address);
    const prevSupply = await nodeToken.totalSupply();

    // now user1 → user2 will incur burn+buyback
    await nodeToken.connect(user1).transfer(user2.address, ethers.parseEther("100"));

    const after2      = await nodeToken.balanceOf(user2.address);
    const afterTreas  = await nodeToken.balanceOf(treasury.address);
    const afterSupply = await nodeToken.totalSupply();

    const gotUser2 = after2      - prev2;
    const gotBuy   = afterTreas  - prevTreas;
    const burnt    = prevSupply  - afterSupply;

    expect(gotUser2).to.equal(ethers.parseEther("99"));
    expect(gotBuy  ).to.equal(ethers.parseEther("0.5"));
    expect(burnt   ).to.equal(ethers.parseEther("0.5"));
 });

  it("K) NODE totalSupply within [622M,690M]", async function () {
    const Token = await ethers.getContractFactory("NodeFiToken");
    const realNode = await Token.deploy(owner.address, treasury.address, 50, 50);
    await realNode.waitForDeployment();

    const supply = await realNode.totalSupply();
    const MIN    = 622_000_000n * 10n**18n;
    const MAX    = 690_000_000n * 10n**18n;

    expect(supply).to.be.gte(MIN);
    expect(supply).to.be.lte(MAX);
  });
});
