const { ethers } = require("hardhat");

async function main() {
  const governor = await ethers.getContract("NodeFiGovernor");
  const timelock = await ethers.getContract("NodeFiTimelockController");
  const core = await ethers.getContract("NodeFiCoreVault");
  // Example: change slippage to 50bps
  const calldata = core.interface.encodeFunctionData("setInitialSlippageBps", [50]);
  const tx = await governor.propose(
    [core.address],
    [0],
    [calldata],
    "Proposal: set slippage to 0.5%"
  );
  console.log("Proposal created:", tx.hash);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
""",
    # Scripts: vote.js
    os.path.join(scripts_dir, "vote.js"): """const { ethers } = require("hardhat");

async function main() {
  const governor = await ethers.getContract("NodeFiGovernor");
  const proposalId = process.argv[2]; // pass ID as arg
  const vote = 1; // 0=against,1=for,2=abstain
  const tx = await governor.castVote(proposalId, vote);
  console.log("Vote cast:", tx.hash);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});