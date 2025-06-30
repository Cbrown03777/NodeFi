const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Governance: NodeFiGovernor & Timelock", function () {
  let token, timelock, governor, owner, addr1;
  const MIN_DELAY = 3600; // 1 hour

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();

    // Deploy ERC20Votes token (NodeFiToken)
    const Token = await ethers.getContractFactory("NodeFiToken");
    token = await Token.deploy("NodeFi", "NODE", ethers.utils.parseEther("1000000"));
    await token.deployed();
    // Mint & delegate to owner
    await token.mint(owner.address, ethers.utils.parseEther("10000"));
    await token.delegate(owner.address);

    // Deploy Timelock
    const Timelock = await ethers.getContractFactory("NodeFiTimelockController");
    timelock = await Timelock.deploy(MIN_DELAY, [owner.address], [owner.address]);
    await timelock.deployed();

    // Deploy Governor
    const Governor = await ethers.getContractFactory("NodeFiGovernor");
    governor = await Governor.deploy(token.address, timelock.address);
    await governor.deployed();

    // Transfer ownership of token & other modules to timelock if needed
    await token.transferOwnership(timelock.address);
    });
  });

  it("should allow proposal, voting, and execution", async function () {
    // Prepare a proposal to change delay of timelock (as an example)
    const iface = timelock.interface;
    const data = iface.encodeFunctionData("updateDelay", [7200]);
    const proposalTx = await governor.propose(
      [timelock.address],
      [0],
      [data],
      "Proposal #1: increase delay to 2 hours"
    );
    const receipt = await proposalTx.wait();
    const proposalId = receipt.events[0].args.proposalId;

    // Move blocks and time forward
    await ethers.provider.send("evm_mine", []); // votingDelay
    // Vote
    await governor.castVote(proposalId, 1); // for
    // Move forward votingPeriod
    for (let i = 0; i < (await governor.votingPeriod()); i++) {
      await ethers.provider.send("evm_mine", []);
    }
    // Queue
    await governor.queue(
      [timelock.address],
      [0],
      [data],
      ethers.utils.id("Proposal #1: increase delay to 2 hours")
    );
    // Increase time
    await ethers.provider.send("evm_increaseTime", [MIN_DELAY]);
    await ethers.provider.send("evm_mine", []);
    // Execute
    await governor.execute(
      [timelock.address],
      [0],
      [data],
      ethers.utils.id("Proposal #1: increase delay to 2 hours")
    );
    expect(await timelock.getMinDelay()).to.equal(7200);
  });