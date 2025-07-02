// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NodeFiCommissionManager.sol";
import "./NodeFiVeToken.sol";
import "./NodeFiVeUNI.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract NodeFiRewardsDistributor is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public nodeToken;
    IERC20Upgradeable public uniToken;
    address public vault;

    NodeFiVeToken public veToken;
    NodeFiVeUNI  public veUniToken;
    NodeFiCommissionManager public commissionManager;
    uint16 public maxBoostBps;
    uint256 public maxVeSupply;
    uint16 public maxUniBoostBps;
    uint256 public maxVeUniSupply;

    mapping(address => uint256) public nodeAccrued;
    mapping(address => uint256) public uniAccrued;

    event RewardsClaimed(
        address indexed user,
        uint256 netNode,
        uint256 boostedUni,
        uint256 veBal,
        uint256 boostBps,
        uint256 veUniBal,
        uint256 uniBoostBps
    );
    event CommissionManagerUpdated(address indexed manager);
    event UniBoostParamsUpdated(uint16 maxUniBoostBps, uint256 maxVeUniSupply);

    function initialize(
        address _vault,
        address _nodeToken,
        address _uniToken,
        address payable _veToken,
        address payable _veUniToken,
        uint16  _maxBoostBps,
        uint256 _maxVeSupply,
        address _commissionManager,
        uint16  _maxUniBoostBps,
        uint256 _maxVeUniSupply
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        vault = _vault;
        nodeToken = IERC20Upgradeable(_nodeToken);
        uniToken = IERC20Upgradeable(_uniToken);
        veToken = NodeFiVeToken(_veToken);
        veUniToken = NodeFiVeUNI(_veUniToken);
        maxBoostBps = _maxBoostBps;
        maxVeSupply = _maxVeSupply;
        commissionManager = NodeFiCommissionManager(_commissionManager);
        maxUniBoostBps = _maxUniBoostBps;
        maxVeUniSupply = _maxVeUniSupply;
        nodeToken.safeApprove(_commissionManager, type(uint256).max);
    }
/// @notice Called by BridgeAdapter to credit new NODE/UNI rewards
    function allocateRewards(
        address[] calldata users,
        uint256[] calldata nodeAmounts,
        uint256[] calldata uniAmounts
    ) external whenNotPaused
    {
        require(
            users.length == nodeAmounts.length &&
            users.length == uniAmounts.length,
            "RD: length mismatch"
        );
        for (uint256 i = 0; i < users.length; i++) {
            nodeAccrued[users[i]] += nodeAmounts[i];
           uniAccrued[users[i]]  += uniAmounts[i];
        }
    }
    function setCommissionManager(address _manager)
        external onlyOwner whenNotPaused
    {
        commissionManager = NodeFiCommissionManager(_manager);
        nodeToken.safeApprove(_manager, type(uint256).max);
        emit CommissionManagerUpdated(_manager);
    }

    function setUniBoostParams(uint16 _maxUniBoostBps, uint256 _maxVeUniSupply)
        external onlyOwner whenNotPaused
    {
        maxUniBoostBps = _maxUniBoostBps;
        maxVeUniSupply = _maxVeUniSupply;
        emit UniBoostParamsUpdated(_maxUniBoostBps, _maxVeUniSupply);
    }

    function claim() external nonReentrant whenNotPaused {
        uint256 baseNode = nodeAccrued[msg.sender];
        uint256 baseUni = uniAccrued[msg.sender];
        require(baseNode > 0 || baseUni > 0, "RD: no rewards");


        uint256 veBal = veToken.veBalanceOf(msg.sender);
        uint256 boostBps = (maxBoostBps * veBal) / maxVeSupply;
        uint256 boostedNode = (baseNode * (10000 + boostBps)) / 10000;

        uint256 veUniBal = veUniToken.veBalanceOf(msg.sender);
        uint256 uniBoostBps = (maxUniBoostBps * veUniBal) / maxVeUniSupply;
        uint256 boostedUni = (baseUni * (10000 + uniBoostBps)) / 10000;

        nodeAccrued[msg.sender] = 0;
        uniAccrued[msg.sender] = 0;

        uint256 netNode = boostedNode;
        if (address(commissionManager) != address(0)) {
            netNode = commissionManager.handleCommission(
                IERC20Upgradeable(nodeToken),
                address(this),
                boostedNode
            );
        }
nodeToken.safeTransfer(msg.sender, netNode);
uniToken.safeTransfer(msg.sender, boostedUni);

emit RewardsClaimed(
    msg.sender, netNode, boostedUni, veBal, boostBps, veUniBal, uniBoostBps
);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

