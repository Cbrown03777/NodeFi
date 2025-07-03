const { ethers } = require("hardhat");

async function main() {
  const governor = await ethers.getContract("NodeFiGovernor");
  const timelock = await ethers.getContract("NodeFiTimelockController");
  const proposalId = process.argv[2]; // pass ID
  const descriptionHash = ethers.utils.id(process.argv[3]); // pass description
  // Retrieve proposal details from governor...
  // For simplicity assume single target/action
  const proposal = await governor.proposals(proposalId);
  const tx = await governor.execute(
    proposal.targets,
    proposal.values,
    proposal.calldatas,
    descriptionHash
  );
  console.log("Proposal executed:", tx.hash);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});