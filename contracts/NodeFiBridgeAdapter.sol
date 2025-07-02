// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

interface IRewardsDistributor {
    function allocateRewards(
        address[] calldata users,
        uint256[] calldata nodeAmounts,
        uint256[] calldata uniAmounts
    ) external;
}

contract NodeFiBridgeAdapter is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public bridgeToken;
    IRewardsDistributor public distributor;
    address public relayer;
    uint256[50] private __gap;

    event BridgeYieldReceived(uint256 amount, uint256 timestamp);
    event RelayerUpdated(address indexed newRelayer);
    event DistributorUpdated(address indexed newDistributor);

    function initialize(
        address _bridgeToken,
        address _distributor,
        address _relayer
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        require(_bridgeToken != address(0) && _distributor != address(0) && _relayer != address(0), "BridgeAdapter: invalid");
        bridgeToken = IERC20Upgradeable(_bridgeToken);
        distributor = IRewardsDistributor(_distributor);
        relayer = _relayer;
    }

    function setRelayer(address _relayer) external onlyOwner whenNotPaused {
        require(_relayer != address(0), "BridgeAdapter: zero");
        relayer = _relayer;
        emit RelayerUpdated(_relayer);
    }

    function setDistributor(address _distributor) external onlyOwner whenNotPaused {
        require(_distributor != address(0), "BridgeAdapter: zero");
        distributor = IRewardsDistributor(_distributor);
        emit DistributorUpdated(_distributor);
    }

    function depositYield(uint256 amount) external nonReentrant whenNotPaused {
        require(msg.sender == relayer && amount > 0, "BridgeAdapter: unauthorized or zero");
        bridgeToken.safeTransferFrom(msg.sender, address(this), amount);
        emit BridgeYieldReceived(amount, block.timestamp);
    }

    event YieldDeposited(address indexed relayer, uint256 amount);

    function forwardYield(
        address[] calldata users,
        uint256[] calldata nodeAmounts,
        uint256[] calldata uniAmounts
    ) external onlyOwner whenNotPaused {
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < users.length; i++) {
            totalAmount += nodeAmounts[i] + uniAmounts[i];
        }
        require(bridgeToken.balanceOf(address(this)) >= totalAmount, "BridgeAdapter: insufficient");
        bridgeToken.safeApprove(address(distributor), totalAmount);
        distributor.allocateRewards(users, nodeAmounts, uniAmounts);
    }
event YieldForwarded(
  address indexed caller,
  address[] recipients,
  uint256[] amountsAllocated,
  uint256[] amountsBoosted
);
    function _authorizeUpgrade(address) internal override onlyOwner {}
    receive() external payable { revert("BridgeAdapter: no ETH"); }
    fallback() external payable { revert("BridgeAdapter: invalid"); }
}
