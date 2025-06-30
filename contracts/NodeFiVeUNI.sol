// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract NodeFiVeUNI is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public uniToken;
    uint256 public constant MAX_TIME = 4 * 365 days;

    mapping(address => uint256) public lockedAmount;
    mapping(address => uint256) public lockEnd;

    uint256 public totalVeSupply;
    struct SupplyCheckpoint {
        uint256 timestamp;
        uint256 supply;
    }
    mapping(uint32 => SupplyCheckpoint) public supplyCheckpoints;
    uint32 public supplyEpoch;

    event LockCreated(address indexed user, uint256 amount, uint256 unlockTime);
    event AmountIncreased(address indexed user, uint256 addedAmount, uint256 newTotal);
    event TimeExtended(address indexed user, uint256 oldUnlockTime, uint256 newUnlockTime);
    event Withdrawn(address indexed user, uint256 amount);
    event SupplyCheckpointed(uint32 indexed epoch, uint256 timestamp, uint256 supply);

    uint256[50] private __gap;

    function initialize(address _uniToken) external initializer {
        require(_uniToken != address(0), "veUNI: zero token");
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        uniToken = IERC20Upgradeable(_uniToken);
    }

    function createLock(uint256 amount, uint256 unlockTime) external nonReentrant whenNotPaused {
        require(amount > 0 && lockedAmount[msg.sender] == 0 && unlockTime > block.timestamp && unlockTime <= block.timestamp + MAX_TIME, "veUNI: invalid lock");
        uint256 newVe = (amount * (unlockTime - block.timestamp)) / MAX_TIME;
        uniToken.safeTransferFrom(msg.sender, address(this), amount);
        lockedAmount[msg.sender] = amount;
        lockEnd[msg.sender] = unlockTime;
        totalVeSupply += newVe;
        _writeCheckpoint();
        emit LockCreated(msg.sender, amount, unlockTime);
    }

    function increaseAmount(uint256 added) external nonReentrant whenNotPaused {
        uint256 current = lockedAmount[msg.sender];
        uint256 endTime = lockEnd[msg.sender];
        require(current > 0 && block.timestamp < endTime && added > 0, "veUNI: invalid");
        uint256 oldVe = (current * (endTime - block.timestamp)) / MAX_TIME;
        uint256 newVe = ((current + added) * (endTime - block.timestamp)) / MAX_TIME;
        uniToken.safeTransferFrom(msg.sender, address(this), added);
        lockedAmount[msg.sender] = current + added;
        totalVeSupply += newVe - oldVe;
        _writeCheckpoint();
        emit AmountIncreased(msg.sender, added, lockedAmount[msg.sender]);
    }

    function increaseUnlockTime(uint256 newUnlockTime) external nonReentrant whenNotPaused {
        uint256 current = lockedAmount[msg.sender];
        uint256 endTime = lockEnd[msg.sender];
        require(current > 0 && endTime > block.timestamp && newUnlockTime > endTime && newUnlockTime <= block.timestamp + MAX_TIME, "veUNI: invalid");
        uint256 oldVe = (current * (endTime - block.timestamp)) / MAX_TIME;
        uint256 newVe = (current * (newUnlockTime - block.timestamp)) / MAX_TIME;
        lockEnd[msg.sender] = newUnlockTime;
        totalVeSupply += newVe - oldVe;
        _writeCheckpoint();
        emit TimeExtended(msg.sender, endTime, newUnlockTime);
    }

    function withdraw() external nonReentrant {
        uint256 amount = lockedAmount[msg.sender];
        uint256 endTime = lockEnd[msg.sender];
        require(amount > 0 && block.timestamp >= endTime, "veUNI: invalid withdraw");
        uint256 oldVe = (amount * (endTime - block.timestamp)) / MAX_TIME;
        lockedAmount[msg.sender] = 0;
        lockEnd[msg.sender] = 0;
        totalVeSupply -= oldVe;
        _writeCheckpoint();
        uniToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function veBalanceOf(address user) public view returns (uint256) {
        uint256 amount = lockedAmount[user];
        uint256 endTime = lockEnd[user];
        if (amount == 0 || block.timestamp >= endTime) return 0;
        return (amount * (endTime - block.timestamp)) / MAX_TIME;
    }

    function _writeCheckpoint() internal {
        supplyEpoch++;
        supplyCheckpoints[supplyEpoch] = SupplyCheckpoint(block.timestamp, totalVeSupply);
        emit SupplyCheckpointed(supplyEpoch, block.timestamp, totalVeSupply);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
    receive() external payable { revert("veUNI: no ETH"); }
    fallback() external payable { revert("veUNI: invalid"); }
}
