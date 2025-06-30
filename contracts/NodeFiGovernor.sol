// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

contract NodeFiGovernor is Governor, GovernorSettings, GovernorCountingSimple, GovernorVotes, GovernorVotesQuorumFraction, GovernorTimelockControl {
    constructor(ERC20Votes _token, TimelockController _timelock)
        Governor("NodeFiGovernor")
        GovernorSettings(1 /* 1 block */, 6570 /* ~1 day */, 0)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(4)
        GovernorTimelockControl(_timelock)
    {}

    // Override required functions
    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }
    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }
    function quorum(uint256 blockNumber) public view override(Governor, GovernorVotesQuorumFraction) returns (uint256) {
        return super.quorum(blockNumber);
    }
    function getVotes(address account, uint256 blockNumber) public view override(Governor, GovernorVotes) returns (uint256) {
        return super.getVotes(account, blockNumber);
    }
    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }
    function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description)
        public override(Governor, GovernorTimelockControl)
        returns (uint256)
    {
        return super.propose(targets, values, calldatas, description);
    }
    function execute(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        public payable override(Governor, GovernorTimelockControl)
        returns (uint256)
    {
        return super.execute{value: msg.value}(targets, values, calldatas, descriptionHash);
    }
    function cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        public override(Governor, GovernorTimelockControl)
        returns (uint256)
    {
        return super.cancel(targets, values, calldatas, descriptionHash);
    }
    function _executor() internal view override(GovernorTimelockControl) returns (address) {
        return super._executor();
    }
    function _schedule(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal override(GovernorTimelockControl)
    {
        super._schedule(targets, values, calldatas, descriptionHash);
    }
    function _execute(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal override(GovernorTimelockControl)
    {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }
}