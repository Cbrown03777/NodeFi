// scripts/deploy.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer, , treasury, burnAddr, relayer] = await ethers.getSigners();

  const underlyingAddr = "REPLACE_UNDERLYING";
  const nodeTokenAddr  = "REPLACE_NODE";
  const uniTokenAddr   = "REPLACE_UNI";
  const bridgeTokenAddr= "REPLACE_BRIDGE";

  const CommissionManager = await ethers.getContractFactory("NodeFiCommissionManager");
  const commissionMgr = await upgrades.deployProxy(CommissionManager, [1000, treasury.address], { initializer: 'initialize' });
  console.log("CommissionManager:", commissionMgr.address);

  const CoreVault = await ethers.getContractFactory("NodeFiCoreVault");
  const coreVault = await upgrades.deployProxy(CoreVault, [underlyingAddr], { initializer: 'initialize' });
  console.log("CoreVault:", coreVault.address);

  const VeToken = await ethers.getContractFactory("NodeFiVeToken");
  const veToken = await upgrades.deployProxy(VeToken, [nodeTokenAddr], { initializer: 'initialize' });
  console.log("veNODE:", veToken.address);

  const VeUNI = await ethers.getContractFactory("NodeFiVeUNI");
  const veUni = await upgrades.deployProxy(VeUNI, [uniTokenAddr], { initializer: 'initialize' });
  console.log("veUNI:", veUni.address);

  const RewardsDistributor = await ethers.getContractFactory("NodeFiRewardsDistributor");
  const rewardsDist = await upgrades.deployProxy(
    RewardsDistributor,
    [
      coreVault.address,
      nodeTokenAddr,
      uniTokenAddr,
      veToken.address,
      veUni.address,
      5000,
      ethers.utils.parseEther("10000"),
      commissionMgr.address,
      3000,
      ethers.utils.parseEther("8000")
    ],
    { initializer: 'initialize' }
  );
  console.log("RewardsDistributor:", rewardsDist.address);

  const BridgeAdapter = await ethers.getContractFactory("NodeFiBridgeAdapter");
  const bridgeAdapter = await upgrades.deployProxy(
    BridgeAdapter,
    [bridgeTokenAddr, rewardsDist.address, relayer.address],
    { initializer: 'initialize' }
  );
  console.log("BridgeAdapter:", bridgeAdapter.address);

  await coreVault.connect(deployer).setRewardsDistributor(rewardsDist.address);
  console.log("Setup complete");
}

main().catch(console.error);
